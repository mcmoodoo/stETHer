// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTest} from "./base-test-setup/RebasingParityPoolTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {RebasingParityPool} from "src/RebasingParityPool.sol";
import {ProtocolRevenue} from "src/ProtocolRevenue.sol";
import {ParityLP} from "src/ParityLP.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {PoolId, PoolIdLibrary} from "@uniswap/v4-core/src/types/PoolId.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

contract RebasingParityPoolSetupTest is RebasingParityPoolTest {
    using PoolIdLibrary for PoolKey;

    function test_getHookPermissions() public view {
        Hooks.Permissions memory permissions = rebasingParityPool.getHookPermissions();

        assertFalse(permissions.beforeInitialize, "beforeInitialize should be false");
        assertFalse(permissions.afterInitialize, "afterInitialize should be false");
        assertTrue(permissions.beforeAddLiquidity, "beforeAddLiquidity should be true");
        assertFalse(permissions.afterAddLiquidity, "afterAddLiquidity should be false");
        assertFalse(permissions.beforeRemoveLiquidity, "beforeRemoveLiquidity should be false");
        assertFalse(permissions.afterRemoveLiquidity, "afterRemoveLiquidity should be false");
        assertTrue(permissions.beforeSwap, "beforeSwap should be true");
        assertFalse(permissions.afterSwap, "afterSwap should be false");
        assertFalse(permissions.beforeDonate, "beforeDonate should be false");
        assertFalse(permissions.afterDonate, "afterDonate should be false");
        assertTrue(permissions.beforeSwapReturnDelta, "beforeSwapReturnDelta should be true");
        assertFalse(permissions.afterSwapReturnDelta, "afterSwapReturnDelta should be false");
        assertFalse(permissions.afterAddLiquidityReturnDelta, "afterAddLiquidityReturnDelta should be false");
        assertFalse(permissions.afterRemoveLiquidityReturnDelta, "afterRemoveLiquidityReturnDelta should be false");

        console2.log("Hook permissions verified:");
        console2.log("  beforeAddLiquidity:", permissions.beforeAddLiquidity);
        console2.log("  beforeSwap:", permissions.beforeSwap);
        console2.log("  beforeSwapReturnDelta:", permissions.beforeSwapReturnDelta);
    }

    function test_constructor_setsCorrectParameters() public view {
        ParityLP lpToken = ParityLP(address(rebasingParityPool.LP_TOKEN()));
        assertEq(address(lpToken) != address(0), true, "LP_TOKEN should be set");

        address protocolRevenueAddress = address(rebasingParityPool.PROTOCOL_REVENUE());
        assertEq(protocolRevenueAddress != address(0), true, "PROTOCOL_REVENUE should be set");

        assertEq(rebasingParityPool.poolETHBalance(), 0, "Initial ETH balance should be 0");
        assertEq(rebasingParityPool.poolStETHBalance(), 0, "Initial stETH balance should be 0");
        assertEq(rebasingParityPool.poolStETHPrincipal(), 0, "Initial stETH principal should be 0");
        assertEq(rebasingParityPool.totalLiquidity(), 0, "Initial total liquidity should be 0");
        assertEq(rebasingParityPool.accumulatedFees0(), 0, "Initial accumulated fees0 should be 0");
        assertEq(rebasingParityPool.accumulatedFees1(), 0, "Initial accumulated fees1 should be 0");
        assertEq(rebasingParityPool.feesPerLpToken0(), 0, "Initial fees per LP token0 should be 0");
        assertEq(rebasingParityPool.feesPerLpToken1(), 0, "Initial fees per LP token1 should be 0");

        console2.log("Constructor parameters verified:");
        console2.log("  LP_TOKEN address:", address(lpToken));
        console2.log("  PROTOCOL_REVENUE address:", protocolRevenueAddress);
    }

    function test_onlyAllowedPool_modifier() public {
        // First, establish the allowed pool by using the correct key
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 10 ether);
        uint256 lpTokens = rebasingParityPool.addLiquidity{value: 10 ether}(key, 10 ether);
        assertTrue(lpTokens > 0, "Should successfully add liquidity with correct pool");

        // Now try to use a different pool key - should fail
        PoolKey memory wrongKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(address(2)), // Different token
            fee: 500,
            tickSpacing: 10,
            hooks: IHooks(address(rebasingParityPool))
        });

        stETH.approve(address(rebasingParityPool), 1 ether);
        vm.expectRevert("Hook: unauthorized pool");
        rebasingParityPool.addLiquidity{value: 1 ether}(wrongKey, 1 ether);

        vm.expectRevert("Hook: unauthorized pool");
        rebasingParityPool.removeLiquidity(wrongKey, lpTokens);

        console2.log("onlyAllowedPool modifier verified:");
        console2.log("  Correct pool accepted: true");
        console2.log("  Wrong pool rejected: true");

        vm.stopPrank();
    }

    function test_deployment_withCorrectAddress() public view {
        address hookAddress = address(rebasingParityPool);

        bool hasBeforeAddLiquidity = Hooks.hasPermission(IHooks(hookAddress), Hooks.BEFORE_ADD_LIQUIDITY_FLAG);
        bool hasBeforeSwap = Hooks.hasPermission(IHooks(hookAddress), Hooks.BEFORE_SWAP_FLAG);
        bool hasBeforeSwapReturnsDelta = Hooks.hasPermission(IHooks(hookAddress), Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG);

        assertTrue(hasBeforeAddLiquidity, "Hook address should have BEFORE_ADD_LIQUIDITY_FLAG");
        assertTrue(hasBeforeSwap, "Hook address should have BEFORE_SWAP_FLAG");
        assertTrue(hasBeforeSwapReturnsDelta, "Hook address should have BEFORE_SWAP_RETURNS_DELTA_FLAG");

        bool hasAfterSwap = Hooks.hasPermission(IHooks(hookAddress), Hooks.AFTER_SWAP_FLAG);
        bool hasBeforeInitialize = Hooks.hasPermission(IHooks(hookAddress), Hooks.BEFORE_INITIALIZE_FLAG);
        bool hasAfterAddLiquidity = Hooks.hasPermission(IHooks(hookAddress), Hooks.AFTER_ADD_LIQUIDITY_FLAG);
        assertFalse(hasAfterSwap, "Hook address should not have AFTER_SWAP_FLAG");
        assertFalse(hasBeforeInitialize, "Hook address should not have BEFORE_INITIALIZE_FLAG");
        assertFalse(hasAfterAddLiquidity, "Hook address should not have AFTER_ADD_LIQUIDITY_FLAG");

        console2.log("Hook deployment address verified:");
        console2.log("  Hook address:", hookAddress);
        console2.log("  Has BEFORE_ADD_LIQUIDITY flag:", hasBeforeAddLiquidity);
        console2.log("  Has BEFORE_SWAP flag:", hasBeforeSwap);
        console2.log("  Has BEFORE_SWAP_RETURNS_DELTA flag:", hasBeforeSwapReturnsDelta);
    }
}