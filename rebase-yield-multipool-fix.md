# Rebase Yield Distribution Fix for Multiple Pools

## Problem
The current `_distributeRebaseYield` function assumes the hook is the only user of stETH in the PoolManager, which won't work in production when multiple pools share the same pool manager.

## Solution: Track Hook's Share via ERC6909

### Current Implementation (Single Pool)
```solidity
function _distributeRebaseYield(Currency stETHCurrency) private {
    // Assumes exclusive access to all stETH in pool manager
    uint256 actualStETHBalance = IERC20(Currency.unwrap(stETHCurrency)).balanceOf(address(poolManager));

    if (actualStETHBalance > lastKnownStETHBalance) {
        uint256 rebaseYield = actualStETHBalance - lastKnownStETHBalance;
        // ... distribute yield
    }
}
```

### Proposed Implementation (Multiple Pools)
```solidity
function _distributeRebaseYield(Currency stETHCurrency) private {
    if (Currency.unwrap(stETHCurrency) == address(0)) return; // Skip for ETH

    // Get this hook's specific stETH balance via ERC6909
    uint256 currentHookBalance = poolManager.balanceOf(address(this), stETHCurrency.toId());

    // Compare against the hook's tracked principal (non-rebased amount)
    if (currentHookBalance > poolStETHBalance) {
        uint256 rebaseYield = currentHookBalance - poolStETHBalance;

        // Distribute yield proportionally to LPs
        uint256 totalLPSupply = LP_TOKEN.totalSupply();

        if (totalLPSupply > 0) {
            feesPerLpToken1 += (rebaseYield * 1e18) / totalLPSupply;
            accumulatedFees1 += rebaseYield;
            poolStETHBalance = currentHookBalance; // Update to new balance including yield

            emit RebaseYieldDistributed(rebaseYield, block.timestamp);
        }
    }
}
```

## Key Changes Required

### 1. Remove `lastKnownStETHBalance` State Variable
- No longer needed since we track via `poolStETHBalance`
- Simplifies state management

### 2. Update `poolStETHBalance` Tracking
- **Current**: Tracks accounting balance (including fees)
- **New**: Tracks total balance including rebase yield
- Only modify on actual liquidity changes (add/remove)

### 3. Adjust Liquidity Functions

#### Add Liquidity
```solidity
function _addLiquidityCallback(...) internal returns (bytes memory) {
    // ... existing token transfer logic ...

    // Update pool balances (principal only, no rebase yield yet)
    poolETHBalance += amountPerToken;
    poolStETHBalance += amountPerToken;  // Just track the principal added

    // Remove this line:
    // lastKnownStETHBalance += amountPerToken;

    // ... rest of function ...
}
```

#### Remove Liquidity
```solidity
function _removeLiquidityCallback(...) internal returns (bytes memory) {
    // ... existing calculation logic ...

    // Update balances to reflect removed principal
    poolETHBalance -= (amount0 - fees0);

    // For stETH, need to account for rebase yield in the withdrawal
    // The actual amount removed might be higher due to accumulated yield
    poolStETHBalance = poolManager.balanceOf(address(this), currency1.toId());

    // Remove this line:
    // lastKnownStETHBalance -= (amount1 - fees1);

    // ... rest of function ...
}
```

## Benefits of This Approach

1. **Isolation**: Each hook's rebase yields are completely isolated from other pools
2. **Simplicity**: Uses existing ERC6909 infrastructure
3. **Gas Efficient**: No additional storage or complex calculations needed
4. **Accurate**: Correctly tracks each hook's share of rebasing yields
5. **Compatible**: Works seamlessly with Uniswap v4's architecture

## Testing Considerations

1. **Multi-Pool Test**: Deploy multiple hooks using stETH to verify isolation
2. **Rebase Simulation**: Test with simulated rebases affecting the pool manager's total stETH
3. **Concurrent Operations**: Ensure swaps/liquidity operations from different hooks don't interfere
4. **Edge Cases**: Test with zero liquidity, single LP, and maximum rebase scenarios

## Migration Path

1. Deploy new hook with updated rebase tracking
2. Migrate liquidity from old hook to new hook
3. Verify rebase yields are correctly distributed in multi-pool environment
4. Deprecate old single-pool implementation