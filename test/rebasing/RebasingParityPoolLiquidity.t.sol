// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTestBase} from "./RebasingParityPoolBase.t.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

contract RebasingParityPoolLiquidityTest is RebasingParityPoolTestBase {

    function test_addLiquidity_firstLP() public {
        // vm.startPrank(alice);
        //
        // uint256 ethAmount = 10 ether;
        // uint256 stethAmount = 10 ether;
        //
        // stETH.approve(address(rebasingParityPool), stethAmount);
        //
        // bytes memory data = abi.encode(alice, ethAmount, stethAmount);
        //
        // uint256 feesPerLpToken0 = rebasingParityPool.feesPerLpToken0();
        // uint256 feesPerLpToken1 = rebasingParityPool.feesPerLpToken1();
        //
        // assertEq(feesPerLpToken0, 0, "no Fees for token 0 should have accrued yet");
        // assertEq(feesPerLpToken1, 0, "no Fees for token 1 should have accrued yet");
        //
        //
        // // assertEq(lpBalance, 10 ether, "First LP should get 1:1 LP tokens");
        //
        // // assertEq(rebasingParityPool.poolBalances(0), ethAmount, "Pool ETH balance incorrect");
        // // assertEq(rebasingParityPool.poolBalances(1), stethAmount, "Pool stETH balance incorrect");
        //
        // vm.stopPrank();
    }

    function test_bit_by_bit() public {
        uint256 a = 3;
        a += 1;
        assertEq(a,4);
    }
}
