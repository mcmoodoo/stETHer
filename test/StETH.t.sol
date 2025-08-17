// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {StETH} from "../src/StETH.sol";

contract StETHTest is Test {
    StETH public stETH;
    address alice = address(0x1);
    address bob = address(0x2);

    function setUp() public {
        stETH = new StETH();
    }

    function test_constructor() public view {
        assertEq(stETH.name(), "Staked Ether");
        assertEq(stETH.symbol(), "stETH");
        assertEq(stETH.decimals(), 18);
    }

    function test_mint() public {
        uint256 amount = 1000 ether;
        stETH.mint(alice, amount);
        assertEq(stETH.balanceOf(alice), amount);
        assertEq(stETH.totalSupply(), amount);
    }

    function test_mint_multiple() public {
        uint256 amount1 = 1000 ether;
        uint256 amount2 = 500 ether;
        
        stETH.mint(alice, amount1);
        stETH.mint(bob, amount2);
        
        assertEq(stETH.balanceOf(alice), amount1);
        assertEq(stETH.balanceOf(bob), amount2);
        assertEq(stETH.totalSupply(), amount1 + amount2);
    }

    function test_burn() public {
        uint256 mintAmount = 1000 ether;
        uint256 burnAmount = 300 ether;
        
        stETH.mint(alice, mintAmount);
        stETH.burn(alice, burnAmount);
        
        assertEq(stETH.balanceOf(alice), mintAmount - burnAmount);
        assertEq(stETH.totalSupply(), mintAmount - burnAmount);
    }

    function test_burn_all() public {
        uint256 amount = 1000 ether;
        
        stETH.mint(alice, amount);
        stETH.burn(alice, amount);
        
        assertEq(stETH.balanceOf(alice), 0);
        assertEq(stETH.totalSupply(), 0);
    }

    function test_transfer() public {
        uint256 amount = 1000 ether;
        uint256 transferAmount = 300 ether;
        
        stETH.mint(alice, amount);
        
        vm.prank(alice);
        stETH.transfer(bob, transferAmount);
        
        assertEq(stETH.balanceOf(alice), amount - transferAmount);
        assertEq(stETH.balanceOf(bob), transferAmount);
        assertEq(stETH.totalSupply(), amount);
    }

    function test_approve_and_transferFrom() public {
        uint256 amount = 1000 ether;
        uint256 allowance = 500 ether;
        uint256 transferAmount = 300 ether;
        
        stETH.mint(alice, amount);
        
        vm.prank(alice);
        stETH.approve(bob, allowance);
        assertEq(stETH.allowance(alice, bob), allowance);
        
        vm.prank(bob);
        stETH.transferFrom(alice, bob, transferAmount);
        
        assertEq(stETH.balanceOf(alice), amount - transferAmount);
        assertEq(stETH.balanceOf(bob), transferAmount);
        assertEq(stETH.allowance(alice, bob), allowance - transferAmount);
    }

    function testFuzz_mint(address to, uint256 amount) public {
        vm.assume(to != address(0));
        vm.assume(amount > 0 && amount <= 1_000_000 ether); // Reasonable bounds
        
        stETH.mint(to, amount);
        assertEq(stETH.balanceOf(to), amount);
        assertEq(stETH.sharesOf(to), amount); // 1:1 initially
    }

    function testFuzz_burn(address from, uint256 mintAmount, uint256 burnAmount) public {
        vm.assume(from != address(0));
        vm.assume(mintAmount > 0 && mintAmount <= 1_000_000 ether); // Reasonable bounds
        vm.assume(burnAmount > 0 && burnAmount <= mintAmount);
        
        stETH.mint(from, mintAmount);
        stETH.burn(from, burnAmount);
        
        assertEq(stETH.balanceOf(from), mintAmount - burnAmount);
    }

    function testFuzz_transfer(address from, address to, uint256 amount, uint256 transferAmount) public {
        vm.assume(from != address(0) && to != address(0));
        vm.assume(from != to);
        vm.assume(amount > 0 && amount <= 1_000_000 ether); // Reasonable bounds
        vm.assume(transferAmount > 0 && transferAmount <= amount);
        
        stETH.mint(from, amount);
        
        vm.prank(from);
        stETH.transfer(to, transferAmount);
        
        // Allow for 1 wei rounding due to shares-based transfers
        assertApproxEqAbs(stETH.balanceOf(from), amount - transferAmount, 1);
        assertApproxEqAbs(stETH.balanceOf(to), transferAmount, 1);
    }
}