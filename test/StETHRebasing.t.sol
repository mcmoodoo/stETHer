// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";
import "../src/StETH.sol";

contract StETHRebasingTest is Test {
    StETH stETH;
    address user1 = address(0x1);
    address user2 = address(0x2);
    
    function setUp() public {
        stETH = new StETH();
    }
    
    function test_initialState() public {
        assertEq(stETH.totalSupply(), 0);
        assertEq(stETH.getTotalShares(), 0);
        assertEq(stETH.name(), "Staked Ether");
        assertEq(stETH.symbol(), "stETH");
        assertEq(stETH.decimals(), 18);
    }
    
    function test_mintAndBalance() public {
        // Mint 100 stETH to user1
        stETH.mint(user1, 100 ether);
        
        assertEq(stETH.balanceOf(user1), 100 ether);
        assertEq(stETH.sharesOf(user1), 100 ether); // 1:1 initially
        assertEq(stETH.totalSupply(), 100 ether);
        assertEq(stETH.getTotalShares(), 100 ether);
    }
    
    function test_rebasing() public {
        // Mint tokens
        stETH.mint(user1, 100 ether);
        
        // Fast forward 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Trigger rebase
        uint256 yieldGenerated = stETH.rebase();
        
        // Should generate approximately 5% yield (5 ether)
        assertGt(yieldGenerated, 4.9 ether); // Allow for small rounding
        assertLt(yieldGenerated, 5.1 ether);
        
        // User balance should increase
        assertGt(stETH.balanceOf(user1), 104.9 ether);
        assertLt(stETH.balanceOf(user1), 105.1 ether);
        
        // Shares remain the same
        assertEq(stETH.sharesOf(user1), 100 ether);
    }
    
    function test_continuousRebasing() public {
        // Mint tokens
        stETH.mint(user1, 100 ether);
        
        uint256 initialBalance = stETH.balanceOf(user1);
        
        // Fast forward 30 days and rebase
        vm.warp(block.timestamp + 30 days);
        stETH.rebase();
        uint256 balanceAfter30Days = stETH.balanceOf(user1);
        
        // Fast forward another 30 days and rebase
        vm.warp(block.timestamp + 30 days);
        stETH.rebase();
        uint256 balanceAfter60Days = stETH.balanceOf(user1);
        
        // Balance should continuously increase
        assertGt(balanceAfter30Days, initialBalance);
        assertGt(balanceAfter60Days, balanceAfter30Days);
        
        console.log("Initial balance:", initialBalance);
        console.log("After 30 days:", balanceAfter30Days);
        console.log("After 60 days:", balanceAfter60Days);
    }
    
    function test_sharePreservationAfterRebase() public {
        // Mint to two users
        stETH.mint(user1, 60 ether);
        stETH.mint(user2, 40 ether);
        
        uint256 shares1 = stETH.sharesOf(user1);
        uint256 shares2 = stETH.sharesOf(user2);
        
        // Fast forward and rebase
        vm.warp(block.timestamp + 365 days);
        stETH.rebase();
        
        // Shares should remain unchanged
        assertEq(stETH.sharesOf(user1), shares1);
        assertEq(stETH.sharesOf(user2), shares2);
        
        // But balances should increase proportionally
        uint256 balance1 = stETH.balanceOf(user1);
        uint256 balance2 = stETH.balanceOf(user2);
        
        // User1 should have ~60% of total supply
        // User2 should have ~40% of total supply
        uint256 totalSupply = stETH.totalSupply();
        assertApproxEqRel(balance1, (totalSupply * 60) / 100, 0.01e18); // 1% tolerance
        assertApproxEqRel(balance2, (totalSupply * 40) / 100, 0.01e18); // 1% tolerance
    }
    
    function test_transferWithRebasing() public {
        // Mint tokens
        stETH.mint(user1, 100 ether);
        
        // Fast forward and rebase to increase balance
        vm.warp(block.timestamp + 365 days);
        stETH.rebase();
        
        uint256 balanceBeforeTransfer = stETH.balanceOf(user1);
        
        // Transfer some tokens
        vm.prank(user1);
        stETH.transfer(user2, 50 ether);
        
        // Check balances (with rounding tolerance for shares-based transfers)
        assertApproxEqAbs(stETH.balanceOf(user1), balanceBeforeTransfer - 50 ether, 1);
        assertApproxEqAbs(stETH.balanceOf(user2), 50 ether, 1);
        
        // Check that total supply is preserved (within 1 wei)
        assertApproxEqAbs(stETH.balanceOf(user1) + stETH.balanceOf(user2), balanceBeforeTransfer, 1);
    }
    
    function test_yieldCalculation() public {
        stETH.mint(user1, 1000 ether);
        
        // Test daily yield estimate
        uint256 estimatedDailyYield = stETH.getEstimatedDailyYield();
        
        // Expected: 1000 ether * 5% / 365 days ≈ 0.137 ether per day
        uint256 annualYield = 1000 ether * 5 / 100; // 50 ether per year
        uint256 expectedDailyYield = annualYield / 365; // ≈ 0.137 ether per day
        
        assertApproxEqRel(estimatedDailyYield, expectedDailyYield, 0.01e18); // 1% tolerance
    }
    
    function test_rebaseEvent() public {
        stETH.mint(user1, 100 ether);
        
        vm.warp(block.timestamp + 365 days);
        
        // Expect Rebase event with actual values
        vm.expectEmit(true, true, true, true);
        emit StETH.Rebase(105 ether, 5 ether, block.timestamp);
        
        stETH.rebase();
    }
    
    function test_getSharePrice() public {
        stETH.mint(user1, 100 ether);
        
        // Initially 1:1
        assertEq(stETH.getSharePrice(), 1e18);
        
        // After rebase, share price should increase
        vm.warp(block.timestamp + 365 days);
        stETH.rebase();
        
        assertGt(stETH.getSharePrice(), 1e18);
        assertLt(stETH.getSharePrice(), 1.1e18); // Should be around 1.05
    }
}