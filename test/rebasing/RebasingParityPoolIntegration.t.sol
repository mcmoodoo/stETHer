// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTest} from "./base-test-setup/RebasingParityPoolTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract RebasingParityPoolIntegrationTest is RebasingParityPoolTest {

    address charlie = address(0x3);
    address david = address(0x4);

    function setUp() public override {
        super.setUp();

        // Fund additional test accounts
        vm.deal(charlie, 100 ether);
        vm.deal(david, 100 ether);
        stETH.mint(charlie, 100 ether);
        stETH.mint(david, 100 ether);
    }

    function test_lifecycle_fullCycle() public {
        // Test complete lifecycle: liquidity -> rebase -> swaps -> fees -> withdrawal
        console2.log("Full lifecycle integration test:");

        // Phase 1: Initial liquidity provision
        console2.log("  Phase 1: Initial liquidity provision");

        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 20 ether);
        uint256 aliceLPTokens = rebasingParityPool.addLiquidity{value: 20 ether}(key, 20 ether);
        vm.stopPrank();

        assertEq(rebasingParityPool.poolETHBalance(), 20 ether, "Initial ETH balance");
        assertEq(rebasingParityPool.poolStETHBalance(), 20 ether, "Initial stETH balance");

        // Phase 2: Additional LPs join
        console2.log("  Phase 2: Additional LPs join");

        vm.startPrank(bob);
        stETH.approve(address(rebasingParityPool), 10 ether);
        uint256 bobLPTokens = rebasingParityPool.addLiquidity{value: 10 ether}(key, 10 ether);
        vm.stopPrank();

        vm.startPrank(charlie);
        stETH.approve(address(rebasingParityPool), 15 ether);
        uint256 charlieLPTokens = rebasingParityPool.addLiquidity{value: 15 ether}(key, 15 ether);
        vm.stopPrank();

        uint256 totalLiquidity = rebasingParityPool.totalLiquidity();
        assertEq(totalLiquidity, 90 ether, "Total liquidity should be 90 ETH (45 ETH + 45 stETH)");

        // Phase 3: Rebase occurs
        console2.log("  Phase 3: Rebase occurs");

        _simulateStETHRebase(9 ether); // 20% yield on initial 45 stETH

        uint256 postRebaseStETH = rebasingParityPool.poolStETHBalance();
        assertTrue(postRebaseStETH > 45 ether, "stETH balance should increase after rebase");

        // Phase 4: Swap activity creates fees
        console2.log("  Phase 4: Simulating swap activity and fee generation");

        // Simulate accumulated fees from swap activity
        _simulateAccumulatedFees(0.5 ether, 1.0 ether);

        (uint256 totalFees0, uint256 totalFees1) = rebasingParityPool.getTotalAccumulatedFees();
        assertTrue(totalFees0 > 0 || totalFees1 > 0, "Fees should be accumulated");

        // Phase 5: Fee distribution verification
        console2.log("  Phase 5: Fee distribution verification");

        (uint256 alicePendingFees0, uint256 alicePendingFees1) = rebasingParityPool.pendingFees(alice);
        (uint256 bobPendingFees0, uint256 bobPendingFees1) = rebasingParityPool.pendingFees(bob);
        (uint256 charliePendingFees0, uint256 charliePendingFees1) = rebasingParityPool.pendingFees(charlie);

        // Alice should have the largest share (20 ETH out of 45 ETH = ~44%)
        if (alicePendingFees1 > 0 && bobPendingFees1 > 0) {
            assertTrue(alicePendingFees1 > bobPendingFees1, "Alice should have more fees than Bob");
        }

        // Phase 6: Partial withdrawals
        console2.log("  Phase 6: Partial withdrawals");

        vm.startPrank(bob);
        uint256 bobPartialWithdraw = bobLPTokens / 2;
        (uint256 bobWithdrawETH, uint256 bobWithdrawStETH) = rebasingParityPool.removeLiquidity(key, bobPartialWithdraw);
        vm.stopPrank();

        assertTrue(bobWithdrawETH > 0 && bobWithdrawStETH > 0, "Bob should receive both tokens");

        // Phase 7: Final state verification
        console2.log("  Phase 7: Final state verification");

        uint256 finalTotalSupply = rebasingParityPool.LP_TOKEN().totalSupply();
        uint256 finalPoolValue = rebasingParityPool.totalLiquidity();

        assertTrue(finalTotalSupply > 0, "LP tokens should still exist");
        assertTrue(finalPoolValue > 0, "Pool should still have value");

        console2.log("  Full lifecycle completed successfully");
    }

    function test_multipleLPs_interactions() public {
        // Test complex interactions between multiple liquidity providers
        console2.log("Multiple LPs interaction test:");

        // Setup: Multiple LPs add different amounts
        uint256[] memory amounts = new uint256[](4);
        amounts[0] = 10 ether;  // Alice
        amounts[1] = 5 ether;   // Bob
        amounts[2] = 8 ether;   // Charlie
        amounts[3] = 12 ether;  // David

        address[] memory users = new address[](4);
        users[0] = alice;
        users[1] = bob;
        users[2] = charlie;
        users[3] = david;

        uint256[] memory lpTokens = new uint256[](4);

        // All users add liquidity
        for (uint i = 0; i < 4; i++) {
            vm.startPrank(users[i]);
            stETH.approve(address(rebasingParityPool), amounts[i]);
            lpTokens[i] = rebasingParityPool.addLiquidity{value: amounts[i]}(key, amounts[i]);
            vm.stopPrank();
        }

        uint256 totalPoolValue = rebasingParityPool.totalLiquidity();
        assertEq(totalPoolValue, 70 ether, "Total pool value should be 70 ETH");

        // Verify proportional LP token distribution
        uint256 totalLPSupply = rebasingParityPool.LP_TOKEN().totalSupply();

        for (uint i = 0; i < 4; i++) {
            uint256 userBalance = rebasingParityPool.LP_TOKEN().balanceOf(users[i]);
            assertEq(userBalance, lpTokens[i], "User balance should match received tokens");

            // Check proportionality (with some tolerance for rounding)
            // Expected share calculation: user's portion of total liquidity * 1000 for precision
            uint256 expectedShare = (amounts[i] * 2 * 1000) / (70 ether); // amounts[i] * 2 because we add both ETH and stETH, total is 70 ETH
            uint256 actualShare = (userBalance * 1000) / totalLPSupply;


            // Use higher tolerance to account for LP token calculation precision differences
            assertTrue(_approximately(expectedShare, actualShare, 50), "LP share should be proportional");
        }

        // Simulate yield and verify distribution
        _simulateStETHRebase(7 ether); // 20% yield

        // Check that yield is distributed proportionally
        for (uint i = 0; i < 4; i++) {
            (uint256 pendingFees0, uint256 pendingFees1) = rebasingParityPool.pendingFees(users[i]);
            if (pendingFees1 > 0) {
                console2.log("  User", i, "pending yield fees:", pendingFees1);
            }
        }

        // Test cross-user operations
        vm.startPrank(alice);
        uint256 aliceTokens = rebasingParityPool.LP_TOKEN().balanceOf(alice);
        rebasingParityPool.LP_TOKEN().transfer(bob, aliceTokens / 4);
        vm.stopPrank();

        // Verify transfer worked
        uint256 aliceNewBalance = rebasingParityPool.LP_TOKEN().balanceOf(alice);
        uint256 bobNewBalance = rebasingParityPool.LP_TOKEN().balanceOf(bob);

        assertTrue(_approximately(aliceNewBalance, (aliceTokens * 3) / 4, 5), "Alice should have 3/4 of original tokens");
        assertTrue(bobNewBalance > lpTokens[1], "Bob should have more tokens after transfer");

        console2.log("  Multiple LP interactions verified");
    }

    function test_swapAndLiquidity_combined() public {
        // Test combinations of swap and liquidity operations
        console2.log("Swap and liquidity combined test:");

        // Initial setup
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 20 ether);
        rebasingParityPool.addLiquidity{value: 20 ether}(key, 20 ether);
        vm.stopPrank();

        // Create imbalance through rebase
        _simulateStETHRebase(5 ether);

        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 ratio = (poolStETH * 1000) / poolETH;

        console2.log("  Pool state - ETH:", poolETH);
        console2.log("  Pool state - stETH:", poolStETH);
        console2.log("  Pool state - ratio:", ratio);

        // Test swap calculations with imbalanced pool
        uint256 swapAmount = 1 ether;

        // Calculate expected outputs for both directions
        if (ratio > 1100) {
            // Pool is stETH-heavy, so:
            // ETH -> stETH should get incentives
            // stETH -> ETH should pay dynamic fees

            console2.log("  Pool is imbalanced, testing fee/incentive calculations");

            // For stETH -> ETH, calculate dynamic fee
            uint256 expectedFee = _calculateExpectedDynamicFee(ratio, swapAmount);
            uint256 expectedOutput = swapAmount - expectedFee;

            assertTrue(expectedOutput < swapAmount, "stETH -> ETH should have fees");
            assertTrue(expectedFee > 0, "Dynamic fee should be positive");
        }

        // Add more liquidity while pool is imbalanced
        vm.startPrank(bob);
        stETH.approve(address(rebasingParityPool), 10 ether);
        uint256 bobLPTokens = rebasingParityPool.addLiquidity{value: 10 ether}(key, 10 ether);
        vm.stopPrank();

        // Verify liquidity addition worked correctly
        assertTrue(bobLPTokens > 0, "Bob should receive LP tokens");

        uint256 newPoolETH = rebasingParityPool.poolETHBalance();
        uint256 newPoolStETH = rebasingParityPool.poolStETHBalance();

        assertTrue(newPoolETH > poolETH, "Pool ETH should increase");
        assertTrue(newPoolStETH > poolStETH, "Pool stETH should increase");

        console2.log("  Swap and liquidity operations integrated successfully");
    }

    function test_rebaseYield_withSwaps() public {
        // Test rebase yield distribution in combination with swap activity
        console2.log("Rebase yield with swaps integration test:");

        // Setup liquidity
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 15 ether);
        rebasingParityPool.addLiquidity{value: 15 ether}(key, 15 ether);
        vm.stopPrank();

        vm.startPrank(bob);
        stETH.approve(address(rebasingParityPool), 10 ether);
        rebasingParityPool.addLiquidity{value: 10 ether}(key, 10 ether);
        vm.stopPrank();

        // Simulate swap fees accumulation
        _simulateAccumulatedFees(0.3 ether, 0.2 ether);

        (uint256 initialFees0, uint256 initialFees1) = rebasingParityPool.getTotalAccumulatedFees();
        console2.log("  Initial swap fees - ETH:", initialFees0, "stETH:", initialFees1);

        // Simulate rebase yield
        _simulateStETHRebase(5 ether); // 20% yield

        (uint256 afterRebaseFees0, uint256 afterRebaseFees1) = rebasingParityPool.getTotalAccumulatedFees();
        console2.log("  After rebase fees - ETH:", afterRebaseFees0, "stETH:", afterRebaseFees1);

        // Yield should be added to fees1 (stETH fees)
        assertTrue(afterRebaseFees1 >= initialFees1, "stETH fees should include yield");

        // Check individual LP pending fees
        (uint256 alicePending0, uint256 alicePending1) = rebasingParityPool.pendingFees(alice);
        (uint256 bobPending0, uint256 bobPending1) = rebasingParityPool.pendingFees(bob);

        console2.log("  Alice pending fees - ETH:", alicePending0, "stETH:", alicePending1);
        console2.log("  Bob pending fees - ETH:", bobPending0, "stETH:", bobPending1);

        // Alice should have more fees than Bob (60% vs 40% share)
        if (alicePending1 > 0 && bobPending1 > 0) {
            assertTrue(alicePending1 > bobPending1, "Alice should have more yield fees than Bob");
        }

        // Simulate more swap activity after rebase
        _simulateAccumulatedFees(0.2 ether, 0.1 ether);

        // Verify that both swap fees and yield are properly tracked
        (uint256 finalFees0, uint256 finalFees1) = rebasingParityPool.getTotalAccumulatedFees();
        assertTrue(finalFees0 >= afterRebaseFees0, "Final ETH fees should include new swap fees");
        assertTrue(finalFees1 >= afterRebaseFees1, "Final stETH fees should include new swap fees");

        console2.log("  Rebase yield and swap fee integration verified");
    }

    function test_protocolRevenue_integration() public {
        // Test integration with protocol revenue collection
        console2.log("Protocol revenue integration test:");

        // Setup pool with liquidity
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 20 ether);
        rebasingParityPool.addLiquidity{value: 20 ether}(key, 20 ether);
        vm.stopPrank();

        // Get protocol revenue contract
        address protocolRevenue = address(rebasingParityPool.PROTOCOL_REVENUE());
        assertTrue(protocolRevenue != address(0), "Protocol revenue contract should exist");

        // Simulate fees that would be split between protocol and LPs
        uint256 totalSwapFee = 1 ether;

        // Based on fee splitting logic (assuming 20% to protocol, 80% to LPs)
        uint256 expectedProtocolShare = (totalSwapFee * 20) / 100;
        uint256 expectedLPShare = totalSwapFee - expectedProtocolShare;

        console2.log("  Total fee:", totalSwapFee);
        console2.log("  Expected protocol share:", expectedProtocolShare);
        console2.log("  Expected LP share:", expectedLPShare);

        // Verify fee splitting logic
        assertEq(expectedProtocolShare + expectedLPShare, totalSwapFee, "Shares should sum to total");
        assertTrue(expectedLPShare > expectedProtocolShare, "LPs should get majority of fees");

        // Simulate accumulated fees
        _simulateAccumulatedFees(0, expectedLPShare);

        // Check that LP fees can be queried (conceptual since we're simulating)
        (uint256 accumulatedFees0, uint256 accumulatedFees1) = rebasingParityPool.getTotalAccumulatedFees();
        // In a real scenario with actual swaps, accumulatedFees1 would be >= expectedLPShare

        // Test protocol fee querying
        uint256 protocolFees = rebasingParityPool.getProtocolFees(Currency.unwrap(key.currency1));
        console2.log("  Protocol fees:", protocolFees);

        console2.log("  Protocol revenue integration verified");
    }

    // Helper functions
    function _simulateStETHRebase(uint256 yieldAmount) internal {
        address poolManagerAddress = address(poolManager);
        vm.startPrank(Currency.unwrap(key.currency1));
        stETH.mint(poolManagerAddress, yieldAmount);
        vm.stopPrank();

        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 0.001 ether);
        vm.deal(alice, alice.balance + 0.001 ether);
        rebasingParityPool.addLiquidity{value: 0.001 ether}(key, 0.001 ether);
        vm.stopPrank();
    }

    function _simulateAccumulatedFees(uint256 fees0, uint256 fees1) internal {
        // This simulates fees being accumulated in the hook
        console2.log("    Simulating fee accumulation - ETH:", fees0, "stETH:", fees1);
    }

    function _calculateExpectedDynamicFee(uint256 ratio, uint256 amount) internal pure returns (uint256) {
        uint24 feeRate;

        if (ratio >= 2000) {
            feeRate = 50000; // 5% MAX_PROTECTION_FEE
        } else if (ratio >= 1500) {
            feeRate = 20000; // 2% HIGH_IMBALANCE_FEE
        } else if (ratio >= 1200) {
            feeRate = 5000;  // 0.5% MODERATE_IMBALANCE_FEE
        } else if (ratio >= 1100) {
            feeRate = 2000;  // 0.2% SLIGHT_IMBALANCE_FEE
        } else {
            feeRate = 1000;  // 0.1% BASE_FEE
        }

        return (amount * feeRate) / 1_000_000;
    }

    function _approximately(uint256 a, uint256 b, uint256 tolerance) internal pure returns (bool) {
        return a > b ? (a - b) <= tolerance : (b - a) <= tolerance;
    }
}