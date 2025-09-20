// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";

import {RebasingParityPool} from "../src/RebasingParityPool.sol";

contract SimpleDeployTest is Script {
    using CurrencyLibrary for Currency;

    address payable public constant UNICHAIN_POOL_MANAGER = payable(0x1F98400000000000000000000000000000000004);
    address public constant TREASURY = 0x1234567890123456789012345678901234567890;
    address public constant TEST_STETH = 0x59b670e9fA9D0A427751Af201D676719a970857b;

    function run() external {
        vm.startBroadcast();

        console.log("=== SIMPLE CREATE2 TEST ===");
        console.log("Deployer:", msg.sender);

        // Create simple pool key
        PoolKey memory testPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(TEST_STETH),
            fee: 3000,
            tickSpacing: 60,
            hooks: IHooks(address(0))
        });

        // Test with salt 0
        bytes32 salt = bytes32(0);

        // Predict address
        bytes memory constructorArgs = abi.encode(
            IPoolManager(UNICHAIN_POOL_MANAGER),
            TREASURY,
            testPoolKey
        );
        bytes memory creationCode = abi.encodePacked(
            type(RebasingParityPool).creationCode,
            constructorArgs
        );
        bytes32 initCodeHash = keccak256(creationCode);
        address predicted = vm.computeCreate2Address(salt, initCodeHash, 0x4e59b44847b379578588920cA78FbF26c0B4956C);

        console.log("Predicted address:", predicted);

        // Deploy
        RebasingParityPool hook = new RebasingParityPool{salt: salt}(
            IPoolManager(UNICHAIN_POOL_MANAGER),
            TREASURY,
            testPoolKey
        );

        console.log("Actual address:", address(hook));
        console.log("Addresses match:", predicted == address(hook));

        vm.stopBroadcast();
    }
}