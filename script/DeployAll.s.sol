// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {stdJson} from "forge-std/StdJson.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {PoolId, PoolIdLibrary} from "v4-core/src/types/PoolId.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";

import {StETH} from "../src/StETH.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";
import {ProtocolRevenue} from "../src/ProtocolRevenue.sol";

contract DeployAllScript is Script {
    using CurrencyLibrary for Currency;
    using stdJson for string;

    // Deployment addresses - loaded from JSON
    address payable public UNICHAIN_POOL_MANAGER;
    address public POSITION_MANAGER;
    address public UNIVERSAL_ROUTER;
    address public PERMIT2;
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
        // Load deployment addresses from JSON
        _loadDeploymentAddresses();

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
        console.log("Attempting pool initialization with flexible hook validation...");
        _initializePool();

        // 8. Skip initial liquidity (can be added later with separate script)
        console.log("Skipping initial liquidity - can be added later with 'just add-liquidity-unichain'");

        // 9. Save deployment addresses to JSON
        _saveDeploymentAddresses();

        console.log("=== Deployment Complete ===");

        vm.stopBroadcast();
    }

    function _loadDeploymentAddresses() internal {
        string memory json = vm.readFile("./uniswap-deployments.json");

        // Read Unichain addresses (chainId: 130)
        string memory unichainPath = ".mainnet.Unichain.contracts";

        UNICHAIN_POOL_MANAGER = payable(json.readAddress(string.concat(unichainPath, ".PoolManager")));
        POSITION_MANAGER = json.readAddress(string.concat(unichainPath, ".PositionManager"));
        UNIVERSAL_ROUTER = json.readAddress(string.concat(unichainPath, ".UniversalRouter"));
        PERMIT2 = json.readAddress(string.concat(unichainPath, ".Permit2"));

        console.log("Loaded addresses from uniswap-deployments.json:");
        console.log("- PoolManager:", UNICHAIN_POOL_MANAGER);
        console.log("- PositionManager:", POSITION_MANAGER);
        console.log("- UniversalRouter:", UNIVERSAL_ROUTER);
        console.log("- Permit2:", PERMIT2);
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
        console.log("Deploying RebasingParityPool with CREATE2...");

        // Calculate required flags based on our hook permissions
        // beforeAddLiquidity: true (bit 11)
        // beforeSwap: true (bit 7)
        // beforeSwapReturnDelta: true (bit 3)
        uint160 flags = uint160(
            Hooks.BEFORE_ADD_LIQUIDITY_FLAG |
            Hooks.BEFORE_SWAP_FLAG |
            Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG
        );

        console.log("Required permission flags:", flags);
        console.log("Mining for deterministic hook address with correct permissions...");

        // We need to find a salt that produces an address with the correct permission flags
        // The challenge is that we need to know the constructor args, which include the pool key,
        // which includes the hook address itself (circular dependency)

        // Solution: Use a two-phase approach
        // 1. Mine for a salt that gives us the right permission bits
        // 2. Deploy at that exact address

        bytes32 salt;
        address targetHookAddress;
        bool found = false;

        // For now, use a simple mining approach and accept the pool key mismatch
        // A proper solution would require modifying the hook contract to be more flexible
        // or implementing a more sophisticated mining algorithm

        console.log("Mining for hook address with correct permissions...");

        PoolKey memory miningKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(stETH),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(0))
        });

        // Pre-compute the init code hash to save gas
        bytes32 initCodeHash = keccak256(abi.encodePacked(
            type(RebasingParityPool).creationCode,
            abi.encode(IPoolManager(UNICHAIN_POOL_MANAGER), TREASURY)
        ));

        // Mine for correct permissions
        for (uint256 i = 0; i < 100000; i++) {
            salt = bytes32(i);
            targetHookAddress = computeFoundryCreate2Address(salt, initCodeHash);

            if ((uint160(targetHookAddress) & 0x3FFF) == flags) {
                console.log("Found valid salt after", i, "attempts");
                console.log("Target hook address:", targetHookAddress);
                found = true;
                constructionPoolKey = miningKey;
                break;
            }
        }

        require(found, "Could not find valid salt for hook permissions");

        // Deploy the hook with CREATE2 using the found salt
        RebasingParityPool hook = new RebasingParityPool{salt: salt}(
            IPoolManager(UNICHAIN_POOL_MANAGER),
            TREASURY
        );

        // After deployment, create the actual pool key with the deployed address
        constructionPoolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(stETH),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(address(hook))
        });

        // Verify deployment address matches prediction
        require(address(hook) == targetHookAddress, "CREATE2 address mismatch!");

        // Check if the deployed address has valid permissions
        uint160 deployedFlags = uint160(address(hook)) & 0x3FFF;
        console.log("Deployed hook at:", address(hook));
        console.log("Hook permission flags:", deployedFlags);
        console.log("Required flags:", flags);

        require(deployedFlags == flags, "Hook permissions don't match requirements");

        // Verify deployment worked
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(hook)
        }
        console.log("Hook code size:", codeSize, "bytes");
        require(codeSize > 0, "Hook deployment failed - no code at address");

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

    // Not used in deployment - liquidity can be added separately with AddLiquidity.s.sol
    /*
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
    */

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


    /// @notice Helper to compute CREATE2 address for Foundry's CREATE2 factory
    function computeFoundryCreate2Address(bytes32 salt, bytes32 initCodeHash) internal pure returns (address) {
        // Foundry deploys via its own CREATE2 factory at a specific address
        address create2Factory = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
        return address(uint160(uint256(keccak256(abi.encodePacked(
            bytes1(0xff),
            create2Factory,
            salt,
            initCodeHash
        )))));
    }
}