// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTest} from "./base-test-setup/RebasingParityPoolTestBase.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {ParityLP} from "src/ParityLP.sol";

contract RebasingParityPoolLiquidityTest is RebasingParityPoolTest {
    using StateLibrary for IPoolManager;

    function test_addLiquidity_firstLP() public {
        // Setup: Alice adds liquidity as the first LP
        vm.startPrank(alice);

        uint256 liquidityAmount = 10 ether;

        // Track initial balances
        uint256 aliceETHBefore = alice.balance;
        uint256 aliceStETHBefore = stETH.balanceOf(alice);

        // Approve stETH to the hook (hook will transfer to PoolManager)
        stETH.approve(address(rebasingParityPool), liquidityAmount);

        // Get the LP token contract
        ParityLP lpToken = ParityLP(address(rebasingParityPool.LP_TOKEN()));
        uint256 lpBalanceBefore = lpToken.balanceOf(alice);

        // Add liquidity through the hook's custom function
        // This will use PoolManager's unlock mechanism internally
        uint256 lpTokensReceived = rebasingParityPool.addLiquidity{value: liquidityAmount}(
            key,
            liquidityAmount  // amountPerToken - same for ETH and stETH
        );

        // Assertions

        // 1. Verify LP tokens minted (2x for first LP since they provide both tokens)
        uint256 expectedLPTokens = liquidityAmount * 2; // 10 ETH + 10 stETH = 20 total value
        assertEq(lpTokensReceived, expectedLPTokens, "First LP should get LP tokens equal to total value");
        assertEq(lpToken.balanceOf(alice), lpBalanceBefore + expectedLPTokens, "LP token balance incorrect");

        // 2. Verify pool balances updated correctly
        assertEq(rebasingParityPool.poolETHBalance(), liquidityAmount, "Pool ETH balance incorrect");
        assertEq(rebasingParityPool.poolStETHBalance(), liquidityAmount, "Pool stETH balance incorrect");
        assertEq(rebasingParityPool.poolStETHPrincipal(), liquidityAmount, "Pool stETH principal incorrect");

        // 3. Verify user balances decreased appropriately
        assertEq(alice.balance, aliceETHBefore - liquidityAmount, "ETH not deducted from alice");
        assertEq(stETH.balanceOf(alice), aliceStETHBefore - liquidityAmount, "stETH not deducted from alice");

        // 4. Verify total liquidity
        assertEq(rebasingParityPool.totalLiquidity(), liquidityAmount * 2, "Total liquidity incorrect");

        // 5. Verify LP token total supply
        assertEq(lpToken.totalSupply(), expectedLPTokens, "LP token total supply incorrect");

        console2.log("First LP added liquidity:");
        console2.log("  ETH deposited:", liquidityAmount);
        console2.log("  stETH deposited:", liquidityAmount);
        console2.log("  LP tokens received:", lpTokensReceived);

        vm.stopPrank();
    }

    function test_addLiquidity_subsequentLP() public {
        // First, Alice adds initial liquidity
        vm.startPrank(alice);
        uint256 aliceAmount = 10 ether;
        stETH.approve(address(rebasingParityPool), aliceAmount);
        rebasingParityPool.addLiquidity{value: aliceAmount}(key, aliceAmount);
        vm.stopPrank();

        // Now Bob adds liquidity as a subsequent LP
        vm.startPrank(bob);
        uint256 bobAmount = 5 ether;

        // Track initial balances
        uint256 bobETHBefore = bob.balance;
        uint256 bobStETHBefore = stETH.balanceOf(bob);

        // Get LP token contract
        ParityLP lpToken = ParityLP(address(rebasingParityPool.LP_TOKEN()));
        uint256 lpTokenSupplyBefore = lpToken.totalSupply();
        uint256 bobLPBefore = lpToken.balanceOf(bob);

        // Get pool state before
        uint256 poolETHBefore = rebasingParityPool.poolETHBalance();
        uint256 poolStETHBefore = rebasingParityPool.poolStETHBalance();
        uint256 totalPoolValueBefore = poolETHBefore + poolStETHBefore;

        // Bob approves and adds liquidity
        stETH.approve(address(rebasingParityPool), bobAmount);
        uint256 lpTokensReceived = rebasingParityPool.addLiquidity{value: bobAmount}(
            key,
            bobAmount
        );

        // Calculate expected LP tokens for subsequent LP
        // Formula: lpTokens = (amountAdded / totalPoolValue) * lpToken.totalSupply()
        uint256 bobTotalDeposit = bobAmount * 2; // Bob deposits 5 ETH + 5 stETH = 10 total
        uint256 expectedLPTokens = (bobTotalDeposit * lpTokenSupplyBefore) / totalPoolValueBefore;

        // Assertions

        // 1. Verify proportional LP tokens for subsequent LP
        assertEq(lpTokensReceived, expectedLPTokens, "Bob should get proportional LP tokens");
        assertEq(lpToken.balanceOf(bob), bobLPBefore + expectedLPTokens, "Bob's LP balance incorrect");

        // 2. Verify pool balances increased correctly
        assertEq(rebasingParityPool.poolETHBalance(), poolETHBefore + bobAmount, "Pool ETH balance incorrect");
        assertEq(rebasingParityPool.poolStETHBalance(), poolStETHBefore + bobAmount, "Pool stETH balance incorrect");

        // 3. Verify Bob's balances decreased
        assertEq(bob.balance, bobETHBefore - bobAmount, "Bob's ETH not deducted");
        assertEq(stETH.balanceOf(bob), bobStETHBefore - bobAmount, "Bob's stETH not deducted");

        // 4. Verify total LP supply increased
        assertEq(lpToken.totalSupply(), lpTokenSupplyBefore + expectedLPTokens, "Total LP supply incorrect");

        // 5. Verify pool maintains correct ratios
        uint256 aliceLPShare = (lpToken.balanceOf(alice) * 1e18) / lpToken.totalSupply();
        uint256 bobLPShare = (lpToken.balanceOf(bob) * 1e18) / lpToken.totalSupply();

        // Alice should have 2/3 of the pool (20 LP tokens out of 30 total)
        // Bob should have 1/3 of the pool (10 LP tokens out of 30 total)

        // Calculate expected shares manually to avoid division precision issues
        // Alice: 20/30 = 666666666666666666 (about 66.67%)
        // Bob: 10/30 = 333333333333333333 (about 33.33%)

        console2.log("Alice LP share (%):", aliceLPShare * 100 / 1e18);
        console2.log("Bob LP share (%):", bobLPShare * 100 / 1e18);

        // Verify shares approximately match expected ratios
        assertTrue(aliceLPShare > 650000000000000000, "Alice should have ~66.7% share"); // > 65%
        assertTrue(aliceLPShare < 670000000000000000, "Alice should have ~66.7% share"); // < 67%
        assertTrue(bobLPShare > 330000000000000000, "Bob should have ~33.3% share"); // > 33%
        assertTrue(bobLPShare < 340000000000000000, "Bob should have ~33.3% share"); // < 34%

        console2.log("Subsequent LP added liquidity:");
        console2.log("  Bob ETH deposited:", bobAmount);
        console2.log("  Bob stETH deposited:", bobAmount);
        console2.log("  Bob LP tokens received:", lpTokensReceived);
        console2.log("  Expected LP tokens:", expectedLPTokens);
        console2.log("  Total LP supply:", lpToken.totalSupply());

        vm.stopPrank();
    }
}
