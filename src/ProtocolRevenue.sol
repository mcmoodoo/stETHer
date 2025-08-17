// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {IERC20} from "forge-std/interfaces/IERC20.sol";
import {Currency} from "v4-core/src/types/Currency.sol";
import {IPoolManager} from "v4-core/src/interfaces/IPoolManager.sol";

/// @title Protocol Revenue Management
/// @notice Handles protocol fee collection and distribution
contract ProtocolRevenue {
    address public immutable owner;
    address public treasury;
    
    /// @notice Protocol fee settings
    uint256 public constant MAX_PROTOCOL_FEE = 25; // Max 25% of total fees
    uint256 public protocolFeePercentage = 10; // 10% of fees to protocol
    uint256 public largeSwapThreshold = 1000e18; // Threshold for additional protocol fees
    uint256 public largeSwapProtocolFee = 500; // Additional 0.05% for large swaps
    
    /// @notice Accumulated protocol fees
    mapping(address => uint256) public protocolFees; // token -> amount
    
    /// @notice Events
    event ProtocolFeeCollected(address indexed token, uint256 amount);
    event ProtocolFeeWithdrawn(address indexed token, uint256 amount, address to);
    event FeeParametersUpdated(uint256 feePercentage, uint256 threshold, uint256 largeFee);
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }
    
    constructor(address _treasury) {
        owner = msg.sender;
        treasury = _treasury;
    }
    
    /// @notice Calculate protocol fee split
    function calculateProtocolFee(uint256 totalFee, uint256 swapAmount) 
        external view returns (uint256 protocolFee, uint256 lpFee) {
        
        // Base protocol fee percentage
        protocolFee = (totalFee * protocolFeePercentage) / 100;
        
        // Additional fee for large swaps
        if (swapAmount >= largeSwapThreshold) {
            uint256 additionalFee = (swapAmount * largeSwapProtocolFee) / 1_000_000;
            protocolFee += additionalFee;
        }
        
        // Ensure we don't exceed max protocol fee
        uint256 maxProtocolFee = (totalFee * MAX_PROTOCOL_FEE) / 100;
        if (protocolFee > maxProtocolFee) {
            protocolFee = maxProtocolFee;
        }
        
        lpFee = totalFee - protocolFee;
    }
    
    /// @notice Accumulate protocol fees
    function accumulateProtocolFee(address token, uint256 amount) external {
        protocolFees[token] += amount;
        emit ProtocolFeeCollected(token, amount);
    }
    
    /// @notice Withdraw accumulated protocol fees
    function withdrawProtocolFees(address token, uint256 amount) external onlyOwner {
        require(protocolFees[token] >= amount, "Insufficient protocol fees");
        
        protocolFees[token] -= amount;
        IERC20(token).transfer(treasury, amount);
        
        emit ProtocolFeeWithdrawn(token, amount, treasury);
    }
    
    /// @notice Update fee parameters
    function updateFeeParameters(
        uint256 _protocolFeePercentage,
        uint256 _largeSwapThreshold, 
        uint256 _largeSwapProtocolFee
    ) external onlyOwner {
        require(_protocolFeePercentage <= MAX_PROTOCOL_FEE, "Fee too high");
        
        protocolFeePercentage = _protocolFeePercentage;
        largeSwapThreshold = _largeSwapThreshold;
        largeSwapProtocolFee = _largeSwapProtocolFee;
        
        emit FeeParametersUpdated(_protocolFeePercentage, _largeSwapThreshold, _largeSwapProtocolFee);
    }
    
    /// @notice Update treasury address
    function updateTreasury(address _treasury) external onlyOwner {
        treasury = _treasury;
    }
    
    /// @notice Get total protocol fees for a token
    function getProtocolFees(address token) external view returns (uint256) {
        return protocolFees[token];
    }
    
    /// @notice Spend protocol fees for incentives (only callable by hook)
    function spendProtocolFeesForIncentive(address token, uint256 amount) external returns (bool) {
        if (protocolFees[token] >= amount) {
            protocolFees[token] -= amount;
            emit ProtocolFeeWithdrawn(token, amount, msg.sender);
            return true;
        }
        return false;
    }
}