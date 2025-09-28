// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {StETH} from "../src/StETH.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";
import {ProtocolRevenue} from "../src/ProtocolRevenue.sol";

contract VerifyDeploymentScript is Script {
    function run() external view {
        console.log("=== Verifying Unichain Deployment ===");
        console.log("");

        // Load deployment addresses
        address stETH = 0x51aE19065794D01886f97A93E7DC5967940f2894;
        address protocolRevenue = 0x581E767fFF7136f57D33109BfB6121a01c7bc868;
        address rebasingParityPool = 0x522C190f46256270177F9aC6AF296319f157c888;
        address parityLP = 0x8D5E57cf10877E42654d6a084b0511F4E94d0e5B;

        // Check if contracts exist
        console.log("Checking contract deployments...");

        uint256 stethCode;
        uint256 prCode;
        uint256 poolCode;
        uint256 lpCode;

        assembly {
            stethCode := extcodesize(stETH)
            prCode := extcodesize(protocolRevenue)
            poolCode := extcodesize(rebasingParityPool)
            lpCode := extcodesize(parityLP)
        }

        console.log("");
        console.log("Contract sizes:");
        console.log("  StETH:", stethCode, "bytes", stethCode > 0 ? "✅" : "❌");
        console.log("  ProtocolRevenue:", prCode, "bytes", prCode > 0 ? "✅" : "❌");
        console.log("  RebasingParityPool:", poolCode, "bytes", poolCode > 0 ? "✅" : "❌");
        console.log("  ParityLP:", lpCode, "bytes", lpCode > 0 ? "✅" : "❌");

        if (stethCode > 0) {
            console.log("");
            console.log("StETH details:");
            console.log("  Name:", StETH(stETH).name());
            console.log("  Symbol:", StETH(stETH).symbol());
            console.log("  Total Supply:", StETH(stETH).totalSupply());
        }

        if (poolCode > 0) {
            console.log("");
            console.log("RebasingParityPool details:");
            console.log("  LP Token:", address(RebasingParityPool(rebasingParityPool).LP_TOKEN()));
            console.log("  Treasury:", RebasingParityPool(rebasingParityPool).TREASURY());
        }

        console.log("");
        console.log("=== Verification Complete ===");

        bool allDeployed = stethCode > 0 && prCode > 0 && poolCode > 0 && lpCode > 0;
        if (allDeployed) {
            console.log("✅ All contracts successfully deployed!");
            console.log("");
            console.log("Next steps:");
            console.log("1. Add ETH to your wallet for liquidity (at least 0.1 ETH recommended)");
            console.log("2. Run 'just add-liquidity-unichain' to add initial liquidity");
            console.log("3. Update the UI to connect to Unichain mainnet");
        } else {
            console.log("❌ Some contracts are missing. Please check deployment.");
        }
    }
}