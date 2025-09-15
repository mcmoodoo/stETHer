// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {BaseHook} from "./forks/BaseHook.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {ParityLP} from "./ParityLP.sol";
import {ProtocolRevenue} from "./ProtocolRevenue.sol";

contract ParityPool is BaseHook, SafeCallback {
    using SafeCast for uint256;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    /// @notice LP token for this pool
    ParityLP public immutable LP_TOKEN;
    
    /// @notice Protocol revenue management
    ProtocolRevenue public immutable PROTOCOL_REVENUE;
    
    /// @notice Track individual token balances in the pool
    uint256 public poolETHBalance;      // ETH balance in pool
    uint256 public poolStETHBalance;    // stETH balance in pool (accounting)
    uint256 public lastKnownStETHBalance; // Last known actual stETH balance for rebase tracking
    
    /// @notice Accumulated fees for distribution to LPs (in terms of both tokens)
    uint256 public accumulatedFees0; // ETH fees
    uint256 public accumulatedFees1; // stETH fees
    
    /// @notice Track fees claimed per LP token to prevent double claiming
    uint256 public feesPerLpToken0; // ETH fees per LP token (scaled by 1e18)
    uint256 public feesPerLpToken1; // stETH fees per LP token (scaled by 1e18)
    
    /// @notice Track what each user has already claimed
    mapping(address => uint256) public claimedFeesPerLpToken0;
    mapping(address => uint256) public claimedFeesPerLpToken1;

    /// @notice Events for rebase yield tracking
    event RebaseYieldDistributed(uint256 yieldAmount, uint256 timestamp);
    event PoolBalancesUpdated(uint256 ethBalance, uint256 stethBalance);

    constructor(IPoolManager poolManager_, address treasury) SafeCallback(poolManager_) {
        LP_TOKEN = new ParityLP(address(this));
        PROTOCOL_REVENUE = new ProtocolRevenue(treasury);
    }

    function _poolManager() internal view override returns (IPoolManager) {
        return poolManager;
    }

    /// @notice Modifier to automatically sync rebase yield before major operations
    modifier syncRebaseYield(Currency stETHCurrency) {
        _distributeRebaseYield(stETHCurrency);
        _;
    }

    /// @notice Distribute stETH rebasing yield to LPs as accumulated fees
    /// @param stETHCurrency The stETH currency to check for rebasing
    function _distributeRebaseYield(Currency stETHCurrency) private {
        if (Currency.unwrap(stETHCurrency) == address(0)) return; // Skip for ETH

        // For simplicity in testing: assume our hook is the only user of this stETH in PoolManager
        // In production, this would need to be more sophisticated to handle multiple pools
        uint256 actualStETHBalance = IERC20(Currency.unwrap(stETHCurrency)).balanceOf(address(poolManager));

        if (actualStETHBalance > lastKnownStETHBalance) {
            uint256 rebaseYield = actualStETHBalance - lastKnownStETHBalance;

            // Distribute yield proportionally to LPs (like trading fees)
            uint256 totalLPSupply = LP_TOKEN.totalSupply();

            if (totalLPSupply > 0) {
                feesPerLpToken1 += (rebaseYield * 1e18) / totalLPSupply;
                accumulatedFees1 += rebaseYield;
                poolStETHBalance += rebaseYield; // Update accounting balance

                emit RebaseYieldDistributed(rebaseYield, block.timestamp);
            }

            lastKnownStETHBalance = actualStETHBalance;
        }
    }

    function getHookPermissions() public pure override returns (Hooks.Permissions memory) {
        return Hooks.Permissions({
            beforeInitialize: false,
            afterInitialize: false,
            beforeAddLiquidity: true,
            afterAddLiquidity: false,
            beforeRemoveLiquidity: false,
            afterRemoveLiquidity: false,
            beforeSwap: true,
            afterSwap: false,
            beforeDonate: false,
            afterDonate: false,
            beforeSwapReturnDelta: true,
            afterSwapReturnDelta: false,
            afterAddLiquidityReturnDelta: false,
            afterRemoveLiquidityReturnDelta: false
        });
    }

    /// @notice Parity swap via custom accounting, tokens are exchanged 1:1 with asymmetric fees
    function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        internal
        override
        syncRebaseYield(key.currency1)
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return _processSwap(key, params);
    }
    
    /// @notice Process swap logic (extracted to avoid stack too deep)
    function _processSwap(PoolKey calldata key, IPoolManager.SwapParams calldata params)
        internal
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        // determine inbound/outbound token based on 0->1 or 1->0 swap
        (Currency inputCurrency, Currency outputCurrency) =
            params.zeroForOne ? (key.currency0, key.currency1) : (key.currency1, key.currency0);

        bool isExactInput = params.amountSpecified < 0;
        uint24 dynamicFee = params.zeroForOne ? 0 : _calculateDynamicFee(key);

        (uint256 inputAmount, uint256 outputAmount, uint256 feeAmount1, uint256 incentiveAmount) = 
            _calculateSwapAmounts(key, params, isExactInput, dynamicFee);

        // Handle fees and incentives
        if (feeAmount1 > 0) {
            _splitAndAccumulateFees(key, 0, feeAmount1, inputAmount);
        }
        if (incentiveAmount > 0) {
            _payIncentiveFromProtocolFees(key, incentiveAmount);
        }

        // Execute token transfers
        poolManager.mint(address(this), inputCurrency.toId(), inputAmount);
        poolManager.burn(address(this), outputCurrency.toId(), outputAmount);

        // Calculate and return delta
        int128 inputDelta = inputAmount.toInt128();
        int128 outputDelta = outputAmount.toInt128();
        BeforeSwapDelta returnDelta =
            isExactInput ? toBeforeSwapDelta(inputDelta, -outputDelta) : toBeforeSwapDelta(-outputDelta, inputDelta);

        return (BaseHook.beforeSwap.selector, returnDelta, dynamicFee);
    }
    
    /// @notice Calculate swap amounts including fees and incentives
    function _calculateSwapAmounts(PoolKey calldata key, IPoolManager.SwapParams calldata params, bool isExactInput, uint24 dynamicFee)
        internal view returns (uint256 inputAmount, uint256 outputAmount, uint256 feeAmount1, uint256 incentiveAmount)
    {
        if (isExactInput) {
            inputAmount = uint256(-params.amountSpecified);
            
            if (params.zeroForOne) {
                // ETH → stETH: Calculate potential incentive
                (outputAmount, incentiveAmount) = _calculateIncentivizedOutput(key, inputAmount);
            } else if (dynamicFee > 0) {
                // stETH → ETH: Apply dynamic fees
                uint256 feeAmount = (inputAmount * dynamicFee) / 1_000_000;
                outputAmount = inputAmount - feeAmount;
                feeAmount1 = feeAmount;
            } else {
                outputAmount = inputAmount; // No fee, 1:1 swap
            }
        } else {
            outputAmount = uint256(params.amountSpecified);
            
            if (params.zeroForOne) {
                inputAmount = outputAmount; // 1:1 for exact output ETH → stETH
            } else if (dynamicFee > 0) {
                inputAmount = (outputAmount * 1_000_000) / (1_000_000 - dynamicFee);
                feeAmount1 = inputAmount - outputAmount;
            } else {
                inputAmount = outputAmount;
            }
        }
    }

    /// @notice Calculate dynamic fee based on pool imbalance for stETH → ETH swaps
    function _calculateDynamicFee(PoolKey calldata key) internal view returns (uint24) {
        uint256 ethBalance = poolManager.balanceOf(address(this), key.currency0.toId());
        uint256 stethBalance = poolManager.balanceOf(address(this), key.currency1.toId());
        
        if (ethBalance == 0) {
            return 50000; // 5% maximum protection fee
        }
        
        // Calculate imbalance ratio: stETH / ETH (scaled by 1000 for precision)
        uint256 ratio = (stethBalance * 1000) / ethBalance;
        
        if (ratio >= 2000) return 50000; // 5% - Critical imbalance
        if (ratio >= 1500) return 20000; // 2% - High imbalance  
        if (ratio >= 1200) return 5000;  // 0.5% - Moderate imbalance
        if (ratio >= 1100) return 2000;  // 0.2% - Slight imbalance
        return 1000; // 0.1% - Base fee
    }

    /// @notice Calculate incentivized output for ETH → stETH swaps using protocol fees
    function _calculateIncentivizedOutput(PoolKey calldata key, uint256 inputAmount) 
        internal view returns (uint256 outputAmount, uint256 incentiveAmount) {
        
        // Calculate maximum incentive based on pool imbalance
        uint256 maxIncentiveRate = _calculateMaxIncentiveRate(key);
        
        if (maxIncentiveRate == 0) {
            // No incentive when balanced
            return (inputAmount, 0);
        }
        
        uint256 maxIncentive = (inputAmount * maxIncentiveRate) / 1_000_000;
        
        // Check available protocol fees for incentives
        uint256 availableProtocolFees = PROTOCOL_REVENUE.getProtocolFees(Currency.unwrap(key.currency1));
        
        // Use the minimum of max incentive and available protocol fees
        incentiveAmount = maxIncentive > availableProtocolFees ? availableProtocolFees : maxIncentive;
        
        // Only provide incentive if we have protocol fees to cover it
        if (incentiveAmount == 0) {
            outputAmount = inputAmount; // No incentive available
        } else {
            outputAmount = inputAmount + incentiveAmount;
        }
        
        return (outputAmount, incentiveAmount);
    }

    /// @notice Calculate maximum incentive rate based on pool imbalance for ETH → stETH
    function _calculateMaxIncentiveRate(PoolKey calldata key) internal view returns (uint256) {
        uint256 ethBalance = poolManager.balanceOf(address(this), key.currency0.toId());
        uint256 stethBalance = poolManager.balanceOf(address(this), key.currency1.toId());
        
        if (ethBalance == 0) {
            return 1000; // 0.1% max incentive when no ETH (critical need)
        }
        
        // Calculate imbalance ratio: stETH / ETH (scaled by 1000 for precision)
        uint256 ratio = (stethBalance * 1000) / ethBalance;
        
        // Higher ratio = more stETH relative to ETH = higher incentive needed to attract ETH
        if (ratio >= 2000) return 1000; // 0.1% - Critical need for ETH
        if (ratio >= 1500) return 500;  // 0.05% - High need for ETH
        if (ratio >= 1200) return 200;  // 0.02% - Moderate need
        if (ratio >= 1100) return 100;  // 0.01% - Slight need
        return 0; // No incentive when balanced or ETH-heavy
    }

    /// @notice Pay incentive from protocol fees to encourage ETH → stETH swaps
    function _payIncentiveFromProtocolFees(PoolKey calldata key, uint256 incentiveAmount) internal {
        if (incentiveAmount == 0) return;
        
        // Deduct incentive from protocol fees
        address stethToken = Currency.unwrap(key.currency1);
        bool success = PROTOCOL_REVENUE.spendProtocolFeesForIncentive(stethToken, incentiveAmount);
        
        if (!success) {
            // If protocol fees are insufficient, this should not happen due to pre-calculation
            // But we include this as a safety check
            revert("Insufficient protocol fees for incentive");
        }
        
        // The incentive amount will be added to the output in the swap calculation
        // The protocol fees have been deducted to account for this cost
    }

    /// @notice No liquidity will be managed by v4 PoolManager
    function _beforeAddLiquidity(address, PoolKey calldata, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        internal
        pure
        override
        returns (bytes4)
    {
        revert("No v4 Liquidity allowed");
    }

    // -----------------------------------------------
    // Liquidity Functions, not production ready
    // -----------------------------------------------
    /// @notice Add liquidity 1:1 for the parity curve
    /// @param key PoolKey of the pool to add liquidity to
    /// @param amountPerToken The amount of each token to be added as liquidity
    /// @return lpTokens Amount of LP tokens minted to the liquidity provider
    function addLiquidity(PoolKey calldata key, uint256 amountPerToken) external payable syncRebaseYield(key.currency1) returns (uint256 lpTokens) {
        bytes memory result = poolManager.unlock(abi.encode(msg.sender, key.currency0, key.currency1, amountPerToken, true));
        lpTokens = abi.decode(result, (uint256));
        return lpTokens;
    }

    /// @notice Remove liquidity and burn LP tokens
    /// @param key PoolKey of the pool to remove liquidity from
    /// @param lpTokenAmount Amount of LP tokens to burn
    /// @return amount0 Amount of currency0 returned
    /// @return amount1 Amount of currency1 returned
    function removeLiquidity(PoolKey calldata key, uint256 lpTokenAmount) external syncRebaseYield(key.currency1) returns (uint256 amount0, uint256 amount1) {
        require(LP_TOKEN.balanceOf(msg.sender) >= lpTokenAmount, "Insufficient LP tokens");
        
        bytes memory result = poolManager.unlock(abi.encode(msg.sender, key.currency0, key.currency1, lpTokenAmount, false));
        uint256 packedAmounts = abi.decode(result, (uint256));
        amount0 = packedAmounts >> 128;
        amount1 = packedAmounts & type(uint128).max;
        
        return (amount0, amount1);
    }

    function _unlockCallback(bytes calldata data) internal virtual override returns (bytes memory) {
        require(msg.sender == address(poolManager), "Not pool manager");

        // Try to decode with operation type
        uint256 operation;
        if (data.length > 160) { // Check if data includes operation type
            (, , , , , operation) = abi.decode(data, (address, Currency, Currency, uint256, uint256, uint256));
        }

        if (operation == 2) {
            // Claim fees operation
            (address user, Currency currency0, Currency currency1, uint256 fees0, uint256 fees1, ) =
                abi.decode(data, (address, Currency, Currency, uint256, uint256, uint256));
            return _claimFeesCallback(user, currency0, currency1, fees0, fees1);
        } else {
            // Legacy add/remove liquidity operations
            (address user, Currency currency0, Currency currency1, uint256 amount, bool isAddLiquidity) =
                abi.decode(data, (address, Currency, Currency, uint256, bool));

            if (isAddLiquidity) {
                return _addLiquidityCallback(user, currency0, currency1, amount);
            } else {
                return _removeLiquidityCallback(user, currency0, currency1, amount);
            }
        }
    }

    function _addLiquidityCallback(address payer, Currency currency0, Currency currency1, uint256 amountPerToken) 
        internal returns (bytes memory) {
        
        // Handle currency0
        if (currency0.isAddressZero()) {
            poolManager.settle{value: amountPerToken}();
        } else {
            poolManager.sync(currency0);
            require(IERC20(Currency.unwrap(currency0)).transferFrom(payer, address(poolManager), amountPerToken), "TransferFrom failed");
            poolManager.settle();
        }

        // Handle currency1
        if (currency1.isAddressZero()) {
            poolManager.settle{value: amountPerToken}();
        } else {
            poolManager.sync(currency1);
            require(IERC20(Currency.unwrap(currency1)).transferFrom(payer, address(poolManager), amountPerToken), "TransferFrom failed");
            poolManager.settle();
        }

        // Mint ERC6909 to the hook for swaps
        poolManager.mint(address(this), currency0.toId(), amountPerToken);
        poolManager.mint(address(this), currency1.toId(), amountPerToken);

        // Calculate LP tokens to mint
        uint256 lpTokensToMint;
        uint256 totalPoolValue = poolETHBalance + poolStETHBalance;

        if (totalPoolValue == 0) {
            // First liquidity provider gets tokens equal to total amount added
            lpTokensToMint = amountPerToken * 2; // Since we add equal amounts of both tokens
        } else {
            // Subsequent LPs get proportional share
            // lpTokens = (amountAdded / totalPoolValue) * lpToken.totalSupply()
            lpTokensToMint = (amountPerToken * 2 * LP_TOKEN.totalSupply()) / totalPoolValue;
        }

        // Update individual balances
        poolETHBalance += amountPerToken;
        poolStETHBalance += amountPerToken;
        lastKnownStETHBalance += amountPerToken; // Track actual stETH added

        // Mint LP tokens to user
        LP_TOKEN.mint(payer, lpTokensToMint);

        return abi.encode(lpTokensToMint);
    }

    function _removeLiquidityCallback(address user, Currency currency0, Currency currency1, uint256 lpTokenAmount)
        internal returns (bytes memory) {
        
        // Calculate what to remove BEFORE burning tokens (to avoid division by zero)
        uint256 totalLpSupply = LP_TOKEN.totalSupply();

        // Calculate proportional share of each token balance
        uint256 amount0 = (lpTokenAmount * poolETHBalance) / totalLpSupply;
        uint256 amount1 = (lpTokenAmount * poolStETHBalance) / totalLpSupply;

        // Add accumulated fees to withdrawal
        uint256 fees0 = (lpTokenAmount * (feesPerLpToken0 - claimedFeesPerLpToken0[user])) / 1e18;
        uint256 fees1 = (lpTokenAmount * (feesPerLpToken1 - claimedFeesPerLpToken1[user])) / 1e18;
        
        amount0 += fees0;
        amount1 += fees1;
        
        // Update claimed fees tracking for this user
        claimedFeesPerLpToken0[user] = feesPerLpToken0;
        claimedFeesPerLpToken1[user] = feesPerLpToken1;
        
        // Deduct claimed fees from accumulated totals
        accumulatedFees0 -= fees0;
        accumulatedFees1 -= fees1;

        // Get current pool balances and ensure we don't exceed them
        uint256 poolBalance0 = poolManager.balanceOf(address(this), currency0.toId());
        uint256 poolBalance1 = poolManager.balanceOf(address(this), currency1.toId());
        
        if (amount0 > poolBalance0) amount0 = poolBalance0;
        if (amount1 > poolBalance1) amount1 = poolBalance1;

        // Update individual balances BEFORE burning tokens
        poolETHBalance -= (amount0 - fees0); // Subtract base amount (fees stay in pool for others)
        poolStETHBalance -= (amount1 - fees1);
        lastKnownStETHBalance -= (amount1 - fees1); // Update tracking balance

        // Burn LP tokens
        LP_TOKEN.burn(user, lpTokenAmount);

        // Burn ERC6909 tokens from hook
        poolManager.burn(address(this), currency0.toId(), amount0);
        poolManager.burn(address(this), currency1.toId(), amount1);

        // Transfer tokens to user
        poolManager.take(currency0, user, amount0);
        poolManager.take(currency1, user, amount1);

        return abi.encode((uint256(amount0) << 128) | amount1);
    }

    /// @notice Split fees between protocol and LPs, then accumulate LP portion
    function _splitAndAccumulateFees(PoolKey calldata key, uint256 feeAmount0, uint256 feeAmount1, uint256 swapAmount) internal {
        // Calculate protocol fees using the ProtocolRevenue contract
        (uint256 protocolFee0, uint256 lpFee0) = PROTOCOL_REVENUE.calculateProtocolFee(feeAmount0, swapAmount);
        (uint256 protocolFee1, uint256 lpFee1) = PROTOCOL_REVENUE.calculateProtocolFee(feeAmount1, swapAmount);
        
        // Accumulate protocol fees
        if (protocolFee0 > 0) {
            PROTOCOL_REVENUE.accumulateProtocolFee(Currency.unwrap(key.currency0), protocolFee0);
        }
        if (protocolFee1 > 0) {
            PROTOCOL_REVENUE.accumulateProtocolFee(Currency.unwrap(key.currency1), protocolFee1);
        }
        
        // Accumulate LP fees
        _accumulateLpFees(lpFee0, lpFee1);
    }

    /// @notice Accumulate fees for LP distribution
    function _accumulateLpFees(uint256 feeAmount0, uint256 feeAmount1) internal {
        if (feeAmount0 > 0) {
            accumulatedFees0 += feeAmount0;
            
            // Update fees per LP token if there are LP tokens outstanding
            uint256 totalSupply = LP_TOKEN.totalSupply();
            if (totalSupply > 0) {
                feesPerLpToken0 += (feeAmount0 * 1e18) / totalSupply;
            }
        }
        
        if (feeAmount1 > 0) {
            accumulatedFees1 += feeAmount1;
            
            // Update fees per LP token if there are LP tokens outstanding
            uint256 totalSupply = LP_TOKEN.totalSupply();
            if (totalSupply > 0) {
                feesPerLpToken1 += (feeAmount1 * 1e18) / totalSupply;
            }
        }
    }

    /// @notice Calculate pending fees for an LP
    function pendingFees(address lp) external view returns (uint256 fees0, uint256 fees1) {
        uint256 lpBalance = LP_TOKEN.balanceOf(lp);
        if (lpBalance == 0) return (0, 0);
        
        fees0 = (lpBalance * (feesPerLpToken0 - claimedFeesPerLpToken0[lp])) / 1e18;
        fees1 = (lpBalance * (feesPerLpToken1 - claimedFeesPerLpToken1[lp])) / 1e18;
    }

    /// @notice Claim accumulated fees for an LP
    function claimFees(PoolKey calldata key) external syncRebaseYield(key.currency1) returns (uint256 fees0, uint256 fees1) {
        uint256 lpBalance = LP_TOKEN.balanceOf(msg.sender);
        require(lpBalance > 0, "No LP tokens");
        
        // Calculate pending fees
        fees0 = (lpBalance * (feesPerLpToken0 - claimedFeesPerLpToken0[msg.sender])) / 1e18;
        fees1 = (lpBalance * (feesPerLpToken1 - claimedFeesPerLpToken1[msg.sender])) / 1e18;
        
        if (fees0 > 0 || fees1 > 0) {
            bytes memory result = poolManager.unlock(abi.encode(msg.sender, key.currency0, key.currency1, fees0, fees1, 2)); // 2 = claim fees
            (uint256 claimed0, uint256 claimed1) = abi.decode(result, (uint256, uint256));
            return (claimed0, claimed1);
        }
        
        return (0, 0);
    }

    function _claimFeesCallback(address user, Currency currency0, Currency currency1, uint256 fees0, uint256 fees1)
        internal returns (bytes memory) {
        
        // Update claimed fees tracking
        claimedFeesPerLpToken0[user] = feesPerLpToken0;
        claimedFeesPerLpToken1[user] = feesPerLpToken1;
        
        // Deduct from accumulated fees
        accumulatedFees0 -= fees0;
        accumulatedFees1 -= fees1;
        
        // Transfer fees via pool manager
        if (fees0 > 0) {
            poolManager.burn(address(this), currency0.toId(), fees0);
            poolManager.take(currency0, user, fees0);
        }
        if (fees1 > 0) {
            poolManager.burn(address(this), currency1.toId(), fees1);
            poolManager.take(currency1, user, fees1);
        }
        
        return abi.encode(fees0, fees1);
    }

    /// @notice Get total accumulated fees (LP portion only)
    function getTotalAccumulatedFees() external view returns (uint256 fees0, uint256 fees1) {
        return (accumulatedFees0, accumulatedFees1);
    }

    /// @notice Get total liquidity (for backward compatibility with tests)
    function totalLiquidity() external view returns (uint256) {
        return poolETHBalance + poolStETHBalance;
    }
    
    /// @notice Get protocol fees accumulated
    function getProtocolFees(address token) external view returns (uint256) {
        return PROTOCOL_REVENUE.getProtocolFees(token);
    }
    
    /// @notice Get the protocol revenue contract address
    function getProtocolRevenue() external view returns (address) {
        return address(PROTOCOL_REVENUE);
    }
}
