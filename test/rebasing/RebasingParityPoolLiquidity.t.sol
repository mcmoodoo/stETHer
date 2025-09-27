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

    function test_removeLiquidity_fullWithdrawal() public {
        // First, Alice adds liquidity
        vm.startPrank(alice);
        uint256 aliceAmount = 10 ether;
        stETH.approve(address(rebasingParityPool), aliceAmount);
        uint256 lpTokensReceived = rebasingParityPool.addLiquidity{value: aliceAmount}(key, aliceAmount);

        // Get LP token contract
        ParityLP lpToken = ParityLP(address(rebasingParityPool.LP_TOKEN()));

        // Track balances before removal
        uint256 aliceETHBefore = alice.balance;
        uint256 aliceStETHBefore = stETH.balanceOf(alice);
        uint256 aliceLPBefore = lpToken.balanceOf(alice);
        uint256 poolETHBefore = rebasingParityPool.poolETHBalance();
        uint256 poolStETHBefore = rebasingParityPool.poolStETHBalance();

        assertEq(aliceLPBefore, lpTokensReceived, "LP balance should match received tokens");
        assertEq(poolETHBefore, aliceAmount, "Pool should have ETH");
        assertEq(poolStETHBefore, aliceAmount, "Pool should have stETH");

        // Remove all liquidity
        (uint256 amount0, uint256 amount1) = rebasingParityPool.removeLiquidity(key, lpTokensReceived);

        // Assertions after full withdrawal

        // 1. Verify LP tokens burned
        assertEq(lpToken.balanceOf(alice), 0, "All LP tokens should be burned");
        assertEq(lpToken.totalSupply(), 0, "Total LP supply should be 0");

        // 2. Verify user received back their tokens
        assertEq(alice.balance, aliceETHBefore + amount0, "Alice should receive ETH back");
        assertEq(stETH.balanceOf(alice), aliceStETHBefore + amount1, "Alice should receive stETH back");

        // 3. Verify amounts match deposited amounts (no fees in this scenario)
        assertEq(amount0, aliceAmount, "Should receive back all ETH");
        assertEq(amount1, aliceAmount, "Should receive back all stETH");

        // 4. Verify pool is empty
        assertEq(rebasingParityPool.poolETHBalance(), 0, "Pool ETH balance should be 0");
        assertEq(rebasingParityPool.poolStETHBalance(), 0, "Pool stETH balance should be 0");
        assertEq(rebasingParityPool.poolStETHPrincipal(), 0, "Pool stETH principal should be 0");
        assertEq(rebasingParityPool.totalLiquidity(), 0, "Total liquidity should be 0");

        console2.log("Full withdrawal completed:");
        console2.log("  LP tokens burned:", lpTokensReceived);
        console2.log("  ETH received:", amount0);
        console2.log("  stETH received:", amount1);

        vm.stopPrank();
    }

    function test_removeLiquidity_partialWithdrawal() public {
        // First, Alice adds liquidity
        vm.startPrank(alice);
        uint256 aliceAmount = 20 ether;
        stETH.approve(address(rebasingParityPool), aliceAmount);
        uint256 lpTokensReceived = rebasingParityPool.addLiquidity{value: aliceAmount}(key, aliceAmount);

        // Get LP token contract
        ParityLP lpToken = ParityLP(address(rebasingParityPool.LP_TOKEN()));

        // Track balances before partial removal
        uint256 aliceETHBefore = alice.balance;
        uint256 aliceStETHBefore = stETH.balanceOf(alice);
        uint256 aliceLPBefore = lpToken.balanceOf(alice);
        uint256 poolETHBefore = rebasingParityPool.poolETHBalance();
        uint256 poolStETHBefore = rebasingParityPool.poolStETHBalance();
        uint256 poolPrincipalBefore = rebasingParityPool.poolStETHPrincipal();

        // Remove 25% of liquidity (10 out of 40 LP tokens)
        uint256 lpTokensToRemove = lpTokensReceived / 4; // 25%
        (uint256 amount0, uint256 amount1) = rebasingParityPool.removeLiquidity(key, lpTokensToRemove);

        // Calculate expected amounts (25% of pool)
        uint256 expectedETH = aliceAmount / 4;
        uint256 expectedStETH = aliceAmount / 4;

        // Assertions after partial withdrawal

        // 1. Verify correct LP tokens burned
        assertEq(lpToken.balanceOf(alice), aliceLPBefore - lpTokensToRemove, "Should have 75% LP tokens left");
        assertEq(lpToken.totalSupply(), lpTokensReceived - lpTokensToRemove, "Total supply should decrease by 25%");

        // 2. Verify user received correct amounts
        assertEq(alice.balance, aliceETHBefore + amount0, "Alice should receive 25% ETH");
        assertEq(stETH.balanceOf(alice), aliceStETHBefore + amount1, "Alice should receive 25% stETH");
        assertEq(amount0, expectedETH, "ETH amount should be 25% of pool");
        assertEq(amount1, expectedStETH, "stETH amount should be 25% of pool");

        // 3. Verify pool still has remaining liquidity (75%)
        assertEq(rebasingParityPool.poolETHBalance(), poolETHBefore - expectedETH, "Pool should have 75% ETH left");
        assertEq(rebasingParityPool.poolStETHBalance(), poolStETHBefore - expectedStETH, "Pool should have 75% stETH left");
        assertEq(rebasingParityPool.poolStETHPrincipal(), poolPrincipalBefore - expectedStETH, "Principal should decrease proportionally");

        // 4. Verify total liquidity
        uint256 remainingLiquidity = (aliceAmount - expectedETH) + (aliceAmount - expectedStETH);
        assertEq(rebasingParityPool.totalLiquidity(), remainingLiquidity, "Total liquidity should be 75% of original");

        console2.log("Partial withdrawal (25%) completed:");
        console2.log("  LP tokens burned:", lpTokensToRemove);
        console2.log("  LP tokens remaining:", lpToken.balanceOf(alice));
        console2.log("  ETH received:", amount0);
        console2.log("  stETH received:", amount1);
        console2.log("  Pool ETH remaining:", rebasingParityPool.poolETHBalance());
        console2.log("  Pool stETH remaining:", rebasingParityPool.poolStETHBalance());

        // Now remove another 50% of original (20 out of original 40 LP tokens)
        uint256 secondRemoval = lpTokensReceived / 2;
        (uint256 amount0_2, uint256 amount1_2) = rebasingParityPool.removeLiquidity(key, secondRemoval);

        // Verify second removal
        assertEq(lpToken.balanceOf(alice), lpTokensReceived - lpTokensToRemove - secondRemoval, "Should have 25% LP tokens left");
        assertEq(amount0_2, aliceAmount / 2, "Second removal should get 50% of original ETH");
        assertEq(amount1_2, aliceAmount / 2, "Second removal should get 50% of original stETH");

        console2.log("Second partial withdrawal (50% of original) completed:");
        console2.log("  Additional ETH received:", amount0_2);
        console2.log("  Additional stETH received:", amount1_2);
        console2.log("  LP tokens remaining after second removal:", lpToken.balanceOf(alice));

        vm.stopPrank();
    }

    function test_addLiquidity_onlyETH_reverts() public {
        // Test that providing only ETH without stETH approval/balance fails
        vm.startPrank(alice);

        uint256 liquidityAmount = 10 ether;

        // Do NOT approve stETH - this should cause the transaction to fail
        // when the hook tries to transfer stETH from alice

        // Attempt to add liquidity with only ETH (no stETH approval)
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        rebasingParityPool.addLiquidity{value: liquidityAmount}(key, liquidityAmount);

        console2.log("Correctly reverted when trying to add liquidity with only ETH");

        vm.stopPrank();
    }

    function test_addLiquidity_zeroAmount_reverts() public {
        // Test that adding zero liquidity reverts
        vm.startPrank(alice);

        // Even with approval, zero amount should fail
        stETH.approve(address(rebasingParityPool), type(uint256).max);

        // Try to add zero liquidity - should revert when minting 0 LP tokens
        vm.expectRevert(); // May revert with division by zero or similar
        rebasingParityPool.addLiquidity{value: 0}(key, 0);

        console2.log("Correctly reverted when trying to add zero liquidity");

        vm.stopPrank();
    }

    function test_addLiquidity_mismatchedETHAmount_reverts() public {
        // Test that sending wrong ETH amount via msg.value fails
        vm.startPrank(alice);

        uint256 expectedAmount = 10 ether;
        uint256 wrongETHAmount = 5 ether; // Send less ETH than expected

        // Approve correct stETH amount
        stETH.approve(address(rebasingParityPool), expectedAmount);

        // Try to add liquidity with mismatched ETH amount
        // The poolManager.settle() will fail because msg.value doesn't match amountPerToken
        vm.expectRevert(); // PoolManager will revert on settle with wrong value
        rebasingParityPool.addLiquidity{value: wrongETHAmount}(key, expectedAmount);

        console2.log("Correctly reverted when ETH amount doesn't match amountPerToken");

        vm.stopPrank();
    }

    function test_lpToken_onlyHook_canMintBurn() public {
        // Test that only the hook contract can mint and burn LP tokens
        ParityLP lpToken = ParityLP(address(rebasingParityPool.LP_TOKEN()));

        // Try to mint directly as Alice (should fail)
        vm.startPrank(alice);
        vm.expectRevert("Only hook can mint/burn");
        lpToken.mint(alice, 100 ether);

        // Try to burn directly as Alice (should fail)
        vm.expectRevert("Only hook can mint/burn");
        lpToken.burn(alice, 10 ether);
        vm.stopPrank();

        // Try to mint as the owner (should still fail)
        vm.startPrank(owner);
        vm.expectRevert("Only hook can mint/burn");
        lpToken.mint(alice, 100 ether);
        vm.stopPrank();

        // Verify the hook CAN mint (by adding liquidity)
        vm.startPrank(alice);
        stETH.approve(address(rebasingParityPool), 5 ether);
        uint256 lpTokensReceived = rebasingParityPool.addLiquidity{value: 5 ether}(key, 5 ether);
        assertGt(lpTokensReceived, 0, "Hook should successfully mint LP tokens");
        assertEq(lpToken.balanceOf(alice), lpTokensReceived, "Alice should have the minted tokens");

        // Verify the hook CAN burn (by removing liquidity)
        rebasingParityPool.removeLiquidity(key, lpTokensReceived);
        assertEq(lpToken.balanceOf(alice), 0, "Hook should successfully burn LP tokens");
        vm.stopPrank();

        console2.log("LP token access control verified:");
        console2.log("  Direct mint/burn attempts: Correctly rejected");
        console2.log("  Hook mint via addLiquidity: Success");
        console2.log("  Hook burn via removeLiquidity: Success");
    }
}
