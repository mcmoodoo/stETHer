// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/PoolManager.sol";
import {IHooks} from "v4-core/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/libraries/LPFeeLibrary.sol";
import {Hooks} from "v4-core/libraries/Hooks.sol";

import {StETH} from "../src/StETH.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";
import {ParityLP} from "../src/ParityLP.sol";
import {ProtocolRevenue} from "../src/ProtocolRevenue.sol";

contract DeployAllScript is Script {
    using CurrencyLibrary for Currency;

    // Deployment addresses
    address payable public poolManager;
    address public stETH;
    address public protocolRevenue;
    address public rebasingParityPool;
    address public parityLP;

    // Pool configuration
    PoolKey public poolKey;
    uint24 public constant POOL_FEE = 3000; // 0.3%
    int24 public constant TICK_SPACING = 60;
    uint160 public constant SQRT_PRICE_1_1 = 79228162514264337593543950336; // sqrt(1) in Q64.96

    // Treasury address (can be changed later)
    address public constant TREASURY = 0x1234567890123456789012345678901234567890;

    function run() external {
        vm.startBroadcast();

        console.log("=== Deploying All Contracts ===");
        console.log("Deployer:", msg.sender);
        console.log("Chain ID:", block.chainid);

        // 1. Deploy PoolManager (if not already deployed)
        poolManager = _deployPoolManager();

        // 2. Deploy StETH token
        stETH = _deployStETH();

        // 3. Deploy ProtocolRevenue
        protocolRevenue = _deployProtocolRevenue();

        // 4. Deploy RebasingParityPool (hook)
        rebasingParityPool = _deployRebasingParityPool();

        // 5. Get ParityLP address from the hook
        parityLP = _getParityLPAddress();

        // 6. Create pool key
        _createPoolKey();

        // 7. Initialize the pool
        _initializePool();

        // 8. Save deployment addresses to JSON
        _saveDeploymentAddresses();

        console.log("=== Deployment Complete ===");

        vm.stopBroadcast();
    }

    function _deployPoolManager() internal returns (address payable) {
        // Check if pool manager is already deployed on this chain
        // For local development, always deploy new
        // For testnets/mainnet, you might want to use existing pool manager

        console.log("Deploying PoolManager...");
        PoolManager pm = new PoolManager();
        console.log("PoolManager deployed at:", address(pm));
        return payable(address(pm));
    }

    function _deployStETH() internal returns (address) {
        console.log("Deploying StETH...");
        StETH token = new StETH();
        console.log("StETH deployed at:", address(token));
        return address(token);
    }

    function _deployProtocolRevenue() internal returns (address) {
        console.log("Deploying ProtocolRevenue...");
        ProtocolRevenue pr = new ProtocolRevenue(TREASURY);
        console.log("ProtocolRevenue deployed at:", address(pr));
        return address(pr);
    }

    function _deployRebasingParityPool() internal returns (address) {
        console.log("Deploying RebasingParityPool...");

        // Create the pool key that will be allowed
        PoolKey memory allowedPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(stETH),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0)) // Will be set after deployment
        });

        RebasingParityPool hook = new RebasingParityPool(
            IPoolManager(poolManager),
            TREASURY,
            allowedPoolKey
        );

        console.log("RebasingParityPool deployed at:", address(hook));
        return address(hook);
    }

    function _getParityLPAddress() internal view returns (address) {
        address lpToken = RebasingParityPool(rebasingParityPool).LP_TOKEN();
        console.log("ParityLP address:", lpToken);
        return lpToken;
    }

    function _createPoolKey() internal {
        poolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(stETH),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(rebasingParityPool)
        });

        console.log("Pool key created:");
        console.log("  Currency0 (ETH):", Currency.unwrap(poolKey.currency0));
        console.log("  Currency1 (stETH):", Currency.unwrap(poolKey.currency1));
        console.log("  Fee:", poolKey.fee);
        console.log("  Tick Spacing:", poolKey.tickSpacing);
        console.log("  Hooks:", address(poolKey.hooks));
    }

    function _initializePool() internal {
        console.log("Initializing pool...");

        // Initialize the pool with 1:1 price
        IPoolManager(poolManager).initialize(poolKey, SQRT_PRICE_1_1);

        PoolId poolId = PoolIdLibrary.toId(poolKey);
        console.log("Pool initialized with ID:", PoolId.unwrap(poolId));
    }

    function _saveDeploymentAddresses() internal {
        console.log("=== Deployment Addresses ===");
        console.log("Network:", _getNetworkName());
        console.log("PoolManager:", poolManager);
        console.log("StETH:", stETH);
        console.log("ProtocolRevenue:", protocolRevenue);
        console.log("RebasingParityPool:", rebasingParityPool);
        console.log("ParityLP:", parityLP);

        // Create JSON string for addresses
        string memory json = string(abi.encodePacked(
            '{\n',
            '  "network": "', _getNetworkName(), '",\n',
            '  "chainId": ', vm.toString(block.chainid), ',\n',
            '  "timestamp": ', vm.toString(block.timestamp), ',\n',
            '  "deployer": "', vm.toString(msg.sender), '",\n',
            '  "contracts": {\n',
            '    "PoolManager": "', vm.toString(poolManager), '",\n',
            '    "StETH": "', vm.toString(stETH), '",\n',
            '    "ProtocolRevenue": "', vm.toString(protocolRevenue), '",\n',
            '    "RebasingParityPool": "', vm.toString(rebasingParityPool), '",\n',
            '    "ParityLP": "', vm.toString(parityLP), '"\n',
            '  },\n',
            '  "poolKey": {\n',
            '    "currency0": "', vm.toString(Currency.unwrap(poolKey.currency0)), '",\n',
            '    "currency1": "', vm.toString(Currency.unwrap(poolKey.currency1)), '",\n',
            '    "fee": ', vm.toString(poolKey.fee), ',\n',
            '    "tickSpacing": ', vm.toString(int256(poolKey.tickSpacing)), ',\n',
            '    "hooks": "', vm.toString(address(poolKey.hooks)), '"\n',
            '  }\n',
            '}'
        ));

        // Write to file for UI consumption
        string memory filename = string(abi.encodePacked("deployments-", _getNetworkName(), ".json"));
        vm.writeFile(string(abi.encodePacked("ui/src/deployments/", filename)), json);

        console.log("Deployment addresses saved to:", string(abi.encodePacked("ui/src/deployments/", filename)));
    }

    function _getNetworkName() internal view returns (string memory) {
        uint256 chainId = block.chainid;
        if (chainId == 1) return "mainnet";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 31337) return "localhost";
        if (chainId == 1337) return "localhost";
        return string(abi.encodePacked("chain-", vm.toString(chainId)));
    }
}