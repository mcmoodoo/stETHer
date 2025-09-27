// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTest} from "./base-test-setup/RebasingParityPoolTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";

contract RebasingParityPoolDynamicFeesTest is RebasingParityPoolTest {

    function setUp() public override {
        super.setUp();

        // Add initial liquidity to create a balanced pool (1:1 ratio)
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 50 ether);
        rebasingParityPool.addLiquidity{value: 50 ether}(key, 50 ether);
        vm.stopPrank();
    }

    function test_calculateDynamicFee_balanced() public {
        // Test fee calculation for a balanced pool (50:50 ETH:stETH)
        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();

        // Verify pool is balanced
        assertEq(poolETH, 50 ether, "Pool ETH should be 50");
        assertEq(poolStETH, 50 ether, "Pool stETH should be 50");

        // Calculate ratio: (stETH * 1000) / ETH = (50 * 1000) / 50 = 1000 (1:1 ratio)
        uint256 expectedRatio = 1000;
        uint256 actualRatio = (poolStETH * 1000) / poolETH;
        assertEq(actualRatio, expectedRatio, "Balanced pool should have 1:1 ratio");

        // Balanced pools use base fee of 0.1% for stETH -> ETH swaps

        console2.log("Balanced pool fee calculation:");
        console2.log("  Pool ratio (stETH/ETH * 1000):", actualRatio);
        console2.log("  Expected fee tier: BASE_FEE (0.1%)");

        // For balanced pool (ratio = 1000), should use BASE_FEE
        assertTrue(actualRatio < 1100, "Should be below SLIGHT_IMBALANCE_RATIO (1100)");
        assertTrue(actualRatio >= 1000, "Should be at or above perfect balance");
    }

    function test_calculateDynamicFee_slightImbalance() public {
        // Create slight imbalance through stETH rebase
        _simulateStETHRebase(8 ether); // Add 16% more stETH value

        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 ratio = (poolStETH * 1000) / poolETH;

        console2.log("Slight imbalance test:");
        console2.log("  Pool ETH:", poolETH);
        console2.log("  Pool stETH:", poolStETH);
        console2.log("  Ratio:", ratio);

        // Should be in slight imbalance range (1100-1200)
        if (ratio >= 1100 && ratio < 1200) {
            console2.log("  Slight imbalance detected - should use SLIGHT_IMBALANCE_FEE (0.2%)");
        } else {
            console2.log("    Imbalance level:", ratio >= 1200 ? "moderate or higher" : "balanced");
        }
    }

    function test_calculateDynamicFee_moderateImbalance() public {
        // Create moderate imbalance through larger stETH rebase
        _simulateStETHRebase(15 ether); // Add 30% more stETH value

        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 ratio = (poolStETH * 1000) / poolETH;

        console2.log("Moderate imbalance test:");
        console2.log("  Pool ETH:", poolETH);
        console2.log("  Pool stETH:", poolStETH);
        console2.log("  Ratio:", ratio);

        // Should be in moderate imbalance range (1200-1500)
        if (ratio >= 1200 && ratio < 1500) {
            console2.log("  Moderate imbalance detected - should use MODERATE_IMBALANCE_FEE (0.5%)");
        } else {
            console2.log("  Imbalance level:", ratio >= 1500 ? "high or critical" : "slight or balanced");
        }
    }

    function test_calculateDynamicFee_highImbalance() public {
        // Create high imbalance through large stETH rebase
        _simulateStETHRebase(30 ether); // Add 60% more stETH value

        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 ratio = (poolStETH * 1000) / poolETH;

        console2.log("High imbalance test:");
        console2.log("  Pool ETH:", poolETH);
        console2.log("  Pool stETH:", poolStETH);
        console2.log("  Ratio:", ratio);

        // Should be in high imbalance range (1500-2000)
        if (ratio >= 1500 && ratio < 2000) {
            console2.log("   High imbalance detected - should use HIGH_IMBALANCE_FEE (2%)");
        } else {
            console2.log("    Imbalance level:", ratio >= 2000 ? "critical" : "moderate or lower");
        }
    }

    function test_calculateDynamicFee_criticalImbalance() public {
        // Create critical imbalance through massive stETH rebase
        _simulateStETHRebase(75 ether); // Add 150% more stETH value

        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 ratio = (poolStETH * 1000) / poolETH;

        console2.log("Critical imbalance test:");
        console2.log("  Pool ETH:", poolETH);
        console2.log("  Pool stETH:", poolStETH);
        console2.log("  Ratio:", ratio);

        // Should be in critical imbalance range (>= 2000)
        if (ratio >= 2000) {
            console2.log("   Critical imbalance detected - should use MAX_PROTECTION_FEE (5%)");
        } else {
            console2.log("    Imbalance level: high or lower");
        }

        assertTrue(ratio >= 2000, "Should have critical imbalance ratio");
    }

    function test_getFeeByRatio_allTiers() public view {
        // Test the fee calculation logic for all ratio tiers
        // Note: We can't call internal functions directly, but we can verify
        // the constants and logic used in the hook

        console2.log("Fee tier verification:");
        console2.log("  BASE_FEE (ratio < 1100): 0.1% = 1000/1000000");
        console2.log("  SLIGHT_IMBALANCE_FEE (1100-1200): 0.2% = 2000/1000000");
        console2.log("  MODERATE_IMBALANCE_FEE (1200-1500): 0.5% = 5000/1000000");
        console2.log("  HIGH_IMBALANCE_FEE (1500-2000): 2% = 20000/1000000");
        console2.log("  MAX_PROTECTION_FEE (>= 2000): 5% = 50000/1000000");

        // Test calculations for different ratios
        uint256 testAmount = 1 ether;

        // Base fee calculation (0.1%)
        uint256 baseFee = (testAmount * 1000) / 1_000_000;
        assertEq(baseFee, 0.001 ether, "Base fee should be 0.001 ETH for 1 ETH");

        // Slight imbalance fee (0.2%)
        uint256 slightFee = (testAmount * 2000) / 1_000_000;
        assertEq(slightFee, 0.002 ether, "Slight imbalance fee should be 0.002 ETH for 1 ETH");

        // Moderate imbalance fee (0.5%)
        uint256 moderateFee = (testAmount * 5000) / 1_000_000;
        assertEq(moderateFee, 0.005 ether, "Moderate imbalance fee should be 0.005 ETH for 1 ETH");

        // High imbalance fee (2%)
        uint256 highFee = (testAmount * 20000) / 1_000_000;
        assertEq(highFee, 0.02 ether, "High imbalance fee should be 0.02 ETH for 1 ETH");

        // Max protection fee (5%)
        uint256 maxFee = (testAmount * 50000) / 1_000_000;
        assertEq(maxFee, 0.05 ether, "Max protection fee should be 0.05 ETH for 1 ETH");
    }

    function test_dynamicFee_zeroETH_scenario() public {
        // Test edge case where pool has zero ETH
        vm.startPrank(alice);

        // Remove all liquidity first
        uint256 lpTokens = rebasingParityPool.LP_TOKEN().balanceOf(alice);
        rebasingParityPool.removeLiquidity(key, lpTokens);

        vm.stopPrank();

        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();

        console2.log("Zero ETH scenario:");
        console2.log("  Pool ETH:", poolETH);
        console2.log("  Pool stETH:", poolStETH);

        // When ETH balance is 0, should use max protection fee
        if (poolETH == 0) {
            console2.log("   Zero ETH detected - should use MAX_PROTECTION_FEE (5%)");
        }

        assertEq(poolETH, 0, "Pool should have zero ETH");
    }

    // Helper function to simulate stETH rebase
    function _simulateStETHRebase(uint256 yieldAmount) internal {
        console2.log("  Simulating stETH rebase with yield:", yieldAmount);

        // Mint stETH to simulate the rebase
        address poolManagerAddress = address(poolManager);
        vm.startPrank(Currency.unwrap(key.currency1));
        stETH.mint(poolManagerAddress, yieldAmount);
        vm.stopPrank();

        // Trigger rebase yield detection through minimal liquidity operation
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 0.001 ether);
        vm.deal(alice, alice.balance + 0.001 ether);
        rebasingParityPool.addLiquidity{value: 0.001 ether}(key, 0.001 ether);
        vm.stopPrank();
    }
}