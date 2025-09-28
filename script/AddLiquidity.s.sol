// SPDX-License-Identifier: MIT
pragma solidity ^0.8.26;

import {Script, console} from "forge-std/Script.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {CurrencyLibrary, Currency} from "v4-core/src/types/Currency.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {StETH} from "../src/StETH.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";

contract AddLiquidityScript is Script {
    using CurrencyLibrary for Currency;

    // Deployed addresses on Unichain
    address constant POOL_MANAGER = 0x1F98400000000000000000000000000000000004;
    address constant STETH = 0x51aE19065794D01886f97A93E7DC5967940f2894;
    address constant REBASING_POOL = 0x522C190f46256270177F9aC6AF296319f157c888;

    uint24 constant POOL_FEE = 3000;
    int24 constant TICK_SPACING = 60;

    function run() external {
        uint256 liquidityAmount = 0.01 ether; // Start with smaller amount

        console.log("=== Adding Liquidity to Unichain Pool ===");
        console.log("Liquidity amount:", liquidityAmount / 1e18, "ETH");

        vm.startBroadcast();

        // Create pool key
        PoolKey memory poolKey = PoolKey({
            currency0: Currency.wrap(address(0)),
            currency1: Currency.wrap(STETH),
            fee: POOL_FEE,
            tickSpacing: TICK_SPACING,
            hooks: IHooks(REBASING_POOL)
        });

        // Check balances
        uint256 ethBalance = msg.sender.balance;
        uint256 stethBalance = StETH(STETH).balanceOf(msg.sender);

        console.log("Current balances:");
        console.log("  ETH:", ethBalance / 1e18);
        console.log("  stETH:", stethBalance / 1e18);

        if (ethBalance < liquidityAmount) {
            console.log("❌ Insufficient ETH balance. Need at least", liquidityAmount / 1e18, "ETH");
            vm.stopBroadcast();
            return;
        }

        // Mint stETH if needed
        if (stethBalance < liquidityAmount) {
            console.log("Minting stETH...");
            StETH(STETH).mint(msg.sender, liquidityAmount);
            console.log("Minted", liquidityAmount / 1e18, "stETH");
        }

        // Approve stETH
        console.log("Approving stETH...");
        StETH(STETH).approve(REBASING_POOL, liquidityAmount);

        // Add liquidity
        console.log("Adding liquidity...");
        try RebasingParityPool(REBASING_POOL).addLiquidity{value: liquidityAmount}(
            poolKey,
            liquidityAmount
        ) returns (uint256 lpTokens) {
            console.log("✅ Liquidity added successfully!");
            console.log("   LP tokens received:", lpTokens);
            console.log("   ETH deposited:", liquidityAmount / 1e18);
            console.log("   stETH deposited:", liquidityAmount / 1e18);
        } catch Error(string memory reason) {
            console.log("❌ Failed to add liquidity:", reason);
        } catch {
            console.log("❌ Failed to add liquidity with unknown error");
        }

        vm.stopBroadcast();

        console.log("=== Complete ===");
    }
}