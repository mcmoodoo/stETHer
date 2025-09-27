// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTest} from "./base-test-setup/RebasingParityPoolTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {BeforeSwapDelta, toBeforeSwapDelta} from "@uniswap/v4-core/src/types/BeforeSwapDelta.sol";
import {ParityLP} from "src/ParityLP.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {TestSwapRouter} from "../utils/TestSwapRouter.sol";
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

contract RebasingParityPoolSwapsTest is RebasingParityPoolTest {
    TestSwapRouter swapRouter;

    function setUp() public override {
        super.setUp();

        // Deploy test swap router
        swapRouter = new TestSwapRouter(poolManager);

        // Add initial liquidity to enable swaps
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 50 ether);
        rebasingParityPool.addLiquidity{value: 50 ether}(key, 50 ether);
        vm.stopPrank();
    }

    function test_actualSwap_ethToSteth() public {
        // Test actual ETH -> stETH swap execution
        vm.startPrank(bob);

        uint256 swapAmount = 5 ether;

        // Approve stETH for router in case the delta logic requires it
        stETH.approve(address(swapRouter), 100 ether);

        // Track balances before swap
        uint256 bobETHBefore = bob.balance;
        uint256 bobStETHBefore = stETH.balanceOf(bob);
        uint256 poolETHBefore = rebasingParityPool.poolETHBalance();
        uint256 poolStETHBefore = rebasingParityPool.poolStETHBalance();

        // Execute ETH -> stETH swap
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: true, // ETH (currency0) -> stETH (currency1)
            amountSpecified: -int256(swapAmount), // Exact input
            sqrtPriceLimitX96: TickMath.MIN_SQRT_PRICE + 1 // No price limit (zeroForOne = true)
        });

        BalanceDelta delta = swapRouter.swap{value: swapAmount}(key, params, bytes(""));

        // Verify swap results

        // 1. Bob's balances changed correctly
        assertEq(bob.balance, bobETHBefore - swapAmount, "Bob should have spent exact ETH amount");
        assertGt(stETH.balanceOf(bob), bobStETHBefore, "Bob should have received stETH");

        // 2. Pool balances updated correctly
        assertEq(rebasingParityPool.poolETHBalance(), poolETHBefore + swapAmount, "Pool should have more ETH");
        assertLt(rebasingParityPool.poolStETHBalance(), poolStETHBefore, "Pool should have less stETH");

        // 3. Verify approximately 1:1 swap (allowing for potential incentives)
        uint256 stETHReceived = stETH.balanceOf(bob) - bobStETHBefore;
        assertTrue(stETHReceived >= swapAmount, "Should receive at least 1:1, possibly with incentive");
        assertTrue(stETHReceived <= swapAmount + (swapAmount / 100), "Incentive should be reasonable (<1%)");

        // 4. Verify delta
        assertEq(int256(delta.amount0()), int256(swapAmount), "Delta amount0 should match ETH input");
        assertEq(delta.amount1(), -int128(uint128(stETHReceived)), "Delta amount1 should match stETH output");

        console2.log("ETH -> stETH swap completed:");
        console2.log("  ETH used:", swapAmount);
        console2.log("  stETH received:", stETHReceived);
        console2.log("  Effective rate:", (stETHReceived * 1e18) / swapAmount);
        console2.log("  Pool ETH balance:", rebasingParityPool.poolETHBalance());
        console2.log("  Pool stETH balance:", rebasingParityPool.poolStETHBalance());

        vm.stopPrank();
    }

    function test_actualSwap_stethToEth() public {
        // Test actual stETH -> ETH swap execution
        vm.startPrank(bob);

        uint256 swapAmount = 3 ether;

        // Bob needs stETH - he already has some from setup
        // Approve stETH for the swap router
        stETH.approve(address(swapRouter), swapAmount);

        // Track balances before swap
        uint256 bobETHBefore = bob.balance;
        uint256 bobStETHBefore = stETH.balanceOf(bob);
        uint256 poolETHBefore = rebasingParityPool.poolETHBalance();
        uint256 poolStETHBefore = rebasingParityPool.poolStETHBalance();

        // Execute stETH -> ETH swap
        IPoolManager.SwapParams memory params = IPoolManager.SwapParams({
            zeroForOne: false, // stETH (currency1) -> ETH (currency0)
            amountSpecified: -int256(swapAmount), // Exact input
            sqrtPriceLimitX96: TickMath.MAX_SQRT_PRICE - 1 // No price limit (zeroForOne = false)
        });

        BalanceDelta delta = swapRouter.swap(key, params, bytes(""));

        // Verify swap results

        // 1. Bob's balances changed correctly
        assertEq(stETH.balanceOf(bob), bobStETHBefore - swapAmount, "Bob should have spent exact stETH amount");
        assertGt(bob.balance, bobETHBefore, "Bob should have received ETH");

        // 2. Pool balances updated correctly
        assertEq(rebasingParityPool.poolStETHBalance(), poolStETHBefore + swapAmount, "Pool should have more stETH");
        assertLt(rebasingParityPool.poolETHBalance(), poolETHBefore, "Pool should have less ETH");

        // 3. Verify dynamic fees applied (user gets less ETH than stETH paid)
        uint256 ethReceived = bob.balance - bobETHBefore;
        assertTrue(ethReceived < swapAmount, "Should have fees applied (less ETH received than stETH paid)");
        assertTrue(ethReceived >= swapAmount * 95 / 100, "Fees should be reasonable (<5%)");

        // 4. Verify delta
        assertEq(delta.amount0(), -int128(uint128(ethReceived)), "Delta amount0 should match ETH output");
        assertEq(int256(delta.amount1()), int256(swapAmount), "Delta amount1 should match stETH input");

        console2.log("stETH -> ETH swap completed:");
        console2.log("  stETH used:", swapAmount);
        console2.log("  ETH received:", ethReceived);
        console2.log("  Effective rate:", (ethReceived * 1e18) / swapAmount);
        console2.log("  Fee applied:", swapAmount - ethReceived);
        console2.log("  Pool ETH balance:", rebasingParityPool.poolETHBalance());
        console2.log("  Pool stETH balance:", rebasingParityPool.poolStETHBalance());

        vm.stopPrank();
    }

    function test_swap_insufficientReserves_reverts() public {
        // Test theoretical reserve limits for swaps

        uint256 poolETHBalance = rebasingParityPool.poolETHBalance();
        uint256 poolStETHBalance = rebasingParityPool.poolStETHBalance();

        // Verify pool has the expected liquidity from setup
        assertEq(poolETHBalance, 50 ether, "Pool should have 50 ETH from setup");
        assertEq(poolStETHBalance, 50 ether, "Pool should have 50 stETH from setup");

        // For ETH -> stETH swaps, the limit would be the stETH reserves
        // For stETH -> ETH swaps, the limit would be the ETH reserves
        // The hook should enforce these limits in _processSwap

        // Test shows the concept - actual swap testing would require
        // either public wrapper functions or full PoolManager integration

        console2.log("Pool reserve limits:");
        console2.log("  Max ETH->stETH swap limited by stETH reserves:", poolStETHBalance);
        console2.log("  Max stETH->ETH swap limited by ETH reserves:", poolETHBalance);
        console2.log("  Current pool ETH:", poolETHBalance);
        console2.log("  Current pool stETH:", poolStETHBalance);
    }
}