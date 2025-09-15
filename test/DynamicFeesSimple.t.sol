// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {ParityPool} from "../src/ParityPool.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract DynamicFeesSimpleTest is Test, Fixtures {
    ParityPool hook;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4447 << 144)
        );
        bytes memory constructorArgs = abi.encode(manager, address(0x999)); // treasury address
        deployCodeTo("ParityPool.sol:ParityPool", constructorArgs, flags);
        hook = ParityPool(flags);

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_dynamicFee_ethDepletion() public {
        // Setup balanced pool: 1000 ETH, 1000 stETH
        uint256 liquidityAmount = 1000e18;
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);

        console.log("=== INITIAL BALANCED POOL ===");
        console.log("ETH Balance:", manager.balanceOf(address(hook), currency0.toId()));
        console.log("stETH Balance:", manager.balanceOf(address(hook), currency1.toId()));
        
        // Test base fee with balanced pool
        uint256 swapAmount = 100e18;
        uint256 balance0Before = currency0.balanceOfSelf();
        swap(key, false, -int256(swapAmount), ZERO_BYTES);
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 actualOutput1 = balance0After - balance0Before;
        
        console.log("First stETH->ETH swap:");
        console.log("Input stETH:", swapAmount);
        console.log("Output ETH:", actualOutput1);
        console.log("Fee rate:", (swapAmount - actualOutput1) * 10000 / swapAmount, "basis points");
        
        console.log("\nPool after first swap:");
        console.log("ETH Balance:", manager.balanceOf(address(hook), currency0.toId()));
        console.log("stETH Balance:", manager.balanceOf(address(hook), currency1.toId()));
        
        // Keep draining ETH to test increasing fees
        balance0Before = currency0.balanceOfSelf();
        swap(key, false, -int256(swapAmount), ZERO_BYTES);
        balance0After = currency0.balanceOfSelf();
        uint256 actualOutput2 = balance0After - balance0Before;
        
        console.log("\nSecond stETH->ETH swap:");
        console.log("Input stETH:", swapAmount);
        console.log("Output ETH:", actualOutput2);
        console.log("Fee rate:", (swapAmount - actualOutput2) * 10000 / swapAmount, "basis points");
        
        console.log("\nPool after second swap:");
        console.log("ETH Balance:", manager.balanceOf(address(hook), currency0.toId()));
        console.log("stETH Balance:", manager.balanceOf(address(hook), currency1.toId()));
        
        // Third swap should have even higher fee
        balance0Before = currency0.balanceOfSelf();
        swap(key, false, -int256(swapAmount), ZERO_BYTES);
        balance0After = currency0.balanceOfSelf();
        uint256 actualOutput3 = balance0After - balance0Before;
        
        console.log("\nThird stETH->ETH swap:");
        console.log("Input stETH:", swapAmount);
        console.log("Output ETH:", actualOutput3);
        console.log("Fee rate:", (swapAmount - actualOutput3) * 10000 / swapAmount, "basis points");
        
        console.log("\nFinal pool state:");
        console.log("ETH Balance:", manager.balanceOf(address(hook), currency0.toId()));
        console.log("stETH Balance:", manager.balanceOf(address(hook), currency1.toId()));
        
        // Verify fees are increasing as ETH gets depleted
        assertLt(actualOutput2, actualOutput1, "Second swap should have higher fee than first");
        assertLe(actualOutput3, actualOutput2, "Third swap should have equal or higher fee than second");
    }
}