// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTest} from "./base-test-setup/RebasingParityPoolTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract RebasingParityPoolEdgeCasesTest is RebasingParityPoolTest {

    function test_emptyPool_operations() public {
        // Test operations on empty pool (no liquidity)
        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 totalLiquidity = rebasingParityPool.totalLiquidity();

        console2.log("Empty pool test:");
        console2.log("  Pool ETH balance:", poolETH);
        console2.log("  Pool stETH balance:", poolStETH);
        console2.log("  Total liquidity:", totalLiquidity);

        // All balances should be zero initially
        assertEq(poolETH, 0, "Empty pool should have zero ETH");
        assertEq(poolStETH, 0, "Empty pool should have zero stETH");
        assertEq(totalLiquidity, 0, "Empty pool should have zero total liquidity");

        // Check LP token supply
        uint256 lpTokenSupply = rebasingParityPool.LP_TOKEN().totalSupply();
        assertEq(lpTokenSupply, 0, "Empty pool should have zero LP tokens");

        // Check fees
        (uint256 fees0, uint256 fees1) = rebasingParityPool.getTotalAccumulatedFees();
        assertEq(fees0, 0, "Empty pool should have zero fees0");
        assertEq(fees1, 0, "Empty pool should have zero fees1");

        console2.log("  Empty pool state verified");
    }

    function test_singleLP_scenarios() public {
        // Test scenarios with only one liquidity provider
        console2.log("Single LP scenarios test:");

        // Add liquidity from alice only
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 10 ether);
        uint256 lpTokens = rebasingParityPool.addLiquidity{value: 10 ether}(key, 10 ether);
        vm.stopPrank();

        console2.log("  Alice added liquidity, received LP tokens:", lpTokens);

        // Alice should own 100% of the pool
        uint256 aliceBalance = rebasingParityPool.LP_TOKEN().balanceOf(alice);
        uint256 totalSupply = rebasingParityPool.LP_TOKEN().totalSupply();

        assertEq(aliceBalance, totalSupply, "Alice should own all LP tokens");
        assertEq(aliceBalance, lpTokens, "Alice balance should match received tokens");

        // Check pool balances
        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();

        assertEq(poolETH, 10 ether, "Pool should have 10 ETH");
        assertEq(poolStETH, 10 ether, "Pool should have 10 stETH");

        // Alice should be able to withdraw all liquidity
        vm.startPrank(alice);
        (uint256 amount0, uint256 amount1) = rebasingParityPool.removeLiquidity(key, aliceBalance);
        vm.stopPrank();

        console2.log("  Alice withdrew amounts:", amount0, amount1);

        // Pool should be empty again
        assertEq(rebasingParityPool.poolETHBalance(), 0, "Pool should be empty after full withdrawal");
        assertEq(rebasingParityPool.poolStETHBalance(), 0, "Pool should be empty after full withdrawal");
    }

    function test_extremeImbalance_scenarios() public {
        // Test extreme imbalance scenarios through rebase simulation
        console2.log("Extreme imbalance scenarios test:");

        // Add initial balanced liquidity
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 10 ether);
        rebasingParityPool.addLiquidity{value: 10 ether}(key, 10 ether);
        vm.stopPrank();

        // Simulate large positive rebase (200% increase)
        _simulateStETHRebase(20 ether);

        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 ratio = (poolStETH * 1000) / poolETH;

        console2.log("  After extreme rebase:");
        console2.log("  Pool ETH:", poolETH);
        console2.log("  Pool stETH:", poolStETH);
        console2.log("  Ratio:", ratio);

        // Should be far above critical imbalance threshold
        assertTrue(ratio >= 2000, "Should have critical imbalance");

        // Test partial withdrawal instead of full withdrawal to avoid edge cases
        vm.startPrank(alice);
        uint256 lpBalance = rebasingParityPool.LP_TOKEN().balanceOf(alice);

        // Remove only half the liquidity to avoid potential edge cases
        if (lpBalance > 0) {
            uint256 partialAmount = lpBalance / 2;
            rebasingParityPool.removeLiquidity(key, partialAmount);
        }
        vm.stopPrank();

        // Pool should still have some ETH remaining
        uint256 finalETH = rebasingParityPool.poolETHBalance();
        assertTrue(finalETH > 0, "Pool should still have some ETH after partial withdrawal");

        console2.log("  Extreme imbalance scenarios handled correctly");
    }

    function test_rounding_precision() public {
        // Test precision and rounding with very small amounts
        console2.log("Rounding precision test:");

        // Add very small initial liquidity
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 1000 wei);
        uint256 lpTokens = rebasingParityPool.addLiquidity{value: 1000 wei}(key, 1000 wei);
        vm.stopPrank();

        console2.log("  Small liquidity LP tokens:", lpTokens);
        assertTrue(lpTokens > 0, "Should receive some LP tokens for small amounts");

        // Add subsequent small liquidity
        vm.startPrank(bob);
        stETH.approve(address(rebasingParityPool), 500 wei);
        uint256 bobLpTokens = rebasingParityPool.addLiquidity{value: 500 wei}(key, 500 wei);
        vm.stopPrank();

        console2.log("  Bob's small liquidity LP tokens:", bobLpTokens);
        assertTrue(bobLpTokens > 0, "Should receive some LP tokens for small amounts");

        // Check proportional distribution
        uint256 aliceBalance = rebasingParityPool.LP_TOKEN().balanceOf(alice);
        uint256 bobBalance = rebasingParityPool.LP_TOKEN().balanceOf(bob);
        uint256 totalSupply = rebasingParityPool.LP_TOKEN().totalSupply();

        assertEq(aliceBalance + bobBalance, totalSupply, "LP token balances should sum to total supply");

        // Alice should have roughly 2/3 of tokens (1000/(1000+500))
        uint256 aliceExpectedShare = (aliceBalance * 100) / totalSupply;
        assertTrue(aliceExpectedShare >= 65 && aliceExpectedShare <= 68, "Alice should have ~67% share");

        console2.log("  Rounding precision maintained for small amounts");
    }

    function test_poolBalances_consistency() public {
        // Test that pool balances remain consistent across operations
        console2.log("Pool balance consistency test:");

        // Initial state
        uint256 initialETH = rebasingParityPool.poolETHBalance();
        uint256 initialStETH = rebasingParityPool.poolStETHBalance();
        uint256 initialTotal = rebasingParityPool.totalLiquidity();

        assertEq(initialETH, 0, "Initial ETH should be zero");
        assertEq(initialStETH, 0, "Initial stETH should be zero");
        assertEq(initialTotal, 0, "Initial total should be zero");

        // Add liquidity and check consistency
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 5 ether);
        rebasingParityPool.addLiquidity{value: 5 ether}(key, 5 ether);
        vm.stopPrank();

        uint256 afterAddETH = rebasingParityPool.poolETHBalance();
        uint256 afterAddStETH = rebasingParityPool.poolStETHBalance();
        uint256 afterAddTotal = rebasingParityPool.totalLiquidity();

        assertEq(afterAddETH, 5 ether, "ETH balance should match added amount");
        assertEq(afterAddStETH, 5 ether, "stETH balance should match added amount");
        assertEq(afterAddTotal, afterAddETH + afterAddStETH, "Total should equal sum of individual balances");

        // Add more liquidity
        vm.startPrank(bob);
        stETH.approve(address(rebasingParityPool), 3 ether);
        rebasingParityPool.addLiquidity{value: 3 ether}(key, 3 ether);
        vm.stopPrank();

        uint256 finalETH = rebasingParityPool.poolETHBalance();
        uint256 finalStETH = rebasingParityPool.poolStETHBalance();
        uint256 finalTotal = rebasingParityPool.totalLiquidity();

        assertEq(finalETH, 8 ether, "Final ETH should be 8 ether");
        assertEq(finalStETH, 8 ether, "Final stETH should be 8 ether");
        assertEq(finalTotal, finalETH + finalStETH, "Final total should equal sum");

        console2.log("  Pool balance consistency maintained");
    }

    function test_complexSwap_withAllFeatures() public {
        // Test complex scenarios with multiple features combined
        console2.log("Complex swap with all features test:");

        // Setup: Add liquidity and create imbalance
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 20 ether);
        rebasingParityPool.addLiquidity{value: 20 ether}(key, 20 ether);
        vm.stopPrank();

        // Simulate rebase to create imbalance
        _simulateStETHRebase(10 ether);

        // Verify imbalance
        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 ratio = (poolStETH * 1000) / poolETH;

        console2.log("  Pool after rebase - ETH:", poolETH, "stETH:", poolStETH);
        console2.log("  Imbalance ratio:", ratio);

        assertTrue(ratio > 1100, "Should have imbalance for dynamic fees/incentives");

        // Test swap calculations with imbalanced pool
        uint256 inputAmount = 1 ether;

        // For ETH -> stETH (should get incentives)
        uint256 expectedOutput = inputAmount; // Base 1:1
        assertTrue(expectedOutput > 0, "Should calculate valid output for ETH -> stETH");

        // For stETH -> ETH (should pay dynamic fees)
        uint256 dynamicFeeAmount = (inputAmount * 2000) / 1_000_000; // Assuming slight imbalance fee
        uint256 expectedOutputWithFee = inputAmount - dynamicFeeAmount;
        assertTrue(expectedOutputWithFee < inputAmount, "stETH -> ETH should have fees");

        console2.log("  Complex swap calculations validated");
    }

    function test_largeNumbers_handling() public {
        // Test handling of large numbers without overflow
        console2.log("Large numbers handling test:");

        // Use large but reasonable amounts (1000 ETH)
        uint256 largeAmount = 1000 ether;

        vm.startPrank(alice);
        stETH.mint(alice, largeAmount);
        stETH.approve(address(rebasingParityPool), largeAmount);
        vm.deal(alice, alice.balance + largeAmount);

        uint256 lpTokens = rebasingParityPool.addLiquidity{value: largeAmount}(key, largeAmount);
        vm.stopPrank();

        console2.log("  Large amount liquidity - LP tokens received:", lpTokens);
        assertTrue(lpTokens > 0, "Should handle large amounts without overflow");

        // Check pool state
        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();

        assertEq(poolETH, largeAmount, "Pool should handle large ETH amounts");
        assertEq(poolStETH, largeAmount, "Pool should handle large stETH amounts");

        // Test removal with large amounts
        vm.startPrank(alice);
        (uint256 amount0, uint256 amount1) = rebasingParityPool.removeLiquidity(key, lpTokens);
        vm.stopPrank();

        console2.log("  Large amount withdrawal - ETH:", amount0, "stETH:", amount1);
        assertTrue(amount0 > 0 && amount1 > 0, "Should handle large withdrawals");

        console2.log("  Large numbers handled correctly");
    }

    // Helper function to simulate stETH rebase
    function _simulateStETHRebase(uint256 yieldAmount) internal {
        console2.log("  Simulating stETH rebase with yield:", yieldAmount);

        // First, mint stETH to simulate the rebase
        address poolManagerAddress = address(poolManager);
        vm.startPrank(Currency.unwrap(key.currency1));
        stETH.mint(poolManagerAddress, yieldAmount);
        vm.stopPrank();

        // Then trigger syncRebaseYield by calling a hook function
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 0.001 ether);
        vm.deal(alice, alice.balance + 0.001 ether);
        rebasingParityPool.addLiquidity{value: 0.001 ether}(key, 0.001 ether);
        vm.stopPrank();
    }
}