// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";

import {Constants} from "./base/Constants.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

/// @notice Mines the address and deploys the RebasingParityPool.sol Hook contract
contract RebasingParityPoolScript is Script, Constants {
    function setUp() public {}

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        address treasury = address(0x999); // Default treasury for script

        // Create a dummy pool key for the script (ETH/stETH, 0.3% fee, 60 tick spacing)
        PoolKey memory poolKey = PoolKey(
            Currency.wrap(address(0)), // ETH
            Currency.wrap(address(0x888)), // Dummy stETH address
            3000, // 0.3% fee
            60, // tick spacing
            IHooks(address(0)) // Will be set to actual hook address
        );

        bytes memory constructorArgs = abi.encode(POOLMANAGER, treasury, poolKey);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(RebasingParityPool).creationCode, constructorArgs);

        // Update pool key with actual hook address
        poolKey.hooks = IHooks(hookAddress);

        // Deploy the hook using CREATE2
        vm.broadcast();
        RebasingParityPool rebasingParityHook = new RebasingParityPool{salt: salt}(IPoolManager(POOLMANAGER), treasury, poolKey);
        require(address(rebasingParityHook) == hookAddress, "RebasingParityPoolScript: hook address mismatch");
    }
}
