# 2-Minute Demo Voiceover Script

## Opening (0:00 - 0:15)

"Hi, I'm going to show you a Uniswap v4 pool that supports rebasing yield-bearking tokens via hooks. No need to wrap the rebasing token to use it."

## Problem Statement (0:15 - 0:30)

Regular constant product AMM is not a good choice here, because for assets like ETH and stETH that should trade near 1:1, this doesn't make sense. Why should you lose 2% to slippage when swapping correlated assets?"

## Core Innovation (0:30 - 0:50)

"So I built this using x plus y equals k instead. Let me show you the core hook implementation... Here's the parity logic that enables perfect 1:1 swaps when the pool is balanced. No bonding curve, no slippage - just direct swaps at fair prices."

_[Show RebasingParityHook.sol, point to parity math]_

## Dynamic Fee System (0:50 - 1:10)

"But here's where it gets interesting - I implemented dynamic fees that respond to pool imbalance. Look at this fee calculation... As the pool gets unbalanced, fees increase from 0.1% up to 5%. This naturally discourages the trades that would drain the pool while generating revenue."

_[Show dynamic fee tiers in code]_

## Self-Balancing Economics (1:10 - 1:30)

"And here's the clever part - those fees don't just disappear. They fund incentives for rebalancing trades. So when someone drains ETH from the pool, the higher fees generate protocol revenue that I use to pay bonuses for ETH deposits. The pool literally balances itself."

_[Show revenue management and incentive logic]_

## Rebasing Token Support (1:30 - 1:45)

"I also solved the rebasing token problem. Traditional AMMs break with stETH because the balances change over time. My shares-based accounting preserves the underlying 5% staking yield for liquidity providers - something no other AMM does properly."

_[Show StETH.sol rebasing mechanism]_

## Test Coverage (1:45 - 1:55)

"The system has comprehensive test coverage - 74 tests covering everything from basic swaps to complex multi-LP fee distribution scenarios. Every edge case is handled."

_[Show test results: make test output]_

## Closing (1:55 - 2:00)

"This creates the first truly efficient trading venue for correlated assets - zero slippage, no impermanent loss, preserved yield, and completely sustainable economics. Thanks for watching!"

---

## Speaker Notes:

- **Pace**: Aim for about 150-160 words per minute
- **Tone**: Confident but not arrogant, technical but accessible
- **Visual Cues**: Time code indicates when to show specific code sections
- **Emphasis**: Stress the economic innovation and self-balancing nature
- **Key Terms**: Parity pool, dynamic fees, rebasing tokens, self-balancing
