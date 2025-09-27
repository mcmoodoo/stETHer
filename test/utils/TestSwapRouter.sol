// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console2} from "forge-std/console2.sol";

contract TestSwapRouter {
    IPoolManager public immutable poolManager;

    struct SwapParams {
        PoolKey key;
        IPoolManager.SwapParams params;
        address sender;
    }

    constructor(IPoolManager _poolManager) {
        poolManager = _poolManager;
    }

    /// @notice Execute a swap through PoolManager
    function swap(PoolKey calldata key, IPoolManager.SwapParams calldata params, bytes calldata hookData)
        external payable returns (BalanceDelta delta) {

        SwapParams memory swapParams = SwapParams({
            key: key,
            params: params,
            sender: msg.sender
        });

        bytes memory result = poolManager.unlock(abi.encode(swapParams, hookData));
        delta = abi.decode(result, (BalanceDelta));

        return delta;
    }

    /// @notice PoolManager unlock callback
    function unlockCallback(bytes calldata data) external returns (bytes memory) {
        require(msg.sender == address(poolManager), "Only PoolManager can call");

        (SwapParams memory swapParams, bytes memory hookData) = abi.decode(data, (SwapParams, bytes));

        console2.log("=== UNLOCK CALLBACK START ===");
        console2.log("Swap direction (zeroForOne):", swapParams.params.zeroForOne);
        console2.log("Amount specified:", swapParams.params.amountSpecified);

        // Handle pre-swap settlements
        _settleSwap(swapParams);

        // Execute the actual swap through PoolManager
        console2.log("Executing swap through PoolManager...");
        BalanceDelta delta = poolManager.swap(swapParams.key, swapParams.params, hookData);

        console2.log("Swap delta received:");
        console2.log("  delta.amount0():", int256(delta.amount0()));
        console2.log("  delta.amount1():", int256(delta.amount1()));

        // Handle post-swap takes
        _takeSwap(swapParams, delta);

        console2.log("=== UNLOCK CALLBACK END ===");
        return abi.encode(delta);
    }

    /// @notice Handle token settlements before swap
    function _settleSwap(SwapParams memory swapParams) internal {
        // For hooks with beforeSwapReturnDelta, the hook handles all settlement
        // No pre-settlement needed - the hook will return appropriate deltas
        // All settlement/taking is handled in _takeSwap based on returned deltas
    }

    /// @notice Handle token takes after swap
    function _takeSwap(SwapParams memory swapParams, BalanceDelta delta) internal {
        console2.log("=== SETTLEMENT START ===");
        console2.log("Contract ETH balance:", address(this).balance);

        // Handle currency0 (ETH)
        if (delta.amount0() > 0) {
            // User owes ETH to PoolManager
            uint256 amount = uint256(uint128(delta.amount0()));
            console2.log("User owes ETH to PoolManager:", amount);
            console2.log("Settling ETH with balance:", address(this).balance);
            poolManager.settle{value: address(this).balance}();
            console2.log("ETH settlement complete");
        } else if (delta.amount0() < 0) {
            // PoolManager owes ETH to user
            uint256 amount = uint256(uint128(-delta.amount0()));
            console2.log("PoolManager owes ETH to user:", amount);
            poolManager.take(swapParams.key.currency0, swapParams.sender, amount);
            console2.log("ETH take complete");
        } else {
            console2.log("ETH delta is zero");
        }

        // Handle currency1 (stETH)
        if (delta.amount1() > 0) {
            // User owes stETH to PoolManager
            uint256 amount = uint256(uint128(delta.amount1()));
            console2.log("User owes stETH to PoolManager:", amount);
            IERC20(Currency.unwrap(swapParams.key.currency1)).transferFrom(
                swapParams.sender,
                address(poolManager),
                amount
            );
            poolManager.settle();
            console2.log("stETH settlement complete");
        } else if (delta.amount1() < 0) {
            // PoolManager owes stETH to user
            uint256 amount = uint256(uint128(-delta.amount1()));
            console2.log("PoolManager owes stETH to user:", amount);
            poolManager.take(swapParams.key.currency1, swapParams.sender, amount);
            console2.log("stETH take complete");
        } else {
            console2.log("stETH delta is zero");
        }

        console2.log("=== SETTLEMENT END ===");
        console2.log("Final contract ETH balance:", address(this).balance);
        console2.log("Final contract stETH balance:", IERC20(Currency.unwrap(swapParams.key.currency1)).balanceOf(address(this)));
    }

    /// @notice Allow contract to receive ETH
    receive() external payable {}
}