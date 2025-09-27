// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTest} from "./RebasingParityPoolBase.t.sol";
import {console2} from "forge-std/console2.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {StateLibrary} from "@uniswap/v4-core/src/libraries/StateLibrary.sol";
import {ParityLP} from "src/ParityLP.sol";

contract RebasingParityPoolLiquidityTest is RebasingParityPoolTest {
    using StateLibrary for IPoolManager;

    function test_eth_balance() public {
        assertEq(bob.balance, 100 ether);
    }

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
}
