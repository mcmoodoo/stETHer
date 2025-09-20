// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolManager} from "v4-core/src/PoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {LPFeeLibrary} from "v4-core/src/libraries/LPFeeLibrary.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

import {StETH} from "../src/StETH.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";
import {ParityLP} from "../src/ParityLP.sol";
import {ProtocolRevenue} from "../src/ProtocolRevenue.sol";

contract DeployAllScript is Script {
    using CurrencyLibrary for Currency;

    // Deployment addresses
    address payable public constant UNICHAIN_POOL_MANAGER = payable(0x1F98400000000000000000000000000000000004);
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

        // 1. Use existing Unichain PoolManager
        console.log("Using Unichain PoolManager at:", UNICHAIN_POOL_MANAGER);

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

        // 7. Skip pool initialization for now
        console.log("Skipping pool initialization - hook implementation needs refinement");

        // 8. Save deployment addresses to JSON
        _saveDeploymentAddresses();

        console.log("=== Deployment Complete ===");

        vm.stopBroadcast();
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

        // Mine for a valid hook address using CREATE2
        console.log("Mining for valid hook address...");

        // Calculate required flags based on our hook permissions
        // beforeAddLiquidity: true (bit 2)
        // beforeSwap: true (bit 6)
        // beforeSwapReturnDelta: true (bit 10)
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        bytes memory creationCode = abi.encodePacked(
            type(RebasingParityPool).creationCode,
            abi.encode(
                IPoolManager(UNICHAIN_POOL_MANAGER),
                TREASURY,
                allowedPoolKey
            )
        );

        bytes32 salt = _mineHookAddress(creationCode, flags);

        // Deploy with the mined salt
        RebasingParityPool hook = new RebasingParityPool{salt: salt}(
            IPoolManager(UNICHAIN_POOL_MANAGER),
            TREASURY,
            allowedPoolKey
        );

        // Log deployment info
        uint160 deployedFlags = uint160(address(hook)) & 0x3FFF;
        console.log("Required flags:", flags);
        console.log("Deployed flags:", deployedFlags);
        console.log("Hook validation will be performed by PoolManager");

        console.log("RebasingParityPool deployed at:", address(hook));
        return address(hook);
    }

    function _getParityLPAddress() internal view returns (address) {
        address lpToken = address(RebasingParityPool(rebasingParityPool).LP_TOKEN());
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
        IPoolManager(UNICHAIN_POOL_MANAGER).initialize(poolKey, SQRT_PRICE_1_1);

        PoolId poolId = PoolIdLibrary.toId(poolKey);
        console.logBytes32(PoolId.unwrap(poolId));
    }

    function _saveDeploymentAddresses() internal {
        console.log("=== Deployment Addresses ===");
        console.log("Network:", _getNetworkName());
        console.log("PoolManager:", UNICHAIN_POOL_MANAGER);
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
            '    "PoolManager": "', vm.toString(UNICHAIN_POOL_MANAGER), '",\n',
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
        if (chainId == 130) return "unichain";
        if (chainId == 11155111) return "sepolia";
        if (chainId == 31337) return "localhost";
        if (chainId == 1337) return "localhost";
        return string(abi.encodePacked("chain-", vm.toString(chainId)));
    }

    /// @notice Mine for a valid hook address that matches the required permissions
    function _mineHookAddress(bytes memory creationCode, uint160 flags) internal returns (bytes32) {
        bytes32 initCodeHash = keccak256(creationCode);

        for (uint256 salt = 0; salt < 1000000; salt++) {
            bytes32 saltBytes = bytes32(salt);

            // Use vm.computeCreate2Address with the actual deployer that will be used
            address hookAddress = vm.computeCreate2Address(
                saltBytes,
                initCodeHash,
                msg.sender
            );

            // Check if the address matches the required flags
            // The hook address must have its lower 14 bits match the permission flags
            if (uint160(hookAddress) & 0x3FFF == flags) {
                console.log("Found valid address after", salt, "attempts");
                console.log("Target hook address:", hookAddress);
                return saltBytes;
            }
        }

        revert("Could not find valid hook address within reasonable attempts");
    }
}