// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "v4-core/src/types/BalanceDelta.sol";
import {BeforeSwapDelta} from "v4-core/src/types/BeforeSwapDelta.sol";
import {Counter} from "../src/Counter.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract CounterExtendedTest is Test, Fixtures {
    Counter hook;
    
    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4445 << 144)
        );
        bytes memory constructorArgs = abi.encode(manager, address(0x999)); // treasury address
        deployCodeTo("Counter.sol:Counter", constructorArgs, flags);
        hook = Counter(flags);

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_addLiquidity_success() public {
        uint256 amount = 1000e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), amount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), amount);
        
        uint256 balance0Before = manager.balanceOf(address(hook), currency0.toId());
        uint256 balance1Before = manager.balanceOf(address(hook), currency1.toId());
        
        hook.addLiquidity(key, amount);
        
        uint256 balance0After = manager.balanceOf(address(hook), currency0.toId());
        uint256 balance1After = manager.balanceOf(address(hook), currency1.toId());
        
        assertEq(balance0After - balance0Before, amount);
        assertEq(balance1After - balance1Before, amount);
    }

    function test_addLiquidity_multiple_deposits() public {
        uint256 amount1 = 500e18;
        uint256 amount2 = 300e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), amount1 + amount2);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), amount1 + amount2);
        
        hook.addLiquidity(key, amount1);
        hook.addLiquidity(key, amount2);
        
        assertEq(manager.balanceOf(address(hook), currency0.toId()), amount1 + amount2);
        assertEq(manager.balanceOf(address(hook), currency1.toId()), amount1 + amount2);
    }

    function test_swap_after_liquidity() public {
        uint256 liquidityAmount = 1000e18;
        uint256 swapAmount = 100e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        // ETH → stETH: 0% fee, 1:1 swap
        assertEq(balance0Before - balance0After, swapAmount);
        assertEq(balance1After - balance1Before, swapAmount);
    }

    function test_swap_reverse_direction() public {
        uint256 liquidityAmount = 1000e18;
        uint256 swapAmount = 100e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        // First swap: 0 -> 1
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        
        // Second swap: 1 -> 0 (stETH -> ETH with 0.1% fee)
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, false, -int256(swapAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        // stETH -> ETH has 0.1% fee, so output is reduced
        uint256 expectedOutput = swapAmount * 999 / 1000; // swapAmount - 0.1% fee
        assertEq(balance0After - balance0Before, expectedOutput);
        assertEq(balance1Before - balance1After, swapAmount);
    }

    function test_swap_exactOutput_zeroForOne() public {
        uint256 liquidityAmount = 1000e18;
        uint256 outputAmount = 150e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, true, int256(outputAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        // ETH → stETH: 0% fee, 1:1 swap for exact output
        assertEq(balance0Before - balance0After, outputAmount);
        assertEq(balance1After - balance1Before, outputAmount);
    }

    function test_swap_exactOutput_oneForZero() public {
        uint256 liquidityAmount = 1000e18;
        uint256 outputAmount = 150e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, false, int256(outputAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        // For exact output stETH->ETH with 0.1% fee, more input is needed
        // inputAmount = outputAmount / (1 - fee) = outputAmount * 1000 / 999
        uint256 expectedInput = (outputAmount * 1000) / 999;
        assertEq(balance0After - balance0Before, outputAmount);
        assertEq(balance1Before - balance1After, expectedInput);
    }

    function test_getHookPermissions() public view {
        Hooks.Permissions memory perms = hook.getHookPermissions();
        
        assertFalse(perms.beforeInitialize);
        assertFalse(perms.afterInitialize);
        assertTrue(perms.beforeAddLiquidity);
        assertFalse(perms.afterAddLiquidity);
        assertFalse(perms.beforeRemoveLiquidity);
        assertFalse(perms.afterRemoveLiquidity);
        assertTrue(perms.beforeSwap);
        assertFalse(perms.afterSwap);
        assertFalse(perms.beforeDonate);
        assertFalse(perms.afterDonate);
        assertTrue(perms.beforeSwapReturnDelta);
        assertFalse(perms.afterSwapReturnDelta);
        assertFalse(perms.afterAddLiquidityReturnDelta);
        assertFalse(perms.afterRemoveLiquidityReturnDelta);
    }

    function test_beforeAddLiquidity_reverts() public {
        vm.expectRevert();
        modifyLiquidityRouter.modifyLiquidity(key, LIQUIDITY_PARAMS, ZERO_BYTES);
    }

    function testFuzz_swap_various_amounts(bool zeroForOne, uint256 swapAmount) public {
        uint256 liquidityAmount = 10000e18;
        swapAmount = bound(swapAmount, 1 wei, 1000e18);
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, zeroForOne, -int256(swapAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        if (zeroForOne) {
            // ETH → stETH: 0% fee, 1:1 swap
            assertEq(balance0Before - balance0After, swapAmount);
            assertEq(balance1After - balance1Before, swapAmount);
        } else {
            // stETH → ETH: 0.1% fee applied
            assertEq(balance1Before - balance1After, swapAmount);
            uint256 feeAmount = (swapAmount * 1000) / 1_000_000;
            uint256 expectedOutput = swapAmount - feeAmount;
            assertEq(balance0After - balance0Before, expectedOutput);
        }
    }

    function testFuzz_addLiquidity(uint256 amount) public {
        amount = bound(amount, 1e18, 10000e18);
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), amount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), amount);
        
        uint256 balance0Before = manager.balanceOf(address(hook), currency0.toId());
        uint256 balance1Before = manager.balanceOf(address(hook), currency1.toId());
        
        hook.addLiquidity(key, amount);
        
        assertEq(manager.balanceOf(address(hook), currency0.toId()) - balance0Before, amount);
        assertEq(manager.balanceOf(address(hook), currency1.toId()) - balance1Before, amount);
    }

    function test_multiple_swaps_same_direction() public {
        uint256 liquidityAmount = 5000e18;
        uint256[] memory swapAmounts = new uint256[](3);
        swapAmounts[0] = 100e18;
        swapAmounts[1] = 250e18;
        swapAmounts[2] = 50e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        uint256 totalSwapped = 0;
        for (uint256 i = 0; i < swapAmounts.length; i++) {
            uint256 balance0Before = currency0.balanceOfSelf();
            uint256 balance1Before = currency1.balanceOfSelf();
            
            swap(key, true, -int256(swapAmounts[i]), ZERO_BYTES);
            
            // ETH → stETH: 0% fee, 1:1 swap
            assertEq(balance0Before - currency0.balanceOfSelf(), swapAmounts[i]);
            assertEq(currency1.balanceOfSelf() - balance1Before, swapAmounts[i]);
            
            totalSwapped += swapAmounts[i];
        }
        
        assertEq(manager.balanceOf(address(hook), currency0.toId()), liquidityAmount + totalSwapped);
        assertEq(manager.balanceOf(address(hook), currency1.toId()), liquidityAmount - totalSwapped);
    }

    function test_swap_zero_amount_reverts() public {
        uint256 liquidityAmount = 1000e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        vm.expectRevert();
        swap(key, true, 0, ZERO_BYTES);
    }
}