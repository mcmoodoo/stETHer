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
    PoolKey public constructionPoolKey; // The pool key used during hook construction
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

        // 7. Initialize the pool
        _initializePool();

        // 8. Add initial liquidity (optional)
        _addInitialLiquidity();

        // 9. Save deployment addresses to JSON
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

        // First, mine with a placeholder PoolKey (hooks set to address(0))
        PoolKey memory miningPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(stETH),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0)) // Placeholder during mining
        });

        // Create constructor args for mining
        bytes memory miningConstructorArgs = abi.encode(
            IPoolManager(UNICHAIN_POOL_MANAGER),
            TREASURY,
            miningPoolKey
        );

        bytes memory miningCreationCode = abi.encodePacked(
            type(RebasingParityPool).creationCode,
            miningConstructorArgs
        );

        // Mine for a valid salt and address
        (bytes32 salt, address minedAddress) = _mineHookAddressWithReturn(miningCreationCode, flags);

        console.log("Mined hook address:", minedAddress);

        // Now create the ACTUAL pool key with the mined hook address
        PoolKey memory actualPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)), // ETH
            currency1: Currency.wrap(stETH),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(minedAddress) // Use the mined address!
        });

        // Create the ACTUAL constructor args with correct hook address
        bytes memory actualConstructorArgs = abi.encode(
            IPoolManager(UNICHAIN_POOL_MANAGER),
            TREASURY,
            actualPoolKey
        );

        bytes memory actualCreationCode = abi.encodePacked(
            type(RebasingParityPool).creationCode,
            actualConstructorArgs
        );

        // Re-mine with the correct pool key containing the mined hook address
        console.log("Re-mining for deployment with correct pool key...");

        // Mine again with the actual constructor args to get the right salt
        (bytes32 deploymentSalt, address finalAddress) = _mineHookAddressWithReturn(actualCreationCode, flags);

        console.log("Final deployment address will be:", finalAddress);

        // Save the construction pool key for later use
        constructionPoolKey = actualPoolKey;

        // Deploy with Solidity's CREATE2 syntax
        RebasingParityPool hook = new RebasingParityPool{salt: deploymentSalt}(
            IPoolManager(UNICHAIN_POOL_MANAGER),
            TREASURY,
            actualPoolKey
        );

        console.log("Actual deployment address:", address(hook));

        if (address(hook) != finalAddress) {
            console.log("ERROR: Address mismatch!");
            console.log("Expected:", finalAddress);
            console.log("Actual:", address(hook));
            console.log("This means the creation code used for mining doesn't match deployment");
        } else {
            console.log("SUCCESS: Hook deployed at the correctly mined address!");
        }

        // Verify deployment worked
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(hook)
        }
        console.log("Hook deployed at:", address(hook));
        console.log("Hook code size:", codeSize, "bytes");
        require(codeSize > 0, "Hook deployment failed - no code at address");

        // Log deployment info
        uint160 deployedFlags = uint160(address(hook)) & 0x3FFF;
        console.log("Deployed address flags:", deployedFlags);
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
        // Use the exact same pool key that was used during hook construction
        poolKey = constructionPoolKey;

        console.log("Pool key created:");
        console.log("  Currency0 (ETH):", Currency.unwrap(poolKey.currency0));
        console.log("  Currency1 (stETH):", Currency.unwrap(poolKey.currency1));
        console.log("  Fee:", poolKey.fee);
        console.log("  Tick Spacing:", poolKey.tickSpacing);
        console.log("  Hooks:", address(poolKey.hooks));
    }

    function _initializePool() internal {
        console.log("Initializing pool...");

        try IPoolManager(UNICHAIN_POOL_MANAGER).initialize(poolKey, SQRT_PRICE_1_1) {
            console.log("Pool initialized successfully with 1:1 price");

            PoolId poolId = PoolIdLibrary.toId(poolKey);
            console.log("Pool ID:");
            console.logBytes32(PoolId.unwrap(poolId));

            // Pool initialization successful
            console.log("Pool initialized with sqrtPriceX96:", SQRT_PRICE_1_1);
        } catch Error(string memory reason) {
            console.log("Pool initialization failed:", reason);
            console.log("This might be because the pool already exists or hook validation failed");
        } catch {
            console.log("Pool initialization failed with unknown error");
        }
    }

    function _addInitialLiquidity() internal {
        console.log("Adding initial liquidity...");

        // For now, we'll assume pool initialization worked
        // In production, you'd want to check pool state properly
        console.log("Preparing to add initial liquidity...");

        // Add a small amount of initial liquidity (0.1 ETH and equivalent stETH)
        uint256 initialLiquidity = 0.1 ether;

        // First, mint some stETH to the deployer
        console.log("Minting stETH for initial liquidity...");
        StETH(stETH).mint(msg.sender, initialLiquidity);
        console.log("Minted", initialLiquidity, "stETH");

        // Check stETH balance
        uint256 stethBalance = StETH(stETH).balanceOf(msg.sender);
        console.log("Deployer stETH balance:", stethBalance);

        // Approve stETH spending to the hook
        StETH(stETH).approve(rebasingParityPool, initialLiquidity);

        // Add liquidity through the hook's addLiquidity function
        try RebasingParityPool(rebasingParityPool).addLiquidity{value: initialLiquidity}(
            poolKey,
            initialLiquidity
        ) returns (uint256 lpTokens) {
            console.log("Initial liquidity added successfully");
            console.log("LP tokens received:", lpTokens);
            console.log("ETH deposited:", initialLiquidity);
            console.log("stETH deposited:", initialLiquidity);
        } catch Error(string memory reason) {
            console.log("Adding liquidity failed:", reason);
            console.log("You may need to manually add liquidity after deployment");
        } catch {
            console.log("Adding liquidity failed with unknown error");
        }
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

            // Use vm.computeCreate2Address with Foundry's CREATE2 factory
            // Foundry uses the CREATE2 factory at this address
            address hookAddress = vm.computeCreate2Address(
                saltBytes,
                initCodeHash,
                0x4e59b44847b379578588920cA78FbF26c0B4956C
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

    /// @notice Mine for a valid hook address and return both salt and address
    function _mineHookAddressWithReturn(bytes memory creationCode, uint160 flags) internal returns (bytes32, address) {
        bytes32 initCodeHash = keccak256(creationCode);

        for (uint256 salt = 0; salt < 1000000; salt++) {
            bytes32 saltBytes = bytes32(salt);

            // Use vm.computeCreate2Address with Foundry's CREATE2 factory
            // Foundry uses the CREATE2 factory at this address
            address hookAddress = vm.computeCreate2Address(
                saltBytes,
                initCodeHash,
                0x4e59b44847b379578588920cA78FbF26c0B4956C
            );

            // Check if the address matches the required flags
            // The hook address must have its lower 14 bits match the permission flags
            if (uint160(hookAddress) & 0x3FFF == flags) {
                console.log("Found valid address after", salt, "attempts");
                console.log("Target hook address:", hookAddress);
                return (saltBytes, hookAddress);
            }
        }

        revert("Could not find valid hook address within reasonable attempts");
    }
}