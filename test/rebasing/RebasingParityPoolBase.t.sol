// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console2} from "forge-std/console2.sol";
import {RebasingParityPool} from "src/RebasingParityPool.sol";
import {StETH} from "src/StETH.sol";
import {ProtocolRevenue} from "src/ProtocolRevenue.sol";

import {IPoolManager} from "@uniswap/v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "@uniswap/v4-core/src/types/PoolKey.sol";
import {Currency} from "@uniswap/v4-core/src/types/Currency.sol";
import {IHooks} from "@uniswap/v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "@uniswap/v4-core/src/libraries/Hooks.sol";
import {PoolManager} from "@uniswap/v4-core/src/PoolManager.sol";
import {HookMiner} from "@uniswap/v4-periphery/src/utils/HookMiner.sol";

contract RebasingParityPoolTestBase is Test {
    StETH stETH;
    RebasingParityPool rebasingParityPool;
    ProtocolRevenue protocolRevenue;
    IPoolManager poolManager;
    PoolKey key;

    address owner = address(0x111);
    address alice = address(0x1);
    address bob = address(0x2);
    address treasury = address(0x999);

    uint160 constant SQRT_PRICE_1_1 = 79228162514264337593543950336;

    function setUp() public virtual {
        stETH = new StETH();
        protocolRevenue = new ProtocolRevenue(treasury);
        poolManager = new PoolManager(owner);

        uint160 flags = uint160(Hooks.BEFORE_ADD_LIQUIDITY_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_SWAP_FLAG);

        rebasingParityPool = new RebasingParityPool(
            poolManager,
            address(protocolRevenue)
        );

        bytes memory constructorArgs = abi.encode(poolManager);
        
        console2.logBytes(constructorArgs);

        (address hookAddress, bytes32 salt) = HookMiner.find(address(this), flags, type(RebasingParityPool).creationCode, constructorArgs);

        assertEq(hookAddress & 0x888, 0x888);

        // key = PoolKey({
        //     currency0: Currency.wrap(address(0)),
        //     currency1: Currency.wrap(address(stETH)),
        //     fee: 3000,
        //     tickSpacing: 60,
        //     hooks: IHooks(address(0))
        // });
        //
        // key.hooks = IHooks(address(rebasingParityPool));
        //
        // poolManager.initialize(key, SQRT_PRICE_1_1);
        //
        // vm.deal(alice, 100 ether);
        // vm.deal(bob, 100 ether);
        // stETH.mint(alice, 100 ether);
        // stETH.mint(bob, 100 ether);
    }
}
