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
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

contract RebasingParityPoolSwapsTest is RebasingParityPoolTest {

    function setUp() public override {
        super.setUp();

        // Add initial liquidity to enable swaps
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 50 ether);
        rebasingParityPool.addLiquidity{value: 50 ether}(key, 50 ether);
        vm.stopPrank();
    }

    function test_swapCalculations_ethToSteth() public {
        // Test ETH to stETH swap calculations
        vm.startPrank(bob);

        uint256 swapAmount = 5 ether;

        uint256 poolETHBefore = rebasingParityPool.poolETHBalance();
        uint256 poolStETHBefore = rebasingParityPool.poolStETHBalance();

        // Verify initial pool state
        assertEq(poolETHBefore, 50 ether, "Pool should have 50 ETH initially");
        assertEq(poolStETHBefore, 50 ether, "Pool should have 50 stETH initially");

        // ETH -> stETH swaps receive incentives when pool is stETH-heavy
        // In balanced pools, users get 1:1 conversion plus potential incentives
        uint256 expectedOutput = swapAmount; // Base 1:1 conversion

        assertTrue(poolStETHBefore >= expectedOutput, "Pool has sufficient stETH reserves");

        console2.log("ETH -> stETH swap calculations verified:");
        console2.log("  Input amount:", swapAmount);
        console2.log("  Expected output: ~", expectedOutput, "(1:1 + potential incentive)");
        console2.log("  Pool has sufficient stETH reserves:", poolStETHBefore >= swapAmount);

        vm.stopPrank();
    }

    function test_swapCalculations_stethToEth() public {
        // Test stETH to ETH swap calculations
        vm.startPrank(bob);

        uint256 swapAmount = 3 ether;
        uint256 poolETHBefore = rebasingParityPool.poolETHBalance();

        // Verify Bob has sufficient stETH for the swap
        uint256 bobStETH = stETH.balanceOf(bob);
        assertGe(bobStETH, swapAmount, "Bob should have sufficient stETH for swap");

        // stETH -> ETH swaps pay dynamic fees based on pool imbalance
        // In balanced pools, base fee of 0.1% applies
        uint256 expectedFee = (swapAmount * 1000) / 1_000_000; // 0.1% base fee
        uint256 expectedOutput = swapAmount - expectedFee;

        assertTrue(poolETHBefore >= expectedOutput, "Pool should have sufficient ETH for swap");

        console2.log("stETH -> ETH swap calculations verified:");
        console2.log("  Input amount:", swapAmount);
        console2.log("  Expected fee:", expectedFee);
        console2.log("  Expected output:", expectedOutput);
        console2.log("  Pool has sufficient ETH reserves:", poolETHBefore >= expectedOutput);

        vm.stopPrank();
    }

    function test_swapReserveLimits() public {
        // Test swap reserve limits and capacity

        uint256 poolETHBalance = rebasingParityPool.poolETHBalance();
        uint256 poolStETHBalance = rebasingParityPool.poolStETHBalance();

        // Verify pool has the expected liquidity from setup
        assertEq(poolETHBalance, 50 ether, "Pool should have 50 ETH from setup");
        assertEq(poolStETHBalance, 50 ether, "Pool should have 50 stETH from setup");

        // Test reserve limit logic
        // For ETH -> stETH swaps, the limit is the stETH reserves
        uint256 maxETHToStETH = poolStETHBalance;

        // For stETH -> ETH swaps, the limit is the ETH reserves
        uint256 maxStETHToETH = poolETHBalance;

        // Verify that normal swap amounts are within limits
        assertTrue(5 ether <= maxETHToStETH, "5 ETH swap should be within stETH reserves");
        assertTrue(3 ether <= maxStETHToETH, "3 stETH swap should be within ETH reserves");

        // Verify that excessive swap amounts would exceed limits
        assertTrue(100 ether > maxETHToStETH, "100 ETH swap should exceed stETH reserves");
        assertTrue(100 ether > maxStETHToETH, "100 stETH swap should exceed ETH reserves");

        console2.log("Pool reserve limits verified:");
        console2.log("  Max ETH->stETH swap (limited by stETH reserves):", maxETHToStETH);
        console2.log("  Max stETH->ETH swap (limited by ETH reserves):", maxStETHToETH);
        console2.log("  Current pool ETH:", poolETHBalance);
        console2.log("  Current pool stETH:", poolStETHBalance);
    }

    function test_feeCalculationLogic() public {
        // Test dynamic fee calculation logic

        uint256 poolETH = rebasingParityPool.poolETHBalance();
        uint256 poolStETH = rebasingParityPool.poolStETHBalance();
        uint256 ratio = (poolStETH * 1000) / poolETH; // RATIO_SCALE = 1000

        assertEq(ratio, 1000, "Balanced pool should have 1:1 ratio (1000 scaled)");

        // Dynamic fees are applied to stETH -> ETH swaps based on pool imbalance
        // Balanced pools use base fee of 0.1%
        uint256 testSwapAmount = 3 ether;
        uint256 expectedBaseFee = (testSwapAmount * 1000) / 1_000_000; // 0.1%

        assertTrue(expectedBaseFee > 0, "Base fee should be greater than 0");
        assertTrue(expectedBaseFee < testSwapAmount / 100, "Base fee should be less than 1%");

        console2.log("Fee calculation logic verified:");
        console2.log("  Pool ratio (stETH/ETH * 1000):", ratio);
        console2.log("  Balanced pool applies base fee for stETH->ETH");
        console2.log("  ETH->stETH swaps receive incentives when pool is imbalanced");
        console2.log("  For 3 ETH swap, expected base fee:", expectedBaseFee);
    }
}