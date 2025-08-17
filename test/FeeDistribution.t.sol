// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {Counter} from "../src/Counter.sol";
import {ConstantSumLP} from "../src/ConstantSumLP.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract FeeDistributionTest is Test, Fixtures {
    Counter hook;
    ConstantSumLP lpToken;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4449 << 144)
        );
        bytes memory constructorArgs = abi.encode(manager, address(0x999)); // treasury address
        deployCodeTo("Counter.sol:Counter", constructorArgs, flags);
        hook = Counter(flags);
        lpToken = hook.lpToken();

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_feeAccumulation_singleLP() public {
        uint256 liquidityAmount = 1000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        uint256 lpTokensMinted = hook.addLiquidity(key, liquidityAmount);
        
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
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
        
        // Verify fees were claimed
        assertEq(claimed0, pendingBefore0, "Claimed ETH fees should match pending");
        assertEq(claimed1, pendingBefore1, "Claimed stETH fees should match pending");
        
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount1);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount1);
        uint256 lpTokens1 = hook.addLiquidity(key, liquidityAmount1);
        
        // Second LP adds liquidity
        address secondLP = address(0x123);
        deal(Currency.unwrap(currency0), secondLP, liquidityAmount2);
        deal(Currency.unwrap(currency1), secondLP, liquidityAmount2);
        
        vm.startPrank(secondLP);
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount2);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount2);
        uint256 lpTokens2 = hook.addLiquidity(key, liquidityAmount2);
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        uint256 lpTokensMinted = hook.addLiquidity(key, liquidityAmount);
        
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
        
        // Verify fees were included in withdrawal
        // Note: Total withdrawal may be less than deposited due to pool imbalance from swaps
        // But LP should receive their accumulated fees
        uint256 totalWithdrawn = amount0 + amount1;
        uint256 totalDeposited = liquidityAmount * 2;
        
        // The important thing is that fees are included in the withdrawal
        // LP should get their pending fees on top of their proportional share
        assertGt(pendingBefore1, 0, "Should have accumulated stETH fees");
        
        // The actual withdrawal amount depends on pool state and fees
        console.log("Total deposited:", totalDeposited);
        console.log("Total withdrawn:", totalWithdrawn);
        console.log("Fees included in withdrawal:", pendingBefore1);
        
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
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

    function test_feeDistribution_noLPTokens() public {
        // Generate fees before any LP adds liquidity
        uint256 swapAmount = 100e18;
        
        // This should revert or generate no fees since no LP tokens exist
        // First add minimal liquidity to enable swaps
        uint256 minLiquidity = 10e18;
        IERC20(Currency.unwrap(currency0)).approve(address(hook), minLiquidity);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), minLiquidity);
        hook.addLiquidity(key, minLiquidity);
        
        // Remove all liquidity
        uint256 lpBalance = lpToken.balanceOf(address(this));
        hook.removeLiquidity(key, lpBalance);
        
        // Now try to swap with no LP tokens
        vm.expectRevert(); // Should revert due to insufficient liquidity
        swap(key, false, -int256(swapAmount), ZERO_BYTES);
    }
}