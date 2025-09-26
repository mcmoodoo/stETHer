// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {RebasingParityPoolTestBase} from "./RebasingParityPoolBase.t.sol";
import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {BalanceDelta} from "@uniswap/v4-core/src/types/BalanceDelta.sol";

contract RebasingParityPoolLiquidityTest is RebasingParityPoolTestBase {

    function test_bit_by_bit() public {
        uint256 a = 3;
        a += 1;
        assertEq(a,4);
    }
}
