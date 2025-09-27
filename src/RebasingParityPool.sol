// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {BaseHook} from "./forks/BaseHook.sol";
import {SafeCallback} from "v4-periphery/src/base/SafeCallback.sol";

import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {SafeCast} from "v4-core/src/libraries/SafeCast.sol";
import {ParityLP} from "./ParityLP.sol";
import {ProtocolRevenue} from "./ProtocolRevenue.sol";

contract RebasingParityPool is BaseHook, SafeCallback {
    using SafeCast for uint256;
    using PoolIdLibrary for PoolKey;
    using CurrencyLibrary for Currency;

    // ============ Constants ============

    /// @notice Fee calculation constants
    uint256 private constant FEE_DIVISOR = 1_000_000;
    uint256 private constant RATIO_SCALE = 1000;

    /// @notice Dynamic fee thresholds (in basis points)
    uint24 private constant MAX_PROTECTION_FEE = 50000;  // 5%
    uint24 private constant HIGH_IMBALANCE_FEE = 20000;  // 2%
    uint24 private constant MODERATE_IMBALANCE_FEE = 5000;  // 0.5%
    uint24 private constant SLIGHT_IMBALANCE_FEE = 2000;  // 0.2%
    uint24 private constant BASE_FEE = 1000;  // 0.1%

    /// @notice Incentive rate thresholds (in basis points)
    uint256 private constant CRITICAL_INCENTIVE_RATE = 1000;  // 0.1%
    uint256 private constant HIGH_INCENTIVE_RATE = 500;  // 0.05%
    uint256 private constant MODERATE_INCENTIVE_RATE = 200;  // 0.02%
    uint256 private constant SLIGHT_INCENTIVE_RATE = 100;  // 0.01%

    /// @notice Imbalance ratio thresholds (scaled by 1000)
    uint256 private constant CRITICAL_IMBALANCE_RATIO = 2000;  // 2:1
    uint256 private constant HIGH_IMBALANCE_RATIO = 1500;  // 1.5:1
    uint256 private constant MODERATE_IMBALANCE_RATIO = 1200;  // 1.2:1
    uint256 private constant SLIGHT_IMBALANCE_RATIO = 1100;  // 1.1:1

    /// @notice Fee precision for LP token calculations
    uint256 private constant LP_FEE_PRECISION = 1e18;

    /// @notice Operation type constants for unlock callback routing
    uint8 private constant OP_ADD_LIQUIDITY = 1;
    uint8 private constant OP_REMOVE_LIQUIDITY = 2;
    uint8 private constant OP_CLAIM_FEES = 3;

    // ============ Structs ============

    /// @notice Pool state data with calculated ratio
    struct PoolState {
        uint256 ethBalance;
        uint256 stethBalance;
        uint256 ratio;  // stETH/ETH ratio scaled by RATIO_SCALE
    }

    // ============ Immutable State ============

    /// @notice LP token for this pool
    ParityLP public immutable LP_TOKEN;

    /// @notice Protocol revenue management
    ProtocolRevenue public immutable PROTOCOL_REVENUE;

    /// @notice The only pool this hook is allowed to manage (set on first use)
    PoolId public allowedPoolId;
    
    /// @notice Track individual token balances in the pool
    uint256 public poolETHBalance;      // ETH balance in pool
    uint256 public poolStETHBalance;    // stETH balance in pool (accounting)
    uint256 public poolStETHPrincipal;  // stETH principal (deposited/withdrawn amounts, no rebase)
    
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
        // allowedPoolId will be set on first use
    }


    function _poolManager() internal view override returns (IPoolManager) {
        return poolManager;
    }

    /// @notice Modifier to ensure only the allowed pool can use this hook
    /// @dev Sets the allowed pool ID on first use, then validates exact pool ID match
    modifier onlyAllowedPool(PoolKey calldata key) {
        PoolId poolId = key.toId();

        // If this is the first use, set the allowed pool ID
        if (PoolId.unwrap(allowedPoolId) == bytes32(0)) {
            // Basic validation for first pool
            require(address(key.hooks) == address(this), "Hook: wrong hook address");
            require(Currency.unwrap(key.currency0) == address(0), "Hook: currency0 must be ETH");
            require(Currency.unwrap(key.currency1) != address(0), "Hook: currency1 cannot be zero");

            // Set the allowed pool ID
            allowedPoolId = poolId;
        }

        // Always check exact pool ID match
        require(PoolId.unwrap(poolId) == PoolId.unwrap(allowedPoolId), "Hook: unauthorized pool");
        _;
    }

    /// @notice Modifier to automatically sync rebase yield before major operations
    modifier syncRebaseYield(Currency stETHCurrency) {
        _distributeRebaseYield(stETHCurrency);
        _;
    }


    // ============ SECTION 3: HOOK INTERFACE IMPLEMENTATIONS ============

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

    /// @notice No liquidity will be managed by v4 PoolManager
    function _beforeAddLiquidity(address, PoolKey calldata key, IPoolManager.ModifyLiquidityParams calldata, bytes calldata)
        internal
        override
        onlyAllowedPool(key)
        returns (bytes4)
    {
        revert("No v4 Liquidity allowed");
    }

    /// @notice Parity swap via custom accounting, tokens are exchanged 1:1 with asymmetric fees
    function _beforeSwap(address, PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata)
        internal
        override
        onlyAllowedPool(key)
        syncRebaseYield(key.currency1)
        returns (bytes4, BeforeSwapDelta, uint24)
    {
        return _processSwap(key, params);
    }

    // ============ SECTION 4: SWAP PROCESSING ============
    
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

        // Check if pool has sufficient reserves for the swap
        if (params.zeroForOne) {
            // ETH -> stETH: Need sufficient stETH reserves
            require(poolStETHBalance >= outputAmount, "Insufficient stETH reserves");
        } else {
            // stETH -> ETH: Need sufficient ETH reserves
            require(poolETHBalance >= outputAmount, "Insufficient ETH reserves");
        }

        // Update pool reserves (swap from actual pool balances)
        if (params.zeroForOne) {
            // ETH -> stETH: Increase ETH reserves, decrease stETH reserves
            poolETHBalance += inputAmount;
            poolStETHBalance -= outputAmount;
        } else {
            // stETH -> ETH: Increase stETH reserves, decrease ETH reserves
            poolStETHBalance += inputAmount;
            poolETHBalance -= outputAmount;
        }

        // Execute token transfers through PoolManager
        // The hook's internal pool receives input currency and gives output currency
        // Mint input currency to hook (PoolManager accounting: hook gains input)
        poolManager.mint(address(this), inputCurrency.toId(), inputAmount);
        // Burn output currency from hook (PoolManager accounting: hook loses output)
        poolManager.burn(address(this), outputCurrency.toId(), outputAmount);

        // Calculate and return delta following the same pattern as BaseCustomCurve
        BeforeSwapDelta returnDelta;

        // Determine which currency is specified and which is unspecified
        (Currency specified, Currency unspecified) =
            (params.zeroForOne == isExactInput) ? (key.currency0, key.currency1) : (key.currency1, key.currency0);

        uint256 specifiedAmount = isExactInput ? inputAmount : outputAmount;
        uint256 unspecifiedAmount = isExactInput ? outputAmount : inputAmount;

        if (isExactInput) {
            // For exact input: user pays specified amount, receives unspecified amount
            returnDelta = toBeforeSwapDelta(-specifiedAmount.toInt128(), unspecifiedAmount.toInt128());
        } else {
            // For exact output: user pays unspecified amount, receives specified amount
            returnDelta = toBeforeSwapDelta(unspecifiedAmount.toInt128(), -specifiedAmount.toInt128());
        }

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
                uint256 feeAmount = (inputAmount * dynamicFee) / FEE_DIVISOR;
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
                inputAmount = (outputAmount * FEE_DIVISOR) / (FEE_DIVISOR - dynamicFee);
                feeAmount1 = inputAmount - outputAmount;
            } else {
                inputAmount = outputAmount;
            }
        }
    }

    /// @notice Calculate dynamic fee based on pool imbalance for stETH → ETH swaps
    function _calculateDynamicFee(PoolKey calldata key) internal view returns (uint24) {
        PoolState memory state = _getPoolState(key);

        if (state.ethBalance == 0) {
            return MAX_PROTECTION_FEE;
        }

        return _getFeeByRatio(state.ratio);
    }

    /// @notice Get fee tier based on imbalance ratio
    function _getFeeByRatio(uint256 ratio) internal pure returns (uint24) {
        if (ratio >= CRITICAL_IMBALANCE_RATIO) return MAX_PROTECTION_FEE;
        if (ratio >= HIGH_IMBALANCE_RATIO) return HIGH_IMBALANCE_FEE;
        if (ratio >= MODERATE_IMBALANCE_RATIO) return MODERATE_IMBALANCE_FEE;
        if (ratio >= SLIGHT_IMBALANCE_RATIO) return SLIGHT_IMBALANCE_FEE;
        return BASE_FEE;
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
        
        uint256 maxIncentive = (inputAmount * maxIncentiveRate) / FEE_DIVISOR;
        
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
        PoolState memory state = _getPoolState(key);

        if (state.ethBalance == 0) {
            return CRITICAL_INCENTIVE_RATE;
        }

        return _getIncentiveByRatio(state.ratio);
    }

    /// @notice Get incentive rate based on imbalance ratio
    function _getIncentiveByRatio(uint256 ratio) internal pure returns (uint256) {
        if (ratio >= CRITICAL_IMBALANCE_RATIO) return CRITICAL_INCENTIVE_RATE;
        if (ratio >= HIGH_IMBALANCE_RATIO) return HIGH_INCENTIVE_RATE;
        if (ratio >= MODERATE_IMBALANCE_RATIO) return MODERATE_INCENTIVE_RATE;
        if (ratio >= SLIGHT_IMBALANCE_RATIO) return SLIGHT_INCENTIVE_RATE;
        return 0; // No incentive when balanced or ETH-heavy
    }

    /// @notice Get current pool state with calculated ratio
    function _getPoolState(PoolKey calldata key) internal view returns (PoolState memory) {
        uint256 ethBalance = poolManager.balanceOf(address(this), key.currency0.toId());
        uint256 stethBalance = poolManager.balanceOf(address(this), key.currency1.toId());
        uint256 ratio;

        if (ethBalance == 0) {
            ratio = type(uint256).max; // Extreme imbalance
        } else {
            ratio = (stethBalance * RATIO_SCALE) / ethBalance;
        }

        return PoolState(ethBalance, stethBalance, ratio);
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

    // ============ SECTION 5: LIQUIDITY MANAGEMENT ============
    /// @notice Add liquidity 1:1 for the parity curve
    /// @param key PoolKey of the pool to add liquidity to
    /// @param amountPerToken The amount of each token to be added as liquidity
    /// @return lpTokens Amount of LP tokens minted to the liquidity provider
    function addLiquidity(PoolKey calldata key, uint256 amountPerToken)
        external
        payable
        onlyAllowedPool(key)
        syncRebaseYield(key.currency1)
        returns (uint256 lpTokens)
    {
        bytes memory data = abi.encodePacked(OP_ADD_LIQUIDITY, abi.encode(msg.sender, key.currency0, key.currency1, amountPerToken));
        bytes memory result = poolManager.unlock(data);
        lpTokens = abi.decode(result, (uint256));
        return lpTokens;
    }

    /// @notice Remove liquidity and burn LP tokens
    /// @param key PoolKey of the pool to remove liquidity from
    /// @param lpTokenAmount Amount of LP tokens to burn
    /// @return amount0 Amount of currency0 returned
    /// @return amount1 Amount of currency1 returned
    function removeLiquidity(PoolKey calldata key, uint256 lpTokenAmount)
        external
        onlyAllowedPool(key)
        syncRebaseYield(key.currency1)
        returns (uint256 amount0, uint256 amount1)
    {
        require(LP_TOKEN.balanceOf(msg.sender) >= lpTokenAmount, "Insufficient LP tokens");
        
        bytes memory data = abi.encodePacked(OP_REMOVE_LIQUIDITY, abi.encode(msg.sender, key.currency0, key.currency1, lpTokenAmount));
        bytes memory result = poolManager.unlock(data);
        uint256 packedAmounts = abi.decode(result, (uint256));
        amount0 = packedAmounts >> 128;
        amount1 = packedAmounts & type(uint128).max;
        
        return (amount0, amount1);
    }

    function _unlockCallback(bytes calldata data) internal virtual override returns (bytes memory) {
        require(msg.sender == address(poolManager), "Not pool manager");
        require(data.length > 0, "Empty data");

        uint8 opType = uint8(data[0]);
        bytes calldata operationData = data[1:];

        if (opType == OP_ADD_LIQUIDITY) {
            return _addLiquidityCallback(operationData);
        } else if (opType == OP_REMOVE_LIQUIDITY) {
            return _removeLiquidityCallback(operationData);
        } else if (opType == OP_CLAIM_FEES) {
            return _claimFeesCallback(operationData);
        } else {
            revert("Invalid operation type");
        }
    }

    function _addLiquidityCallback(bytes calldata data) internal returns (bytes memory) {
        (address payer, Currency currency0, Currency currency1, uint256 amountPerToken) =
            abi.decode(data, (address, Currency, Currency, uint256));

        // Security: payer comes from addLiquidity() which encodes msg.sender
        // This is safe because _unlockCallback is only called by poolManager during unlock

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
        poolStETHPrincipal += amountPerToken; // Track principal (no rebase yield)

        // Mint LP tokens to user
        LP_TOKEN.mint(payer, lpTokensToMint);

        return abi.encode(lpTokensToMint);
    }

    function _removeLiquidityCallback(bytes calldata data) internal returns (bytes memory) {
        (address user, Currency currency0, Currency currency1, uint256 lpTokenAmount) =
            abi.decode(data, (address, Currency, Currency, uint256));
        
        // Calculate what to remove BEFORE burning tokens (to avoid division by zero)
        uint256 totalLpSupply = LP_TOKEN.totalSupply();

        // Calculate proportional share of each token balance
        uint256 amount0 = (lpTokenAmount * poolETHBalance) / totalLpSupply;
        uint256 amount1 = (lpTokenAmount * poolStETHBalance) / totalLpSupply;

        // Add accumulated fees to withdrawal
        uint256 fees0 = (lpTokenAmount * (feesPerLpToken0 - claimedFeesPerLpToken0[user])) / LP_FEE_PRECISION;
        uint256 fees1 = (lpTokenAmount * (feesPerLpToken1 - claimedFeesPerLpToken1[user])) / LP_FEE_PRECISION;
        
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
        poolStETHBalance -= (amount1 - fees1); // Reduce accounting balance
        poolStETHPrincipal -= ((lpTokenAmount * poolStETHPrincipal) / totalLpSupply); // Reduce principal proportionally

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

    // ============ SECTION 6: FEE & YIELD MANAGEMENT ============
    // Note: Reentrancy protection is provided by SafeCallback and poolManager.unlock()

    /// @notice Distribute stETH rebasing yield to LPs as accumulated fees
    /// @param stETHCurrency The stETH currency to check for rebasing
    function _distributeRebaseYield(Currency stETHCurrency) private {
        if (Currency.unwrap(stETHCurrency) == address(0)) return; // Skip for ETH

        // Get hook's ERC6909 balance (this is the fixed claim amount)
        uint256 hookERC6909Balance = poolManager.balanceOf(address(this), stETHCurrency.toId());

        if (hookERC6909Balance == 0) return; // No tokens to rebase

        // Get total actual stETH in the pool manager (including rebases)
        uint256 totalStETHInPoolManager = IERC20(Currency.unwrap(stETHCurrency)).balanceOf(address(poolManager));

        // Get total ERC6909 stETH balance across all hooks in the pool manager
        uint256 totalERC6909Balance = poolManager.balanceOf(address(poolManager), stETHCurrency.toId());

        // Calculate this hook's actual stETH value (proportional share of rebased total)
        uint256 actualStETHValue;
        if (totalERC6909Balance > 0) {
            actualStETHValue = (hookERC6909Balance * totalStETHInPoolManager) / totalERC6909Balance;
        } else {
            // Fallback: if this is the only hook, our value equals the total
            actualStETHValue = totalStETHInPoolManager;
        }

        // Calculate rebase yield for this hook only
        if (actualStETHValue > poolStETHPrincipal) {
            uint256 hookTotalYield = actualStETHValue - poolStETHPrincipal;

            // Calculate undistributed yield (total yield minus what we've already distributed)
            uint256 alreadyDistributed = accumulatedFees1; // All fees/yield distributed so far
            uint256 newYield = hookTotalYield > alreadyDistributed ?
                hookTotalYield - alreadyDistributed : 0;

            uint256 totalLPSupply = LP_TOKEN.totalSupply();
            if (newYield > 0 && totalLPSupply > 0) {
                feesPerLpToken1 += (newYield * LP_FEE_PRECISION) / totalLPSupply;
                accumulatedFees1 += newYield;
                poolStETHBalance = poolStETHPrincipal + hookTotalYield; // Update accounting

                emit RebaseYieldDistributed(newYield, block.timestamp);
            }
        }
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
                feesPerLpToken0 += (feeAmount0 * LP_FEE_PRECISION) / totalSupply;
            }
        }
        
        if (feeAmount1 > 0) {
            accumulatedFees1 += feeAmount1;
            
            // Update fees per LP token if there are LP tokens outstanding
            uint256 totalSupply = LP_TOKEN.totalSupply();
            if (totalSupply > 0) {
                feesPerLpToken1 += (feeAmount1 * LP_FEE_PRECISION) / totalSupply;
            }
        }
    }

    /// @notice Calculate pending fees for an LP
    function pendingFees(address lp) external view returns (uint256 fees0, uint256 fees1) {
        uint256 lpBalance = LP_TOKEN.balanceOf(lp);
        if (lpBalance == 0) return (0, 0);
        
        fees0 = (lpBalance * (feesPerLpToken0 - claimedFeesPerLpToken0[lp])) / LP_FEE_PRECISION;
        fees1 = (lpBalance * (feesPerLpToken1 - claimedFeesPerLpToken1[lp])) / LP_FEE_PRECISION;
    }

    /// @notice Claim accumulated fees for an LP
    function claimFees(PoolKey calldata key)
        external
        onlyAllowedPool(key)
        syncRebaseYield(key.currency1)
        returns (uint256 fees0, uint256 fees1)
    {
        uint256 lpBalance = LP_TOKEN.balanceOf(msg.sender);
        require(lpBalance > 0, "No LP tokens");
        
        // Calculate pending fees
        fees0 = (lpBalance * (feesPerLpToken0 - claimedFeesPerLpToken0[msg.sender])) / LP_FEE_PRECISION;
        fees1 = (lpBalance * (feesPerLpToken1 - claimedFeesPerLpToken1[msg.sender])) / LP_FEE_PRECISION;
        
        if (fees0 > 0 || fees1 > 0) {
            bytes memory data = abi.encodePacked(OP_CLAIM_FEES, abi.encode(msg.sender, key.currency0, key.currency1, fees0, fees1));
            bytes memory result = poolManager.unlock(data);
            (uint256 claimed0, uint256 claimed1) = abi.decode(result, (uint256, uint256));
            return (claimed0, claimed1);
        }
        
        return (0, 0);
    }

    function _claimFeesCallback(bytes calldata data) internal returns (bytes memory) {
        (address user, Currency currency0, Currency currency1, uint256 fees0, uint256 fees1) =
            abi.decode(data, (address, Currency, Currency, uint256, uint256));
        
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

    // ============ SECTION 7: VIEW/GETTER FUNCTIONS ============

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

    /// @notice Get the allowed pool ID for this hook
    function getAllowedPoolId() external view returns (PoolId) {
        return allowedPoolId;
    }
}
