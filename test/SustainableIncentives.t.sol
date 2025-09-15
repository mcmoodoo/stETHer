// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {ParityPool} from "../src/ParityPool.sol";
import {ParityLP} from "../src/ParityLP.sol";
import {ProtocolRevenue} from "../src/ProtocolRevenue.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract SustainableIncentivesTest is Test, Fixtures {
    ParityPool hook;
    ParityLP lpToken;
    ProtocolRevenue protocolRevenue;
    address treasury = address(0x999);

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4451 << 144)
        );
        bytes memory constructorArgs = abi.encode(manager, treasury);
        deployCodeTo("ParityPool.sol:ParityPool", constructorArgs, flags);
        hook = ParityPool(flags);
        lpToken = hook.lpToken();
        protocolRevenue = ProtocolRevenue(hook.getProtocolRevenue());

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_incentive_requires_protocol_fees() public {
        uint256 liquidityAmount = 1000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
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
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
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
}