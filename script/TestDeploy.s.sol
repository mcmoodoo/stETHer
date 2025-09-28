// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";

contract TestDeployScript is Script {
    function run() external {
        console.log("=== Test Deployment Script ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);
        console.log("Block number:", block.number);

        // Get sender balance
        uint256 balance = msg.sender.balance;
        console.log("Deployer balance:", balance / 1e18, "ETH");

        vm.startBroadcast();

        // Deploy a simple test contract to verify broadcasting works
        TestContract test = new TestContract();
        console.log("Test contract deployed at:", address(test));

        vm.stopBroadcast();

        console.log("=== Test Complete ===");
    }
}

contract TestContract {
    uint256 public value = 42;

    function getValue() public view returns (uint256) {
        return value;
    }
}