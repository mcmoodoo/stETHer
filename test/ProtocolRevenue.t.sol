// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {RebasingParityHook} from "../src/RebasingParityHook.sol";
import {ParityLP} from "../src/ParityLP.sol";
import {ProtocolRevenue} from "../src/ProtocolRevenue.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract ProtocolRevenueTest is Test, Fixtures {
    RebasingParityHook hook;
    ParityLP lpToken;
    ProtocolRevenue protocolRevenue;
    address treasury = address(0x999);

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4450 << 144)
        );
        bytes memory constructorArgs = abi.encode(manager, treasury);
        deployCodeTo("RebasingParityHook.sol:RebasingParityHook", constructorArgs, flags);
        hook = RebasingParityHook(flags);
        lpToken = hook.LP_TOKEN();
        protocolRevenue = ProtocolRevenue(hook.getProtocolRevenue());

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_protocolFeeCollection_basicSwap() public {
        uint256 liquidityAmount = 1000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        // Generate fees through swap (stETH → ETH with dynamic fees)
        uint256 swapAmount = 100e18;
        swap(key, false, -int256(swapAmount), ZERO_BYTES);
        
        // Check protocol fees were collected
        uint256 protocolFees1 = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Protocol fees collected (stETH):", protocolFees1);
        
        // Check LP fees were accumulated 
        (uint256 lpFees0, uint256 lpFees1) = hook.getTotalAccumulatedFees();
        console.log("LP fees accumulated (ETH, stETH):", lpFees0, lpFees1);
        
        // Protocol should get 10% of fees by default
        assertGt(protocolFees1, 0, "Protocol should have collected fees");
        assertGt(lpFees1, 0, "LPs should have received fees");
        
        // Total fees should be split between protocol and LPs
        uint256 totalFees = protocolFees1 + lpFees1;
        console.log("Total fees generated:", totalFees);
        
        // Verify protocol gets approximately 10% (with some tolerance for precision)
        uint256 expectedProtocolShare = totalFees * 10 / 100;
        assertApproxEqRel(protocolFees1, expectedProtocolShare, 1e16, "Protocol should get ~10% of fees");
    }

    function test_protocolFeeCollection_largeSw() public {
        uint256 liquidityAmount = 2000e18;
        
        // LP adds liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        // Large swap that triggers additional protocol fees
        uint256 largeSwapAmount = 1500e18; // Above threshold of 1000e18
        swap(key, false, -int256(largeSwapAmount), ZERO_BYTES);
        
        // Check protocol fees
        uint256 protocolFees1 = hook.getProtocolFees(Currency.unwrap(currency1));
        (uint256 lpFees0, uint256 lpFees1) = hook.getTotalAccumulatedFees();
        
        console.log("Large swap protocol fees (stETH):", protocolFees1);
        console.log("Large swap LP fees (stETH):", lpFees1);
        
        // For large swaps, protocol should get more than the base 10%
        uint256 totalFees = protocolFees1 + lpFees1;
        uint256 protocolPercentage = (protocolFees1 * 100) / totalFees;
        console.log("Protocol fee percentage for large swap:", protocolPercentage);
        
        assertGt(protocolPercentage, 10, "Large swaps should have higher protocol fee percentage");
    }

    function test_feeSplitting_multipleLPs() public {
        uint256 liquidityAmount1 = 1000e18;
        uint256 liquidityAmount2 = 500e18;
        
        // First LP adds liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount1);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount1);
        hook.addLiquidity(key, liquidityAmount1);
        
        // Second LP adds liquidity
        address secondLP = address(0x123);
        deal(Currency.unwrap(currency0), secondLP, liquidityAmount2);
        deal(Currency.unwrap(currency1), secondLP, liquidityAmount2);
        
        vm.startPrank(secondLP);
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount2);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount2);
        hook.addLiquidity(key, liquidityAmount2);
        vm.stopPrank();
        
        // Generate fees
        uint256 swapAmount = 300e18;
        swap(key, false, -int256(swapAmount), ZERO_BYTES);
        
        // Check fees
        uint256 protocolFees1 = hook.getProtocolFees(Currency.unwrap(currency1));
        (uint256 pending1_0, uint256 pending1_1) = hook.pendingFees(address(this));
        (uint256 pending2_0, uint256 pending2_1) = hook.pendingFees(secondLP);
        
        console.log("Protocol fees:", protocolFees1);
        console.log("LP1 pending fees:", pending1_1);
        console.log("LP2 pending fees:", pending2_1);
        
        // Verify protocol got its share
        assertGt(protocolFees1, 0, "Protocol should have fees");
        
        // Verify LPs get proportional shares (LP1 should get 2/3, LP2 should get 1/3)
        uint256 totalLPFees = pending1_1 + pending2_1;
        assertApproxEqRel(pending1_1, totalLPFees * 2 / 3, 1e15, "LP1 should get ~2/3 of LP fees");
        assertApproxEqRel(pending2_1, totalLPFees * 1 / 3, 1e15, "LP2 should get ~1/3 of LP fees");
    }

    function test_protocolFeeWithdrawal() public {
        uint256 liquidityAmount = 1000e18;
        
        // Setup and generate fees
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        // Generate some fees
        for (uint i = 0; i < 3; i++) {
            swap(key, false, -int256(100e18), ZERO_BYTES);
        }
        
        uint256 protocolFees1 = hook.getProtocolFees(Currency.unwrap(currency1));
        console.log("Total protocol fees accumulated:", protocolFees1);
        
        // Test withdrawal (would need to be called by protocol owner)
        assertGt(protocolFees1, 0, "Should have protocol fees to withdraw");
        
        // Note: Actual withdrawal would require proper access control
        // This test just verifies fees are being tracked correctly
    }

    function test_protocolFeeParameters() public view {
        // Test default protocol fee parameters
        assertEq(protocolRevenue.protocolFeePercentage(), 10, "Default protocol fee should be 10%");
        assertEq(protocolRevenue.largeSwapThreshold(), 1000e18, "Default large swap threshold");
        assertEq(protocolRevenue.largeSwapProtocolFee(), 500, "Default large swap additional fee");
        assertEq(protocolRevenue.MAX_PROTOCOL_FEE(), 25, "Max protocol fee should be 25%");
    }

    function test_feeSplitting_calculation() public {
        // Test the fee calculation directly
        uint256 totalFee = 1000; // 0.1% of some amount
        uint256 swapAmount = 500e18; // Small swap
        
        (uint256 protocolFee, uint256 lpFee) = protocolRevenue.calculateProtocolFee(totalFee, swapAmount);
        
        console.log("Total fee:", totalFee);
        console.log("Protocol fee:", protocolFee);
        console.log("LP fee:", lpFee);
        
        assertEq(protocolFee + lpFee, totalFee, "Fees should sum to total");
        assertEq(protocolFee, totalFee * 10 / 100, "Protocol should get 10% for small swaps");
        
        // Test large swap
        uint256 largeSwapAmount = 1500e18;
        (uint256 protocolFeeLarge, uint256 lpFeeLarge) = protocolRevenue.calculateProtocolFee(totalFee, largeSwapAmount);
        
        assertGt(protocolFeeLarge, protocolFee, "Large swaps should have higher protocol fees");
        assertEq(protocolFeeLarge + lpFeeLarge, totalFee, "Large swap fees should sum to total");
    }
}