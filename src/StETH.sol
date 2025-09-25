// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title StETH - Rebasing Staked Ethereum Token
/// @notice A rebasing implementation of stETH with automatic yield generation at 5% APY
/// @dev Uses shares-based accounting to handle rebasing while maintaining ERC20 compatibility
contract StETH {
    string public constant NAME = "Staked Ether";
    string public constant SYMBOL = "stETH";
    uint8 public constant DECIMALS = 18;

    // ERC20 compatibility functions
    function name() public pure returns (string memory) {
        return NAME;
    }

    function symbol() public pure returns (string memory) {
        return SYMBOL;
    }

    function decimals() public pure returns (uint8) {
        return DECIMALS;
    }

    uint256 public totalSupply;
    mapping(address => mapping(address => uint256)) public allowance;
    uint256 public lastRebaseTime;
    uint256 public constant ANNUAL_YIELD_BPS = 500; // 5% = 500 basis points
    uint256 public constant SECONDS_PER_YEAR = 365 days;
    uint256 public constant BPS_DENOMINATOR = 10000;
    
    // Track total shares vs total supply for rebasing
    uint256 private _totalShares;
    mapping(address => uint256) private _shares;
    
    event Transfer(address indexed from, address indexed to, uint256 amount);
    event Approval(address indexed owner, address indexed spender, uint256 amount);
    event Rebase(uint256 newTotalSupply, uint256 yieldGenerated, uint256 timestamp);
    
    constructor() {
        lastRebaseTime = block.timestamp;
    }
    
    /// @notice Mint stETH tokens (maintains shares-based accounting)
    /// @dev Converts amount to shares based on current exchange rate
    function mint(address to, uint256 amount) external {
        require(amount > 0, "Cannot mint zero");
        
        // Auto-rebase before minting to ensure accurate conversion
        rebase();
        
        uint256 sharesToMint;
        if (_totalShares == 0) {
            // Initial mint: 1:1 ratio
            sharesToMint = amount;
        } else {
            // Calculate shares based on current ratio
            sharesToMint = (amount * _totalShares) / totalSupply;
        }
        
        _shares[to] += sharesToMint;
        _totalShares += sharesToMint;
        
        // Update total supply (ERC20)
        totalSupply += amount;
        
        emit Transfer(address(0), to, amount);
    }
    
    /// @notice Burn stETH tokens (maintains shares-based accounting)
    function burn(address from, uint256 amount) external {
        require(amount > 0, "Cannot burn zero");
        
        // Auto-rebase before burning
        rebase();
        
        // Convert amount to shares
        uint256 sharesToBurn = (amount * _totalShares) / totalSupply;
        
        require(_shares[from] >= sharesToBurn, "Insufficient balance");
        
        _shares[from] -= sharesToBurn;
        _totalShares -= sharesToBurn;
        totalSupply -= amount;
        
        emit Transfer(from, address(0), amount);
    }
    
    /// @notice Automatic rebase function - increases token balances based on 5% APY
    /// @return yieldGenerated Amount of new tokens created from yield
    function rebase() public returns (uint256 yieldGenerated) {
        uint256 timeSinceLastRebase = block.timestamp - lastRebaseTime;

        if (timeSinceLastRebase == 0) {
            return 0; // No time passed
        }

        uint256 currentSupply = totalSupply;
        if (currentSupply == 0) {
            lastRebaseTime = block.timestamp;
            return 0; // No tokens to rebase
        }

        // Calculate yield based on time elapsed and 5% APY
        // yield = principal × (rate/10000) × (timeElapsed/secondsPerYear)
        // Using higher precision to avoid rounding to 0
        uint256 numerator = currentSupply * ANNUAL_YIELD_BPS * timeSinceLastRebase;
        uint256 denominator = BPS_DENOMINATOR * SECONDS_PER_YEAR;
        yieldGenerated = numerator / denominator;

        // Always update lastRebaseTime to prevent stuck rebases
        lastRebaseTime = block.timestamp;

        if (yieldGenerated > 0) {
            // Increase total supply without changing shares
            // This effectively increases the value of each share
            totalSupply += yieldGenerated;

            emit Rebase(totalSupply, yieldGenerated, block.timestamp);
        }

        return yieldGenerated;
    }
    
    /// @notice Get the current balance of an account (shares × current exchange rate)
    function balanceOf(address account) public view returns (uint256) {
        if (_totalShares == 0) {
            return 0;
        }
        return (_shares[account] * totalSupply) / _totalShares;
    }
    
    /// @notice Get the shares owned by an account
    function sharesOf(address account) external view returns (uint256) {
        return _shares[account];
    }
    
    /// @notice Get total shares in existence
    function getTotalShares() external view returns (uint256) {
        return _totalShares;
    }
    
    /// @notice Get the current share price (tokens per share)
    function getSharePrice() external view returns (uint256) {
        if (_totalShares == 0) {
            return 1e18; // 1:1 initially
        }
        return (totalSupply * 1e18) / _totalShares;
    }
    
    /// @notice Transfer tokens using shares-based accounting
    function transfer(address to, uint256 amount) public returns (bool) {
        return transferFrom(msg.sender, to, amount);
    }
    
    /// @notice Transfer tokens from one account to another using shares-based accounting
    function transferFrom(address from, address to, uint256 amount) public returns (bool) {
        require(amount > 0, "Cannot transfer zero");
        
        // Convert amount to shares based on current exchange rate
        uint256 sharesToTransfer = (_totalShares == 0) ? amount : (amount * _totalShares) / totalSupply;
        
        // Handle allowance (if not self-transfer)
        if (from != msg.sender) {
            uint256 allowed = allowance[from][msg.sender];
            if (allowed != type(uint256).max) {
                require(allowed >= amount, "ERC20: transfer amount exceeds allowance");
                allowance[from][msg.sender] = allowed - amount;
            }
        }
        
        // Perform share transfer
        require(_shares[from] >= sharesToTransfer, "ERC20: transfer amount exceeds balance");
        _shares[from] -= sharesToTransfer;
        _shares[to] += sharesToTransfer;
        
        emit Transfer(from, to, amount);
        return true;
    }
    
    /// @notice Approve spender to transfer tokens on behalf of owner
    function approve(address spender, uint256 amount) public returns (bool) {
        allowance[msg.sender][spender] = amount;
        emit Approval(msg.sender, spender, amount);
        return true;
    }
    
    /// @notice Get balance with automatic rebase to ensure up-to-date yields
    function balanceOfWithRebase(address account) external returns (uint256) {
        rebase();
        return balanceOf(account);
    }
    
    /// @notice Get estimated daily yield based on current balance
    function getEstimatedDailyYield() external view returns (uint256) {
        if (totalSupply == 0) return 0;
        return (totalSupply * ANNUAL_YIELD_BPS) / (BPS_DENOMINATOR * 365);
    }
    
    /// @notice Force rebase to current time (useful for testing or if rebase hasn't been called)
    function syncTotalSupply() external {
        rebase();
    }
    
    /// @notice Get time until next meaningful rebase (for display purposes)
    function timeUntilNextRebase() external view returns (uint256) {
        // Return seconds until next hour (rebases are meaningful every hour or so)
        return 3600 - ((block.timestamp - lastRebaseTime) % 3600);
    }
}