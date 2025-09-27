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
import {TickMath} from "@uniswap/v4-core/src/libraries/TickMath.sol";

contract RebasingParityPoolDeployCodeToTest is Test {
    RebasingParityPool rebasingParityPool;
    StETH stETH;
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

        // Hook must have these specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        // Calculate the required address pattern
        // The address needs to have the flag bits set in the last 160 bits
        // For our flags: 0x888 (bits 3, 7, and 11)
        address targetHookAddress = address(uint160(0x8888888888888888888888888888888888880888));

        console2.log("Target hook address:", targetHookAddress);
        console2.log("Required flags:", flags);

        // Deploy the RebasingParityPool directly to the target address
        // First deploy normally, then copy bytecode to target address
        bytes memory constructorArgs = abi.encode(poolManager, address(protocolRevenue));

        // Deploy a temporary instance to get the runtime bytecode
        address tempDeployment = vm.deployCode(
            "RebasingParityPool.sol:RebasingParityPool",
            constructorArgs
        );

        // Get the deployed bytecode from the temporary instance
        bytes memory deployedBytecode = tempDeployment.code;

        // Use etch to place the bytecode at our target address with correct permission bits
        vm.etch(targetHookAddress, deployedBytecode);

        // Cast to our hook interface
        rebasingParityPool = RebasingParityPool(targetHookAddress);

        // Verify the hook has correct permissions
        uint160 hookAddressUint = uint160(targetHookAddress);
        require(hookAddressUint & flags == flags, "Hook address doesn't have required permission bits");

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

    function test_deployCodeTo_setup() public {
        // Verify the hook address has the correct permission bits
        address hookAddr = address(rebasingParityPool);
        uint160 hookAddrUint = uint160(hookAddr);

        // Check individual flags
        assertTrue(hookAddrUint & Hooks.BEFORE_ADD_LIQUIDITY_FLAG == Hooks.BEFORE_ADD_LIQUIDITY_FLAG, "Missing BEFORE_ADD_LIQUIDITY_FLAG");
        assertTrue(hookAddrUint & Hooks.BEFORE_SWAP_FLAG == Hooks.BEFORE_SWAP_FLAG, "Missing BEFORE_SWAP_FLAG");
        assertTrue(hookAddrUint & Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG == Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG, "Missing BEFORE_SWAP_RETURNS_DELTA_FLAG");

        console2.log("Hook deployed at:", hookAddr);
        console2.log("Hook address as uint160:", hookAddrUint);
        console2.log("Last 2 bytes (hex):", hookAddrUint & 0xFFFF);
    }
}
