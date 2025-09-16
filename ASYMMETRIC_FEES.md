# Asymmetric Fees Implementation

## Overview

The RebasingParityHook now implements **asymmetric fees** to incentivize rebalancing trades and discourage pool drainage. This creates economic pressure to maintain the pool's 1:1 ratio while still allowing free-market arbitrage.

## Fee Structure

### 🆓 **ETH → stETH Swaps: 0% Fee**
```
User pays: 1 ETH
User gets: 1 stETH  
Fee: 0%
```
**Incentive**: Encourages bringing ETH into the pool when it has excess stETH

### 💰 **stETH → ETH Swaps: 0.1% Fee**  
```
User pays: 1 stETH
User gets: ~0.999 ETH (after 0.1% fee)
Fee: 0.1%
```
**Deterrent**: Discourages taking ETH out of the pool

## Implementation Details

### Code Changes

```solidity
// In _beforeSwap function:
uint24 dynamicFee;
if (params.zeroForOne) {
    // ETH → stETH: 0% fee to incentivize bringing ETH in
    dynamicFee = 0;
} else {
    // stETH → ETH: 0.1% fee to discourage taking ETH out  
    dynamicFee = 1000; // 0.1% = 1000 / 1000000
}

return (BaseHook.beforeSwap.selector, returnDelta, dynamicFee);
```

### Fee Calculation
- Uniswap v4 uses basis points: `1000000 = 100%`
- `0.1% = 1000 / 1000000 = 1000 basis points`

## Economic Impact

### 🎯 **Rebalancing Incentives**

**When Pool Has Excess stETH** (common scenario):
- ✅ **ETH→stETH trades are FREE**: Arbitrageurs get rewarded for bringing ETH
- ❌ **stETH→ETH trades cost 0.1%**: Creates friction for draining ETH

**Result**: Natural economic pressure pushes pool toward balance

### 📊 **Arbitrage Economics**

**External Market**: 1 stETH = 1.05 ETH (5% yield)
**Your Pool**: 1:1 ratio + asymmetric fees

**Arbitrage Scenarios**:

1. **Buy stETH from Pool** (ETH→stETH):
   - Cost: 1 ETH → 1 stETH (0% fee)
   - Sell External: 1 stETH → 1.05 ETH  
   - **Profit: 0.05 ETH** ✅ (Free arbitrage!)

2. **Sell stETH to Pool** (stETH→ETH):
   - Buy External: 1.05 ETH → 1 stETH
   - Sell to Pool: 1 stETH → 0.999 ETH (after 0.1% fee)
   - **Loss: 0.051 ETH** ❌ (Unprofitable)

### 🔄 **Pool Dynamics**

**Steady State**:
- Pool slightly favors ETH→stETH trades
- stETH→ETH trades become expensive relative to external markets
- Pool maintains liquidity in both directions
- Arbitrageurs help rebalance by bringing ETH when profitable

## Benefits

### ✅ **For the Pool**
- **Better Balance**: Reduces extreme imbalances
- **Sustained Liquidity**: Both tokens remain available
- **Fee Revenue**: Generates income from stETH→ETH trades

### ✅ **For Liquidity Providers**  
- **Reduced Impermanent Loss**: Less dramatic pool composition changes
- **Fee Sharing**: Earn from the 0.1% fees on stETH→ETH trades
- **Stable Operations**: Pool remains functional longer

### ✅ **For Arbitrageurs**
- **Free Rebalancing**: No cost for beneficial ETH→stETH trades  
- **Clear Incentives**: Know exactly when arbitrage is profitable
- **Predictable Costs**: 0.1% fee is transparent and constant

## Trade-offs

### 📉 **Potential Downsides**

1. **Reduced stETH→ETH Volume**: 0.1% fee may deter some legitimate users
2. **Complexity**: No longer pure 1:1 for all trades
3. **Fee Sensitivity**: Users might seek alternatives for stETH→ETH swaps

### ⚖️ **Balance Considerations**

The 0.1% fee is intentionally modest:
- **Low enough**: Doesn't completely block stETH→ETH trades
- **High enough**: Creates meaningful friction for large arbitrage
- **Competitive**: Still better than many DEX fees (0.3%-1%)

## Usage Examples

### Example 1: Balanced Pool
```
Pool State: 100 ETH, 100 stETH
- ETH→stETH: 1 ETH → 1 stETH (0% fee)
- stETH→ETH: 1 stETH → 0.999 ETH (0.1% fee)
```

### Example 2: Imbalanced Pool  
```
Pool State: 50 ETH, 150 stETH (excess stETH)
- ETH→stETH: 1 ETH → 1 stETH (0% fee) ← INCENTIVIZED
- stETH→ETH: 1 stETH → 0.999 ETH (0.1% fee) ← DISCOURAGED
```

### Example 3: Fee Revenue
```
Daily Volume: 1000 stETH→ETH swaps
Fee Revenue: 1000 × 0.1% = 1 stETH per day
Distribution: Shared among liquidity providers
```

## Future Enhancements

### 🔮 **Potential Improvements**

1. **Dynamic Fee Rates**: Adjust based on pool imbalance ratio
2. **Time-Based Scaling**: Increase fees during extended imbalances  
3. **Volume Discounts**: Lower fees for large trades
4. **Governance**: Allow fee adjustment through voting

### 📊 **Advanced Strategies**

```solidity
// Example: Imbalance-based dynamic fees
uint256 imbalanceRatio = stethBalance * 100 / ethBalance;
if (imbalanceRatio > 120) {
    // Pool >20% imbalanced: increase stETH→ETH fee
    dynamicFee = 2000; // 0.2%
} else if (imbalanceRatio < 80) {
    // Pool <80% balanced: increase ETH→stETH fee  
    dynamicFee = params.zeroForOne ? 1000 : 0; // 0.1% vs 0%
}
```

---

This asymmetric fee structure creates a **self-balancing mechanism** that maintains pool health while preserving the core 1:1 exchange functionality. The small 0.1% fee provides just enough friction to prevent excessive drainage while keeping the pool competitive and useful for legitimate users.