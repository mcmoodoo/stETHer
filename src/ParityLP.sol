// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {ERC20} from "solmate/src/tokens/ERC20.sol";

/// @title Parity LP Token
/// @notice ERC20 token representing liquidity provider shares in the parity pool
contract ParityLP is ERC20 {
    address public immutable hook;
    
    modifier onlyHook() {
        require(msg.sender == hook, "Only hook can mint/burn");
        _;
    }
    
    constructor(address _hook) ERC20("Parity LP", "PLP", 18) {
        hook = _hook;
    }
    
    /// @notice Mint LP tokens to liquidity provider
    /// @param to Address to mint tokens to
    /// @param amount Amount of LP tokens to mint
    function mint(address to, uint256 amount) external onlyHook {
        _mint(to, amount);
    }
    
    /// @notice Burn LP tokens from liquidity provider
    /// @param from Address to burn tokens from
    /// @param amount Amount of LP tokens to burn
    function burn(address from, uint256 amount) external onlyHook {
        _burn(from, amount);
    }
}