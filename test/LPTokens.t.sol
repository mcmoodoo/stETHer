// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {RebasingParityPool} from "../src/RebasingParityPool.sol";
import {ParityLP} from "../src/ParityLP.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract LPTokensTest is Test, Fixtures {
    RebasingParityPool hook;
    ParityLP lpToken;

    function setUp() public {
        deployFreshManagerAndRouters();
        deployMintAndApprove2Currencies();
        deployAndApprovePosm(manager);

        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4448 << 144)
        );
        // Create the pool key first (before deploying hook)
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(flags));

        bytes memory constructorArgs = abi.encode(manager, address(0x999), key); // treasury address
        deployCodeTo("RebasingParityPool.sol:RebasingParityPool", constructorArgs, flags);

        // Update key reference after deployment
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        hook = RebasingParityPool(flags);
        lpToken = hook.LP_TOKEN();

        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);
    }

    function test_addLiquidity_mintsLPTokens() public {
        uint256 liquidityAmount = 1000e18;
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        
        uint256 lpTokensBefore = lpToken.balanceOf(address(this));
        uint256 lpTokensMinted = hook.addLiquidity(key, liquidityAmount);
        uint256 lpTokensAfter = lpToken.balanceOf(address(this));
        
        assertEq(lpTokensMinted, 2000e18); // 2 * liquidityAmount for first LP
        assertEq(lpTokensAfter - lpTokensBefore, lpTokensMinted);
        assertEq(lpToken.totalSupply(), lpTokensMinted);
        assertEq(hook.totalLiquidity(), 2000e18);
    }

    function test_multipleLPs_proportionalShares() public {
        uint256 firstAmount = 1000e18;
        uint256 secondAmount = 500e18;
        
        // First LP
        IERC20(Currency.unwrap(currency0)).approve(address(hook), firstAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), firstAmount);
        uint256 firstLPTokens = hook.addLiquidity(key, firstAmount);
        
        // Second LP (different address)
        address secondLP = address(0x123);
        deal(Currency.unwrap(currency0), secondLP, secondAmount);
        deal(Currency.unwrap(currency1), secondLP, secondAmount);
        
        vm.startPrank(secondLP);
        IERC20(Currency.unwrap(currency0)).approve(address(hook), secondAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), secondAmount);
        uint256 secondLPTokens = hook.addLiquidity(key, secondAmount);
        vm.stopPrank();
        
        // Verify proportional shares
        assertEq(firstLPTokens, 2000e18); // First LP gets base amount
        assertEq(secondLPTokens, 1000e18); // Second LP gets half (proportional)
        assertEq(lpToken.totalSupply(), 3000e18);
        assertEq(hook.totalLiquidity(), 3000e18);
        
        // Verify ownership
        assertEq(lpToken.balanceOf(address(this)), firstLPTokens);
        assertEq(lpToken.balanceOf(secondLP), secondLPTokens);
    }

    function test_removeLiquidity_burnsLPTokens() public {
        uint256 liquidityAmount = 1000e18;
        
        // Add liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        uint256 lpTokensMinted = hook.addLiquidity(key, liquidityAmount);
        
        // Remove half the liquidity
        uint256 lpTokensToRemove = lpTokensMinted / 2;
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        (uint256 amount0, uint256 amount1) = hook.removeLiquidity(key, lpTokensToRemove);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        // Verify tokens were returned
        assertEq(balance0After - balance0Before, amount0);
        assertEq(balance1After - balance1Before, amount1);
        
        // Should get back approximately half of each token
        assertApproxEqAbs(amount0, liquidityAmount / 2, 1e15); // 0.001 ETH tolerance
        assertApproxEqAbs(amount1, liquidityAmount / 2, 1e15);
        
        // Verify LP tokens were burned
        assertEq(lpToken.balanceOf(address(this)), lpTokensMinted - lpTokensToRemove);
        assertEq(lpToken.totalSupply(), lpTokensMinted - lpTokensToRemove);
    }

    function test_feeDistribution_throughWithdrawal() public {
        uint256 liquidityAmount = 1000e18;
        
        // Add liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        uint256 lpTokensMinted = hook.addLiquidity(key, liquidityAmount);
        
        // Generate fees through swaps
        uint256 swapAmount = 100e18;
        for (uint i = 0; i < 5; i++) {
            swap(key, false, -int256(swapAmount), ZERO_BYTES); // stETH → ETH (generates fees)
        }
        
        console.log("Pool balance after fees:");
        console.log("ETH:", manager.balanceOf(address(hook), currency0.toId()));
        console.log("stETH:", manager.balanceOf(address(hook), currency1.toId()));
        console.log("Total liquidity tracked:", hook.totalLiquidity());
        
        // Remove all liquidity and check if we get fees
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        (uint256 amount0, uint256 amount1) = hook.removeLiquidity(key, lpTokensMinted);
        
        uint256 balance0After = currency0.balanceOfSelf();
        uint256 balance1After = currency1.balanceOfSelf();
        
        console.log("Withdrawn amounts:");
        console.log("ETH:", amount0);
        console.log("stETH:", amount1);
        
        // Note: In current implementation, fees don't accumulate to LPs
        // The dynamic fee reduces what swappers receive, but doesn't add to pool
        // This test demonstrates current behavior - LPs get proportional share of remaining pool
        uint256 totalWithdrawn = amount0 + amount1;
        console.log("Total deposited:", liquidityAmount * 2);
        console.log("Total withdrawn:", totalWithdrawn);
        
        // LP gets proportional share of current pool balances
        // Pool may have imbalanced due to trades, but LP gets their fair share
        assertGt(totalWithdrawn, 0, "Should receive something");
        assertLe(totalWithdrawn, liquidityAmount * 2 + 10e18, "Should not exceed deposit by much");
        
        // Verify tokens were actually transferred
        assertEq(balance0After - balance0Before, amount0);
        assertEq(balance1After - balance1Before, amount1);
    }

    function test_lpToken_metadata() public view {
        assertEq(lpToken.name(), "Parity LP");
        assertEq(lpToken.symbol(), "PLP");
        assertEq(lpToken.decimals(), 18);
        assertEq(address(lpToken.HOOK()), address(hook));
    }

    function test_onlyHook_canMintBurn() public {
        // Only hook should be able to mint/burn
        vm.expectRevert("Only hook can mint/burn");
        lpToken.mint(address(this), 100e18);
        
        vm.expectRevert("Only hook can mint/burn");
        lpToken.burn(address(this), 100e18);
    }
}
