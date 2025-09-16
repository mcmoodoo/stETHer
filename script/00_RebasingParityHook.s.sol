// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script} from "forge-std/Script.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

import {Constants} from "./base/Constants.sol";
import {RebasingParityHook} from "../src/RebasingParityHook.sol";
import {HookMiner} from "v4-periphery/src/utils/HookMiner.sol";

/// @notice Mines the address and deploys the RebasingParityHook.sol Hook contract
contract RebasingParityHookScript is Script, Constants {
    function setUp() public {}

    function run() public {
        // hook contracts must have specific flags encoded in the address
        uint160 flags = uint160(
            Hooks.BEFORE_SWAP_FLAG | Hooks.AFTER_SWAP_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG
                | Hooks.BEFORE_REMOVE_LIQUIDITY_FLAG
        );

        // Mine a salt that will produce a hook address with the correct flags
        address treasury = address(0x999); // Default treasury for script
        bytes memory constructorArgs = abi.encode(POOLMANAGER, treasury);
        (address hookAddress, bytes32 salt) =
            HookMiner.find(CREATE2_DEPLOYER, flags, type(RebasingParityHook).creationCode, constructorArgs);

        // Deploy the hook using CREATE2
        vm.broadcast();
        RebasingParityHook rebasingParityHook = new RebasingParityHook{salt: salt}(IPoolManager(POOLMANAGER), treasury);
        require(address(rebasingParityHook) == hookAddress, "RebasingParityHookScript: hook address mismatch");
    }
}
