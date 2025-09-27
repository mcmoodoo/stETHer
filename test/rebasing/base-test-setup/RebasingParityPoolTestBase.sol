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

abstract contract RebasingParityPoolTest is Test {
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
    address constant CREATE2_DEPLOYER = address(0x4e59b44847b379578588920cA78FbF26c0B4956C);

    function setUp() public virtual {
        stETH = new StETH();
        protocolRevenue = new ProtocolRevenue(treasury);
        poolManager = new PoolManager(owner);

        // Hook must have these specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        bytes memory constructorArgs = abi.encode(poolManager, address(protocolRevenue));
        (address hookAddress, bytes32 salt) = HookMiner.find(
            address(this),
            flags,
            type(RebasingParityPool).creationCode,
            constructorArgs
        );

        // Log the number of iterations (salt is the iteration count)
        console2.log("Hook mining iterations:", uint256(salt));
        console2.log("Hook address:", hookAddress);

        // Deploy the hook using CREATE2 from the test contract
        rebasingParityPool = new RebasingParityPool{salt: salt}(
            poolManager,
            address(protocolRevenue)
        );

        require(address(rebasingParityPool) == hookAddress, "Hook address mismatch");

        // Create pool key with the deployed hook
        key = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(address(stETH)),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(rebasingParityPool))
        });

        // Initialize the pool
        poolManager.initialize(key, SQRT_PRICE_1_1);

        // Fund test accounts
        vm.deal(alice, 100 ether);
        vm.deal(bob, 100 ether);
        stETH.mint(alice, 100 ether);
        stETH.mint(bob, 100 ether);
    }
}
