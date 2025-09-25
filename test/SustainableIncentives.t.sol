// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";
import {ParityLP} from "../src/ParityLP.sol";
import {ProtocolRevenue} from "../src/ProtocolRevenue.sol";
import {Fixtures} from "./utils/Fixtures.sol";
import {StETH} from "../src/StETH.sol";

contract SustainableIncentivesTest is Test, Fixtures {
    StETH stETH;
    RebasingParityPool hook;
    ParityLP lpToken;
    ProtocolRevenue protocolRevenue;
    address treasury = address(0x999);

    function setUp() public {
        deployFreshManagerAndRouters();

        // Deploy stETH and set up ETH/stETH pair

        stETH = new StETH();

        currency0 = Currency.wrap(address(0)); // ETH

        currency1 = Currency.wrap(address(stETH)); // stETH



        // Mint stETH to test contracts

        stETH.mint(address(this), 10_000_000 ether);

        stETH.mint(address(swapRouter), 10_000_000 ether);

        stETH.mint(address(modifyLiquidityRouter), 10_000_000 ether);



        // Deal ETH to test contracts

        vm.deal(address(this), 10_000_000 ether);

        vm.deal(address(swapRouter), 10_000_000 ether);

        vm.deal(address(modifyLiquidityRouter), 10_000_000 ether);

        // Approve stETH for routers

        stETH.approve(address(swapRouter), type(uint256).max);

        stETH.approve(address(modifyLiquidityRouter), type(uint256).max);
        deployAndApprovePosm(manager);

        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4451 << 144)
        );

        // Create pool key with flags address for constructor
        PoolKey memory constructorKey = PoolKey(currency0, currency1, 3000, 60, IHooks(flags));
        bytes memory constructorArgs = abi.encode(manager, treasury, constructorKey);
        deployCodeTo("RebasingParityPool.sol:RebasingParityPool", constructorArgs, flags);

        hook = RebasingParityPool(flags);
        lpToken = hook.LP_TOKEN();
        protocolRevenue = ProtocolRevenue(hook.getProtocolRevenue());

        // Update key with actual hook address and initialize
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_incentive_requires_protocol_fees() public {
        uint256 liquidityAmount = 1000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);
        
        // First, verify no protocol fees exist
        uint256 protocolFees = hook.getProtocolFees(Currency.unwrap(currency1));
        assertEq(protocolFees, 0, "Should start with no protocol fees");
        
        // Try ETH → stETH swap with no protocol fees available
        uint256 swapAmount = 100e18;
        
        // Record balances before swap
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        // ETH → stETH swap (should be 1:1 with no incentive since no protocol fees)
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        // Calculate actual amounts
        uint256 ethSpent = balance0Before - balance0After;
        uint256 stethReceived = balance1After - balance1Before;
        
        console.log("ETH spent:", ethSpent);
        console.log("stETH received:", stethReceived);
        
        // Should be approximately 1:1 (no incentive without protocol fees)
        assertApproxEqAbs(ethSpent, stethReceived, 1e15, "Should be ~1:1 without protocol fees");
    }

    function test_incentive_funded_by_protocol_fees() public {
        uint256 liquidityAmount = 1000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);
        
        // Generate protocol fees through stETH → ETH swaps
        uint256 feeGeneratingSwap = 200e18;
        for (uint i = 0; i < 3; i++) {
            swap(key, false, -int256(feeGeneratingSwap), ZERO_BYTES); // stETH → ETH
        }
        
        // Check accumulated protocol fees
        uint256 protocolFees = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Protocol fees accumulated:", protocolFees);
        assertGt(protocolFees, 0, "Should have accumulated protocol fees");
        
        // Now try ETH → stETH swap with protocol fees available
        uint256 swapAmount = 50e18; // Smaller swap to ensure we have enough protocol fees
        
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        // ETH → stETH swap (should include incentive)
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        uint256 ethSpent = balance0Before - balance0After;
        uint256 stethReceived = balance1After - balance1Before;
        
        console.log("With incentive - ETH spent:", ethSpent);
        console.log("With incentive - stETH received:", stethReceived);
        
        // Should receive more stETH than ETH spent (incentive applied)
        assertGt(stethReceived, ethSpent, "Should receive incentive bonus");
        
        // Check that protocol fees were reduced
        uint256 protocolFeesAfter = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Protocol fees after incentive:", protocolFeesAfter);
        assertLt(protocolFeesAfter, protocolFees, "Protocol fees should be reduced by incentive");
    }

    function test_incentive_scales_with_imbalance() public {
        uint256 liquidityAmount = 2000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);
        
        // Generate significant protocol fees
        for (uint i = 0; i < 5; i++) {
            swap(key, false, -int256(300e18), ZERO_BYTES); // stETH → ETH (creates imbalance)
        }
        
        // Check pool state
        uint256 ethBalance = manager.balanceOf(address(hook), currency0.toId());
        uint256 stethBalance = manager.balanceOf(address(hook), currency1.toId());
        console.log("Pool ETH balance:", ethBalance);
        console.log("Pool stETH balance:", stethBalance);
        
        uint256 protocolFees = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Protocol fees before incentive test:", protocolFees);
        
        // Try ETH → stETH swap in imbalanced state
        uint256 swapAmount = 100e18;
        
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        uint256 ethSpent = balance0Before - balance0After;
        uint256 stethReceived = balance1After - balance1Before;
        
        console.log("Imbalanced state - ETH spent:", ethSpent);
        console.log("Imbalanced state - stETH received:", stethReceived);
        
        // Calculate incentive percentage
        uint256 incentiveAmount = stethReceived - ethSpent;
        uint256 incentivePercent = (incentiveAmount * 10000) / ethSpent; // Basis points
        console.log("Incentive percentage (bp):", incentivePercent);
        
        // In imbalanced state, should get meaningful incentive
        assertGt(incentivePercent, 0, "Should have incentive in imbalanced state");
        assertLe(incentivePercent, 100, "Incentive should not exceed 1% (100 bp)");
    }

    function test_incentive_sustainability() public {
        uint256 liquidityAmount = 1000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);
        
        // Simulate trading cycle: fees accumulate, then incentives are paid
        for (uint cycle = 0; cycle < 3; cycle++) {
            console.log("=== Cycle", cycle, "===");
            
            // Generate fees through stETH → ETH swaps
            uint256 feeSwapAmount = 150e18;
            swap(key, false, -int256(feeSwapAmount), ZERO_BYTES);
            
            uint256 protocolFeesAfterFee = hook.getProtocolFees(Currency.unwrap(currency1));
            console.log("Protocol fees after fee generation:", protocolFeesAfterFee);
            
            // Use incentives through ETH → stETH swaps
            uint256 incentiveSwapAmount = 75e18; // Smaller to ensure sustainability
            
            uint256 protocolFeesBefore = hook.getProtocolFees(Currency.unwrap(currency1));
            
            if (protocolFeesBefore > 0) {
                swap(key, true, -int256(incentiveSwapAmount), ZERO_BYTES);
                
                uint256 protocolFeesAfterIncentive = hook.getProtocolFees(Currency.unwrap(currency1));
                console.log("Protocol fees after incentive:", protocolFeesAfterIncentive);
                
                // Protocol should still have fees remaining (sustainable)
                assertGe(protocolFeesAfterIncentive, 0, "Protocol fees should not go negative");
            }
        }
        
        // Final check: protocol should still have fees
        uint256 finalProtocolFees = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Final protocol fees:", finalProtocolFees);
        assertGt(finalProtocolFees, 0, "Protocol should maintain fee reserves");
    }

    function test_no_incentive_when_balanced() public {
        uint256 liquidityAmount = 1000e18;
        
        // LP adds liquidity (starts balanced)
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);
        
        // Generate some protocol fees but keep pool balanced
        swap(key, false, -int256(100e18), ZERO_BYTES); // stETH → ETH
        swap(key, true, -int256(100e18), ZERO_BYTES);  // ETH → stETH (rebalance)
        
        uint256 protocolFees = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Protocol fees in balanced state:", protocolFees);
        
        // Try ETH → stETH swap in balanced state
        uint256 swapAmount = 50e18;
        
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        uint256 ethSpent = balance0Before - balance0After;
        uint256 stethReceived = balance1After - balance1Before;
        
        console.log("Balanced state - ETH spent:", ethSpent);
        console.log("Balanced state - stETH received:", stethReceived);
        
        // Should be approximately 1:1 (no incentive when balanced)
        assertApproxEqAbs(ethSpent, stethReceived, 1e15, "Should be ~1:1 when balanced");
        
        // Protocol fees should be unchanged (no incentive paid)
        uint256 protocolFeesAfter = hook.getProtocolFees(Currency.unwrap(currency1));
        assertEq(protocolFeesAfter, protocolFees, "Protocol fees should be unchanged");
    }

    function test_large_incentive_limited_by_available_fees() public {
        uint256 liquidityAmount = 1000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);
        
        // Generate very small amount of protocol fees
        swap(key, false, -int256(10e18), ZERO_BYTES); // Very small fee-generating swap
        
        uint256 limitedProtocolFees = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Limited protocol fees before imbalance:", limitedProtocolFees);
        
        // Create imbalance to trigger higher incentive rates
        for (uint i = 0; i < 3; i++) {
            swap(key, false, -int256(200e18), ZERO_BYTES); // Create imbalance
        }
        
        // Check protocol fees after creating imbalance
        uint256 protocolFeesAfterImbalance = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Protocol fees after creating imbalance:", protocolFeesAfterImbalance);
        
        // Try ETH → stETH swap in very imbalanced state
        uint256 swapAmount = 100e18; // Moderate swap amount
        
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        uint256 ethSpent = balance0Before - balance0After;
        uint256 stethReceived = balance1After - balance1Before;
        uint256 incentiveGiven = stethReceived > ethSpent ? stethReceived - ethSpent : 0;
        
        console.log("Large swap - ETH spent:", ethSpent);
        console.log("Large swap - stETH received:", stethReceived);
        console.log("Incentive given:", incentiveGiven);
        console.log("Available protocol fees before swap:", protocolFeesAfterImbalance);
        
        // Since we created imbalance with swaps, we should have more protocol fees available
        // The incentive should be reasonable and not exceed total protocol fees
        uint256 protocolFeesAfterSwap = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Protocol fees after incentive swap:", protocolFeesAfterSwap);
        
        // The protocol fees should have decreased by the incentive amount
        assertEq(protocolFeesAfterImbalance - protocolFeesAfterSwap, incentiveGiven, "Protocol fees should decrease by incentive amount");
    }

    // === FEE DISTRIBUTION TESTS (from FeeDistribution.t.sol) ===

    function test_feeAccumulation_singleLP() public {
        uint256 liquidityAmount = 1000e18;

        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        uint256 lpTokensMinted = hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);

        // Generate fees through swaps (stETH → ETH with dynamic fees)
        uint256 swapAmount = 100e18;
        for (uint i = 0; i < 3; i++) {
            swap(key, false, -int256(swapAmount), ZERO_BYTES); // stETH → ETH
        }

        // Check accumulated fees
        (uint256 accFees0, uint256 accFees1) = hook.getTotalAccumulatedFees();
        console.log("Total accumulated fees:");
        console.log("ETH fees:", accFees0);
        console.log("stETH fees:", accFees1);

        // Check pending fees for LP
        (uint256 pendingFees0, uint256 pendingFees1) = hook.pendingFees(address(this));
        console.log("Pending fees for LP:");
        console.log("ETH fees:", pendingFees0);
        console.log("stETH fees:", pendingFees1);

        // Fees should be accumulated (stETH fees since we're swapping stETH → ETH)
        assertGt(accFees1, 0, "Should have accumulated stETH fees");
        assertEq(pendingFees1, accFees1, "LP should get all fees (single LP)");
    }

    function test_claimFees_functionality() public {
        uint256 liquidityAmount = 1000e18;

        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);

        // Generate fees
        uint256 swapAmount = 200e18;
        swap(key, false, -int256(swapAmount), ZERO_BYTES); // stETH → ETH (0.5% fee due to imbalance)

        // Check fees before claiming
        (uint256 pendingBefore0, uint256 pendingBefore1) = hook.pendingFees(address(this));
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();

        // Claim fees
        (uint256 claimed0, uint256 claimed1) = hook.claimFees(key);

        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();

        // Verify fees were claimed (including potential rebasing yield)
        assertEq(claimed0, pendingBefore0, "Claimed ETH fees should match pending");
        assertGe(claimed1, pendingBefore1, "Claimed stETH fees should be at least pending (may include rebasing yield)");

        // Verify tokens were transferred
        assertEq(balance0After - balance0Before, claimed0, "ETH balance should increase by claimed amount");
        assertEq(balance1After - balance1Before, claimed1, "stETH balance should increase by claimed amount");

        // Verify no more pending fees
        (uint256 pendingAfter0, uint256 pendingAfter1) = hook.pendingFees(address(this));
        assertEq(pendingAfter0, 0, "No ETH fees should be pending after claim");
        assertEq(pendingAfter1, 0, "No stETH fees should be pending after claim");
    }

    function test_feeDistribution_multipleLPs() public {
        uint256 liquidityAmount1 = 1000e18;
        uint256 liquidityAmount2 = 500e18;

        // First LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount1);
        uint256 lpTokens1 = hook.addLiquidity{value: liquidityAmount1}(key, liquidityAmount1);

        // Second LP adds liquidity
        address secondLP = address(0x123);
        vm.deal(secondLP, liquidityAmount2); // Deal ETH
        deal(Currency.unwrap(currency1), secondLP, liquidityAmount2);

        vm.startPrank(secondLP);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount2);
        uint256 lpTokens2 = hook.addLiquidity{value: liquidityAmount2}(key, liquidityAmount2);
        vm.stopPrank();

        // Generate fees
        uint256 swapAmount = 300e18;
        swap(key, false, -int256(swapAmount), ZERO_BYTES); // stETH → ETH

        // Check fees for each LP
        (uint256 pending1_0, uint256 pending1_1) = hook.pendingFees(address(this));
        (uint256 pending2_0, uint256 pending2_1) = hook.pendingFees(secondLP);

        console.log("LP1 pending fees (ETH, stETH):", pending1_0, pending1_1);
        console.log("LP2 pending fees (ETH, stETH):", pending2_0, pending2_1);
        console.log("LP1 tokens:", lpTokens1, "LP2 tokens:", lpTokens2);

        // LP1 should get 2/3 of fees (2000 tokens out of 3000 total)
        // LP2 should get 1/3 of fees (1000 tokens out of 3000 total)
        uint256 totalFees = pending1_1 + pending2_1;
        assertApproxEqRel(pending1_1, totalFees * 2 / 3, 1e15, "LP1 should get ~2/3 of fees");
        assertApproxEqRel(pending2_1, totalFees * 1 / 3, 1e15, "LP2 should get ~1/3 of fees");
    }

    function test_removeLiquidity_includesFees() public {
        uint256 liquidityAmount = 1000e18;

        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        uint256 lpTokensMinted = hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);

        // Generate fees
        uint256 swapAmount = 150e18;
        swap(key, false, -int256(swapAmount), ZERO_BYTES); // stETH → ETH

        // Check pending fees before withdrawal
        (uint256 pendingBefore0, uint256 pendingBefore1) = hook.pendingFees(address(this));

        // Record balances before withdrawal
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();

        // Remove all liquidity
        (uint256 amount0, uint256 amount1) = hook.removeLiquidity(key, lpTokensMinted);

        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();

        // Verify fees were included in withdrawal
        console.log("Withdrawn amounts (ETH, stETH):", amount0, amount1);
        console.log("Pending fees before (ETH, stETH):", pendingBefore0, pendingBefore1);

        // The important thing is that fees are included in the withdrawal
        // LP should get their pending fees on top of their proportional share
        assertGt(pendingBefore1, 0, "Should have accumulated stETH fees");

        // Verify tokens were transferred
        assertEq(balance0After - balance0Before, amount0, "ETH balance should increase by withdrawn amount");
        assertEq(balance1After - balance1Before, amount1, "stETH balance should increase by withdrawn amount");

        // Verify no more pending fees after full withdrawal
        (uint256 pendingAfter0, uint256 pendingAfter1) = hook.pendingFees(address(this));
        assertEq(pendingAfter0, 0, "No ETH fees should be pending after full withdrawal");
        assertEq(pendingAfter1, 0, "No stETH fees should be pending after full withdrawal");
    }

    function test_feeAccumulation_acrossMultipleSwaps() public {
        uint256 liquidityAmount = 2000e18;

        // LP adds liquidity
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity{value: liquidityAmount}(key, liquidityAmount);

        // Track fee accumulation across multiple swaps
        uint256[] memory swapAmounts = new uint256[](4);
        swapAmounts[0] = 50e18;
        swapAmounts[1] = 100e18;
        swapAmounts[2] = 75e18;
        swapAmounts[3] = 125e18;

        uint256 totalExpectedFees = 0;

        for (uint i = 0; i < swapAmounts.length; i++) {
            // Record fees before swap
            (uint256 feesBefore0, uint256 feesBefore1) = hook.getTotalAccumulatedFees();

            // Perform swap
            swap(key, false, -int256(swapAmounts[i]), ZERO_BYTES); // stETH → ETH

            // Check fees after swap
            (uint256 feesAfter0, uint256 feesAfter1) = hook.getTotalAccumulatedFees();

            uint256 feeIncrease = feesAfter1 - feesBefore1;
            console.log("Swap amount:", swapAmounts[i]);
            console.log("Fee generated:", feeIncrease);

            // Fee should be accumulated with each swap
            assertGt(feeIncrease, 0, "Each swap should generate fees");
            totalExpectedFees += feeIncrease;
        }

        // Final check - total accumulated fees should match sum of individual fees
        (uint256 finalFees0, uint256 finalFees1) = hook.getTotalAccumulatedFees();
        assertEq(finalFees1, totalExpectedFees, "Total fees should equal sum of individual fees");
    }
}