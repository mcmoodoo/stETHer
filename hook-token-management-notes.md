# Hook Token Management in Uniswap v4

## When Hooks Need to Manage Tokens (Hold ERC6909 Balances)

### 1. Custom Liquidity Management
- When rejecting v4's native AMM liquidity
- Implementing alternative curves (1:1 parity, stableswap, etc.)
- Managing liquidity with custom LP tokens
- Example: RebasingParityHook implementing 1:1 ETH/stETH swaps

### 2. Order-Based Systems
- **Limit Orders**: Hold tokens until price targets are hit
- **TWAMM (Time-Weighted AMM)**: Hold tokens for gradual time-weighted swaps
- **RFQ (Request for Quote)**: Hold tokens for off-chain negotiated trades

### 3. Vault-Style Strategies
- **Yield Aggregators**: Hold tokens to deploy to external protocols
- **Rebalancing Vaults**: Hold tokens between rebalancing operations
- **Options/Derivatives**: Hold collateral for options contracts

### 4. Fee Collection & Distribution
- Collecting fees over time before distribution
- Holding protocol fees for later withdrawal
- Managing rebasing token yields (like stETH rebases)
- Implementing fee sharing mechanisms

### 5. Liquidity Incentives
- Holding reward tokens for LP incentives
- Managing liquidity mining programs
- Vesting schedules for liquidity providers
- Distributing incentives based on liquidity provision time

## When Hooks DON'T Need Token Management

- **Simple fee hooks**: Just modify fee tiers dynamically
- **Oracle hooks**: Just provide price feeds
- **Access control hooks**: Just restrict who can trade
- **Analytics hooks**: Just emit events for tracking
- **Validation hooks**: Just validate swap parameters

## Architecture Overview

```
Users → Hook Contract → ERC6909 Balances → Pool Manager (holds actual tokens)
         ↓
      Custom Logic
      (LP Tokens, Orders, Vaults, etc.)
```

## Key Design Principles

1. **Security**: Pool manager holds actual ERC20 tokens, hooks only hold ERC6909 claims
2. **Isolation**: Each hook's balances are isolated from other hooks
3. **Atomicity**: ERC6909 minting/burning happens atomically with swaps
4. **Flexibility**: Hooks can implement any token management logic while maintaining security

## The Pattern

**If a hook needs to custody tokens beyond a single atomic transaction**, it needs ERC6909 balance management.

This ensures:
- Tokens remain safely in the pool manager
- Hook controls the logic without holding actual tokens
- Protection against malicious hooks draining funds
- Consistent accounting across all hooks

## Standard Practice

It's absolutely correct and standard for hooks to hold ERC6909 balances when they need to:
- Provide custom liquidity
- Execute multi-step operations
- Distribute tokens over time
- Implement complex trading strategies

This is a core design pattern in Uniswap v4 that enables hooks to be both powerful and secure.