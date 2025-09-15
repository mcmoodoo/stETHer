// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {IHooks} from "v4-core/src/interfaces/IHooks.sol";
import {Hooks} from "v4-core/src/libraries/Hooks.sol";
import {PoolKey} from "v4-core/src/types/PoolKey.sol";
import {Currency, CurrencyLibrary} from "v4-core/src/types/Currency.sol";
import {ParityPool} from "../src/ParityPool.sol";
import {StETH} from "../src/StETH.sol";
import {Fixtures} from "./utils/Fixtures.sol";

contract ETHStETHSimpleTest is Test, Fixtures {
    using CurrencyLibrary for Currency;
    
    ParityPool hook;
    StETH stETH;
    
    function setUp() public {
        deployFreshManagerAndRouters();
        
        // Deploy stETH
        stETH = new StETH();
        stETH.mint(address(this), 10000e18);
        
        // Set up currencies with stETH and a regular token
        currency0 = Currency.wrap(address(stETH));
        deployMintAndApprove2Currencies(); // This will deploy currency1
        
        deployAndApprovePosm(manager);
        
        // Deploy the hook
        address flags = address(
            uint160(Hooks.BEFORE_SWAP_FLAG | Hooks.BEFORE_SWAP_RETURNS_DELTA_FLAG | Hooks.BEFORE_ADD_LIQUIDITY_FLAG)
                ^ (0x4447 << 144)
        );
        bytes memory constructorArgs = abi.encode(manager, address(0x999)); // treasury address
        deployCodeTo("ParityPool.sol:ParityPool", constructorArgs, flags);
        hook = ParityPool(flags);
        
        // Sort currencies
        if (Currency.unwrap(currency0) > Currency.unwrap(currency1)) {
            (currency0, currency1) = (currency1, currency0);
        }
        
        key = PoolKey(currency0, currency1, 3000, 60, IHooks(hook));
        manager.initialize(key, SQRT_PRICE_1_1);
    }
    
    function test_stETH_token_basics() public view {
        assertEq(stETH.name(), "Staked Ether");
        assertEq(stETH.symbol(), "stETH");
        assertEq(stETH.decimals(), 18);
    }
    
    function test_addLiquidity_with_stETH() public {
        uint256 amount = 1000e18;
        
        // Mint stETH to this contract if needed
        if (Currency.unwrap(currency0) == address(stETH)) {
            stETH.approve(address(hook), amount);
        } else {
            stETH.approve(address(hook), amount);
        }
        
        IERC20(Currency.unwrap(currency0)).approve(address(hook), amount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), amount);
        
        uint256 balance0Before = manager.balanceOf(address(hook), currency0.toId());
        uint256 balance1Before = manager.balanceOf(address(hook), currency1.toId());
        
        hook.addLiquidity(key, amount);
        
        assertEq(manager.balanceOf(address(hook), currency0.toId()) - balance0Before, amount);
        assertEq(manager.balanceOf(address(hook), currency1.toId()) - balance1Before, amount);
    }
    
    function test_swap_with_stETH() public {
        uint256 liquidityAmount = 5000e18;
        uint256 swapAmount = 100e18;
        
        // Add liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        // Perform swap
        uint256 balance0Before = currency0.balanceOfSelf();
        uint256 balance1Before = currency1.balanceOfSelf();
        
        swap(key, true, -int256(swapAmount), ZERO_BYTES);
        
        // ETH → stETH: 0% fee, 1:1 swap (assuming currency0 is ETH)
        assertEq(balance0Before - currency0.balanceOfSelf(), swapAmount);
        assertEq(currency1.balanceOfSelf() - balance1Before, swapAmount);
    }
    
    function test_multiple_swaps_with_stETH() public {
        uint256 liquidityAmount = 10000e18;
        
        // Add liquidity
        IERC20(Currency.unwrap(currency0)).approve(address(hook), liquidityAmount);
        IERC20(Currency.unwrap(currency1)).approve(address(hook), liquidityAmount);
        hook.addLiquidity(key, liquidityAmount);
        
        // Multiple swaps
        uint256[] memory amounts = new uint256[](3);
        amounts[0] = 50e18;
        amounts[1] = 100e18;
        amounts[2] = 75e18;
        
        for (uint256 i = 0; i < amounts.length; i++) {
            bool zeroForOne = (i % 2 == 0);
            
            uint256 balance0Before = currency0.balanceOfSelf();
            uint256 balance1Before = currency1.balanceOfSelf();
            
            swap(key, zeroForOne, -int256(amounts[i]), ZERO_BYTES);
            
            if (zeroForOne) {
                // ETH → stETH: 0% fee, 1:1 swap
                assertEq(balance0Before - currency0.balanceOfSelf(), amounts[i]);
                assertEq(currency1.balanceOfSelf() - balance1Before, amounts[i]);
            } else {
                // stETH → ETH: 0.1% fee applied
                uint256 expectedOutput = amounts[i] * 999 / 1000; // amounts[i] - 0.1% fee
                assertEq(balance1Before - currency1.balanceOfSelf(), amounts[i]);
                assertEq(currency0.balanceOfSelf() - balance0Before, expectedOutput);
            }
        }
    }
    
    function testFuzz_stETH_operations(uint256 mintAmount, uint256 transferAmount) public {
        mintAmount = bound(mintAmount, 1e18, 1000000e18);
        transferAmount = bound(transferAmount, 0, mintAmount);
        
        address alice = address(0x1234);
        
        uint256 initialBalance = stETH.balanceOf(alice);
        
        stETH.mint(alice, mintAmount);
        assertEq(stETH.balanceOf(alice), initialBalance + mintAmount);
        
        if (transferAmount > 0) {
            vm.prank(alice);
            stETH.transfer(address(this), transferAmount);
            assertEq(stETH.balanceOf(alice), initialBalance + mintAmount - transferAmount);
        }
    }
}