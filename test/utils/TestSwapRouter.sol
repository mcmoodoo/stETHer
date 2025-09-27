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

        // Handle pre-swap settlements
        _settleSwap(swapParams);

        // Execute the actual swap through PoolManager
        BalanceDelta delta = poolManager.swap(swapParams.key, swapParams.params, hookData);

        // Handle post-swap takes
        _takeSwap(swapParams, delta);

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
        // Get the delta amounts for input and output currencies
        int128 inputDelta = swapParams.params.zeroForOne ? delta.amount0() : delta.amount1();
        int128 outputDelta = swapParams.params.zeroForOne ? delta.amount1() : delta.amount0();

        console2.log("Debug: zeroForOne =", swapParams.params.zeroForOne);
        console2.log("Debug: delta.amount0() =", int256(delta.amount0()));
        console2.log("Debug: delta.amount1() =", int256(delta.amount1()));
        console2.log("Debug: inputDelta =", int256(inputDelta));
        console2.log("Debug: outputDelta =", int256(outputDelta));

        // Handle settlement and taking based on delta signs
        // If delta is negative, PoolManager owes tokens - we take them
        // If delta is positive, we owe tokens to PoolManager - we settle them

        // Handle currency0 (ETH)
        if (delta.amount0() > 0) {
            // We owe ETH to PoolManager
            uint256 amount = uint256(uint128(delta.amount0()));
            console2.log("Settling ETH:", amount);
            poolManager.settle{value: amount}();
            console2.log("ETH settlement completed");
        } else if (delta.amount0() < 0) {
            // PoolManager owes ETH to us
            uint256 amount = uint256(uint128(-delta.amount0()));
            console2.log("Taking ETH:", amount);
            poolManager.take(swapParams.key.currency0, swapParams.sender, amount);
            console2.log("ETH take completed");
        } else {
            console2.log("ETH delta is zero");
        }

        // Handle currency1 (stETH)
        if (delta.amount1() > 0) {
            // We owe stETH to PoolManager
            uint256 amount = uint256(uint128(delta.amount1()));
            console2.log("Settling stETH:", amount);
            IERC20(Currency.unwrap(swapParams.key.currency1)).transferFrom(
                swapParams.sender,
                address(poolManager),
                amount
            );
            poolManager.settle();
            console2.log("stETH settlement completed");
        } else if (delta.amount1() < 0) {
            // PoolManager owes stETH to us
            uint256 amount = uint256(uint128(-delta.amount1()));
            console2.log("Taking stETH:", amount);
            poolManager.take(swapParams.key.currency1, swapParams.sender, amount);
            console2.log("stETH take completed");
        } else {
            console2.log("stETH delta is zero");
        }

        console2.log("All settlement operations completed");
    }

    /// @notice Allow contract to receive ETH
    receive() external payable {}
}