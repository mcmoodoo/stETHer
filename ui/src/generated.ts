import {
  createUseReadContract,
  createUseWriteContract,
  createUseSimulateContract,
  createUseWatchContractEvent,
} from 'wagmi/codegen'

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ParityLP
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const parityLpAbi = [
  {
    type: 'constructor',
    inputs: [{ name: '_hook', internalType: 'address', type: 'address' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'DOMAIN_SEPARATOR',
    outputs: [{ name: '', internalType: 'bytes32', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'HOOK',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: '', internalType: 'address', type: 'address' },
      { name: '', internalType: 'address', type: 'address' },
    ],
    name: 'allowance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'approve',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'balanceOf',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'burn',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'decimals',
    outputs: [{ name: '', internalType: 'uint8', type: 'uint8' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'mint',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'name',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'nonces',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'owner', internalType: 'address', type: 'address' },
      { name: 'spender', internalType: 'address', type: 'address' },
      { name: 'value', internalType: 'uint256', type: 'uint256' },
      { name: 'deadline', internalType: 'uint256', type: 'uint256' },
      { name: 'v', internalType: 'uint8', type: 'uint8' },
      { name: 'r', internalType: 'bytes32', type: 'bytes32' },
      { name: 's', internalType: 'bytes32', type: 'bytes32' },
    ],
    name: 'permit',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'symbol',
    outputs: [{ name: '', internalType: 'string', type: 'string' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalSupply',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'transfer',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'from', internalType: 'address', type: 'address' },
      { name: 'to', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'transferFrom',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'owner',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'spender',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'Approval',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      { name: 'from', internalType: 'address', type: 'address', indexed: true },
      { name: 'to', internalType: 'address', type: 'address', indexed: true },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'Transfer',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// ProtocolRevenue
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const protocolRevenueAbi = [
  {
    type: 'constructor',
    inputs: [{ name: '_treasury', internalType: 'address', type: 'address' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'MAX_PROTOCOL_FEE',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'OWNER',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'accumulateProtocolFee',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'totalFee', internalType: 'uint256', type: 'uint256' },
      { name: 'swapAmount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'calculateProtocolFee',
    outputs: [
      { name: 'protocolFee', internalType: 'uint256', type: 'uint256' },
      { name: 'lpFee', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'getProtocolFees',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'largeSwapProtocolFee',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'largeSwapThreshold',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'protocolFeePercentage',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'protocolFees',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'spendProtocolFeesForIncentive',
    outputs: [{ name: '', internalType: 'bool', type: 'bool' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'treasury',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      {
        name: '_protocolFeePercentage',
        internalType: 'uint256',
        type: 'uint256',
      },
      { name: '_largeSwapThreshold', internalType: 'uint256', type: 'uint256' },
      {
        name: '_largeSwapProtocolFee',
        internalType: 'uint256',
        type: 'uint256',
      },
    ],
    name: 'updateFeeParameters',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '_treasury', internalType: 'address', type: 'address' }],
    name: 'updateTreasury',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'token', internalType: 'address', type: 'address' },
      { name: 'amount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'withdrawProtocolFees',
    outputs: [],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'feePercentage',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'threshold',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'largeFee',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'FeeParametersUpdated',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'ProtocolFeeCollected',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'token',
        internalType: 'address',
        type: 'address',
        indexed: true,
      },
      {
        name: 'amount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      { name: 'to', internalType: 'address', type: 'address', indexed: false },
    ],
    name: 'ProtocolFeeWithdrawn',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// RebasingParityPool
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

export const rebasingParityPoolAbi = [
  {
    type: 'constructor',
    inputs: [
      {
        name: 'poolManager_',
        internalType: 'contract IPoolManager',
        type: 'address',
      },
      { name: 'treasury', internalType: 'address', type: 'address' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'LP_TOKEN',
    outputs: [{ name: '', internalType: 'contract ParityLP', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'PROTOCOL_REVENUE',
    outputs: [
      { name: '', internalType: 'contract ProtocolRevenue', type: 'address' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'accumulatedFees0',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'accumulatedFees1',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      { name: 'amountPerToken', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'addLiquidity',
    outputs: [{ name: 'lpTokens', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'payable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      {
        name: 'params',
        internalType: 'struct IPoolManager.ModifyLiquidityParams',
        type: 'tuple',
        components: [
          { name: 'tickLower', internalType: 'int24', type: 'int24' },
          { name: 'tickUpper', internalType: 'int24', type: 'int24' },
          { name: 'liquidityDelta', internalType: 'int256', type: 'int256' },
          { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
        ],
      },
      { name: 'delta', internalType: 'BalanceDelta', type: 'int256' },
      { name: 'feesAccrued', internalType: 'BalanceDelta', type: 'int256' },
      { name: 'hookData', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'afterAddLiquidity',
    outputs: [
      { name: '', internalType: 'bytes4', type: 'bytes4' },
      { name: '', internalType: 'BalanceDelta', type: 'int256' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' },
      { name: 'hookData', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'afterDonate',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      { name: 'sqrtPriceX96', internalType: 'uint160', type: 'uint160' },
      { name: 'tick', internalType: 'int24', type: 'int24' },
    ],
    name: 'afterInitialize',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      {
        name: 'params',
        internalType: 'struct IPoolManager.ModifyLiquidityParams',
        type: 'tuple',
        components: [
          { name: 'tickLower', internalType: 'int24', type: 'int24' },
          { name: 'tickUpper', internalType: 'int24', type: 'int24' },
          { name: 'liquidityDelta', internalType: 'int256', type: 'int256' },
          { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
        ],
      },
      { name: 'delta', internalType: 'BalanceDelta', type: 'int256' },
      { name: 'feesAccrued', internalType: 'BalanceDelta', type: 'int256' },
      { name: 'hookData', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'afterRemoveLiquidity',
    outputs: [
      { name: '', internalType: 'bytes4', type: 'bytes4' },
      { name: '', internalType: 'BalanceDelta', type: 'int256' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      {
        name: 'params',
        internalType: 'struct IPoolManager.SwapParams',
        type: 'tuple',
        components: [
          { name: 'zeroForOne', internalType: 'bool', type: 'bool' },
          { name: 'amountSpecified', internalType: 'int256', type: 'int256' },
          {
            name: 'sqrtPriceLimitX96',
            internalType: 'uint160',
            type: 'uint160',
          },
        ],
      },
      { name: 'delta', internalType: 'BalanceDelta', type: 'int256' },
      { name: 'hookData', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'afterSwap',
    outputs: [
      { name: '', internalType: 'bytes4', type: 'bytes4' },
      { name: '', internalType: 'int128', type: 'int128' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'allowedPoolId',
    outputs: [{ name: '', internalType: 'PoolId', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      {
        name: 'params',
        internalType: 'struct IPoolManager.ModifyLiquidityParams',
        type: 'tuple',
        components: [
          { name: 'tickLower', internalType: 'int24', type: 'int24' },
          { name: 'tickUpper', internalType: 'int24', type: 'int24' },
          { name: 'liquidityDelta', internalType: 'int256', type: 'int256' },
          { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
        ],
      },
      { name: 'hookData', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'beforeAddLiquidity',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' },
      { name: 'hookData', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'beforeDonate',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      { name: 'sqrtPriceX96', internalType: 'uint160', type: 'uint160' },
    ],
    name: 'beforeInitialize',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      {
        name: 'params',
        internalType: 'struct IPoolManager.ModifyLiquidityParams',
        type: 'tuple',
        components: [
          { name: 'tickLower', internalType: 'int24', type: 'int24' },
          { name: 'tickUpper', internalType: 'int24', type: 'int24' },
          { name: 'liquidityDelta', internalType: 'int256', type: 'int256' },
          { name: 'salt', internalType: 'bytes32', type: 'bytes32' },
        ],
      },
      { name: 'hookData', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'beforeRemoveLiquidity',
    outputs: [{ name: '', internalType: 'bytes4', type: 'bytes4' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      { name: 'sender', internalType: 'address', type: 'address' },
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      {
        name: 'params',
        internalType: 'struct IPoolManager.SwapParams',
        type: 'tuple',
        components: [
          { name: 'zeroForOne', internalType: 'bool', type: 'bool' },
          { name: 'amountSpecified', internalType: 'int256', type: 'int256' },
          {
            name: 'sqrtPriceLimitX96',
            internalType: 'uint160',
            type: 'uint160',
          },
        ],
      },
      { name: 'hookData', internalType: 'bytes', type: 'bytes' },
    ],
    name: 'beforeSwap',
    outputs: [
      { name: '', internalType: 'bytes4', type: 'bytes4' },
      { name: '', internalType: 'BeforeSwapDelta', type: 'int256' },
      { name: '', internalType: 'uint24', type: 'uint24' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
    ],
    name: 'claimFees',
    outputs: [
      { name: 'fees0', internalType: 'uint256', type: 'uint256' },
      { name: 'fees1', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'claimedFeesPerLpToken0',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: '', internalType: 'address', type: 'address' }],
    name: 'claimedFeesPerLpToken1',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'feesPerLpToken0',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'feesPerLpToken1',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getAllowedPoolId',
    outputs: [{ name: '', internalType: 'PoolId', type: 'bytes32' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getHookPermissions',
    outputs: [
      {
        name: '',
        internalType: 'struct Hooks.Permissions',
        type: 'tuple',
        components: [
          { name: 'beforeInitialize', internalType: 'bool', type: 'bool' },
          { name: 'afterInitialize', internalType: 'bool', type: 'bool' },
          { name: 'beforeAddLiquidity', internalType: 'bool', type: 'bool' },
          { name: 'afterAddLiquidity', internalType: 'bool', type: 'bool' },
          { name: 'beforeRemoveLiquidity', internalType: 'bool', type: 'bool' },
          { name: 'afterRemoveLiquidity', internalType: 'bool', type: 'bool' },
          { name: 'beforeSwap', internalType: 'bool', type: 'bool' },
          { name: 'afterSwap', internalType: 'bool', type: 'bool' },
          { name: 'beforeDonate', internalType: 'bool', type: 'bool' },
          { name: 'afterDonate', internalType: 'bool', type: 'bool' },
          { name: 'beforeSwapReturnDelta', internalType: 'bool', type: 'bool' },
          { name: 'afterSwapReturnDelta', internalType: 'bool', type: 'bool' },
          {
            name: 'afterAddLiquidityReturnDelta',
            internalType: 'bool',
            type: 'bool',
          },
          {
            name: 'afterRemoveLiquidityReturnDelta',
            internalType: 'bool',
            type: 'bool',
          },
        ],
      },
    ],
    stateMutability: 'pure',
  },
  {
    type: 'function',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'getProtocolFees',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getProtocolRevenue',
    outputs: [{ name: '', internalType: 'address', type: 'address' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'getTotalAccumulatedFees',
    outputs: [
      { name: 'fees0', internalType: 'uint256', type: 'uint256' },
      { name: 'fees1', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'lp', internalType: 'address', type: 'address' }],
    name: 'pendingFees',
    outputs: [
      { name: 'fees0', internalType: 'uint256', type: 'uint256' },
      { name: 'fees1', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'poolETHBalance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'poolManager',
    outputs: [
      { name: '', internalType: 'contract IPoolManager', type: 'address' },
    ],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'poolStETHBalance',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [],
    name: 'poolStETHPrincipal',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [
      {
        name: 'key',
        internalType: 'struct PoolKey',
        type: 'tuple',
        components: [
          { name: 'currency0', internalType: 'Currency', type: 'address' },
          { name: 'currency1', internalType: 'Currency', type: 'address' },
          { name: 'fee', internalType: 'uint24', type: 'uint24' },
          { name: 'tickSpacing', internalType: 'int24', type: 'int24' },
          { name: 'hooks', internalType: 'contract IHooks', type: 'address' },
        ],
      },
      { name: 'lpTokenAmount', internalType: 'uint256', type: 'uint256' },
    ],
    name: 'removeLiquidity',
    outputs: [
      { name: 'amount0', internalType: 'uint256', type: 'uint256' },
      { name: 'amount1', internalType: 'uint256', type: 'uint256' },
    ],
    stateMutability: 'nonpayable',
  },
  {
    type: 'function',
    inputs: [],
    name: 'totalLiquidity',
    outputs: [{ name: '', internalType: 'uint256', type: 'uint256' }],
    stateMutability: 'view',
  },
  {
    type: 'function',
    inputs: [{ name: 'data', internalType: 'bytes', type: 'bytes' }],
    name: 'unlockCallback',
    outputs: [{ name: '', internalType: 'bytes', type: 'bytes' }],
    stateMutability: 'nonpayable',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'ethBalance',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'stethBalance',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'PoolBalancesUpdated',
  },
  {
    type: 'event',
    anonymous: false,
    inputs: [
      {
        name: 'yieldAmount',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
      {
        name: 'timestamp',
        internalType: 'uint256',
        type: 'uint256',
        indexed: false,
      },
    ],
    name: 'RebaseYieldDistributed',
  },
  { type: 'error', inputs: [], name: 'HookNotCalledByPoolManager' },
  { type: 'error', inputs: [], name: 'HookNotImplemented' },
  { type: 'error', inputs: [], name: 'NotPoolManager' },
  {
    type: 'error',
    inputs: [{ name: 'token', internalType: 'address', type: 'address' }],
    name: 'SafeERC20FailedOperation',
  },
] as const

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
// React
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__
 */
export const readParityLpFunction = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"DOMAIN_SEPARATOR"`
 */
export const readParityLpDomainSeparator = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'DOMAIN_SEPARATOR',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"HOOK"`
 */
export const readParityLpHook = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'HOOK',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"allowance"`
 */
export const readParityLpAllowance = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'allowance',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"balanceOf"`
 */
export const readParityLpBalanceOf = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'balanceOf',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"decimals"`
 */
export const readParityLpDecimals = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'decimals',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"name"`
 */
export const readParityLpName = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'name',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"nonces"`
 */
export const readParityLpNonces = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'nonces',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"symbol"`
 */
export const readParityLpSymbol = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'symbol',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"totalSupply"`
 */
export const readParityLpTotalSupply = /*#__PURE__*/ createUseReadContract({
  abi: parityLpAbi,
  functionName: 'totalSupply',
})

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link parityLpAbi}__
 */
export const writeParityLpFunction = /*#__PURE__*/ createUseWriteContract({
  abi: parityLpAbi,
})

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"approve"`
 */
export const writeParityLpApprove = /*#__PURE__*/ createUseWriteContract({
  abi: parityLpAbi,
  functionName: 'approve',
})

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"burn"`
 */
export const writeParityLpBurn = /*#__PURE__*/ createUseWriteContract({
  abi: parityLpAbi,
  functionName: 'burn',
})

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"mint"`
 */
export const writeParityLpMint = /*#__PURE__*/ createUseWriteContract({
  abi: parityLpAbi,
  functionName: 'mint',
})

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"permit"`
 */
export const writeParityLpPermit = /*#__PURE__*/ createUseWriteContract({
  abi: parityLpAbi,
  functionName: 'permit',
})

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"transfer"`
 */
export const writeParityLpTransfer = /*#__PURE__*/ createUseWriteContract({
  abi: parityLpAbi,
  functionName: 'transfer',
})

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"transferFrom"`
 */
export const writeParityLpTransferFrom = /*#__PURE__*/ createUseWriteContract({
  abi: parityLpAbi,
  functionName: 'transferFrom',
})

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link parityLpAbi}__
 */
export const simulateParityLpFunction = /*#__PURE__*/ createUseSimulateContract(
  { abi: parityLpAbi },
)

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"approve"`
 */
export const simulateParityLpApprove = /*#__PURE__*/ createUseSimulateContract({
  abi: parityLpAbi,
  functionName: 'approve',
})

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"burn"`
 */
export const simulateParityLpBurn = /*#__PURE__*/ createUseSimulateContract({
  abi: parityLpAbi,
  functionName: 'burn',
})

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"mint"`
 */
export const simulateParityLpMint = /*#__PURE__*/ createUseSimulateContract({
  abi: parityLpAbi,
  functionName: 'mint',
})

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"permit"`
 */
export const simulateParityLpPermit = /*#__PURE__*/ createUseSimulateContract({
  abi: parityLpAbi,
  functionName: 'permit',
})

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"transfer"`
 */
export const simulateParityLpTransfer = /*#__PURE__*/ createUseSimulateContract(
  { abi: parityLpAbi, functionName: 'transfer' },
)

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link parityLpAbi}__ and `functionName` set to `"transferFrom"`
 */
export const simulateParityLpTransferFrom =
  /*#__PURE__*/ createUseSimulateContract({
    abi: parityLpAbi,
    functionName: 'transferFrom',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link parityLpAbi}__
 */
export const watchParityLpFunction = /*#__PURE__*/ createUseWatchContractEvent({
  abi: parityLpAbi,
})

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link parityLpAbi}__ and `eventName` set to `"Approval"`
 */
export const watchParityLpApproval = /*#__PURE__*/ createUseWatchContractEvent({
  abi: parityLpAbi,
  eventName: 'Approval',
})

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link parityLpAbi}__ and `eventName` set to `"Transfer"`
 */
export const watchParityLpTransfer = /*#__PURE__*/ createUseWatchContractEvent({
  abi: parityLpAbi,
  eventName: 'Transfer',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__
 */
export const readProtocolRevenueFunction = /*#__PURE__*/ createUseReadContract({
  abi: protocolRevenueAbi,
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"MAX_PROTOCOL_FEE"`
 */
export const readProtocolRevenueMaxProtocolFee =
  /*#__PURE__*/ createUseReadContract({
    abi: protocolRevenueAbi,
    functionName: 'MAX_PROTOCOL_FEE',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"OWNER"`
 */
export const readProtocolRevenueOwner = /*#__PURE__*/ createUseReadContract({
  abi: protocolRevenueAbi,
  functionName: 'OWNER',
})

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"calculateProtocolFee"`
 */
export const readProtocolRevenueCalculateProtocolFee =
  /*#__PURE__*/ createUseReadContract({
    abi: protocolRevenueAbi,
    functionName: 'calculateProtocolFee',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"getProtocolFees"`
 */
export const readProtocolRevenueGetProtocolFees =
  /*#__PURE__*/ createUseReadContract({
    abi: protocolRevenueAbi,
    functionName: 'getProtocolFees',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"largeSwapProtocolFee"`
 */
export const readProtocolRevenueLargeSwapProtocolFee =
  /*#__PURE__*/ createUseReadContract({
    abi: protocolRevenueAbi,
    functionName: 'largeSwapProtocolFee',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"largeSwapThreshold"`
 */
export const readProtocolRevenueLargeSwapThreshold =
  /*#__PURE__*/ createUseReadContract({
    abi: protocolRevenueAbi,
    functionName: 'largeSwapThreshold',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"protocolFeePercentage"`
 */
export const readProtocolRevenueProtocolFeePercentage =
  /*#__PURE__*/ createUseReadContract({
    abi: protocolRevenueAbi,
    functionName: 'protocolFeePercentage',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"protocolFees"`
 */
export const readProtocolRevenueProtocolFees =
  /*#__PURE__*/ createUseReadContract({
    abi: protocolRevenueAbi,
    functionName: 'protocolFees',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"treasury"`
 */
export const readProtocolRevenueTreasury = /*#__PURE__*/ createUseReadContract({
  abi: protocolRevenueAbi,
  functionName: 'treasury',
})

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link protocolRevenueAbi}__
 */
export const writeProtocolRevenueFunction =
  /*#__PURE__*/ createUseWriteContract({ abi: protocolRevenueAbi })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"accumulateProtocolFee"`
 */
export const writeProtocolRevenueAccumulateProtocolFee =
  /*#__PURE__*/ createUseWriteContract({
    abi: protocolRevenueAbi,
    functionName: 'accumulateProtocolFee',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"spendProtocolFeesForIncentive"`
 */
export const writeProtocolRevenueSpendProtocolFeesForIncentive =
  /*#__PURE__*/ createUseWriteContract({
    abi: protocolRevenueAbi,
    functionName: 'spendProtocolFeesForIncentive',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"updateFeeParameters"`
 */
export const writeProtocolRevenueUpdateFeeParameters =
  /*#__PURE__*/ createUseWriteContract({
    abi: protocolRevenueAbi,
    functionName: 'updateFeeParameters',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"updateTreasury"`
 */
export const writeProtocolRevenueUpdateTreasury =
  /*#__PURE__*/ createUseWriteContract({
    abi: protocolRevenueAbi,
    functionName: 'updateTreasury',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"withdrawProtocolFees"`
 */
export const writeProtocolRevenueWithdrawProtocolFees =
  /*#__PURE__*/ createUseWriteContract({
    abi: protocolRevenueAbi,
    functionName: 'withdrawProtocolFees',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link protocolRevenueAbi}__
 */
export const simulateProtocolRevenueFunction =
  /*#__PURE__*/ createUseSimulateContract({ abi: protocolRevenueAbi })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"accumulateProtocolFee"`
 */
export const simulateProtocolRevenueAccumulateProtocolFee =
  /*#__PURE__*/ createUseSimulateContract({
    abi: protocolRevenueAbi,
    functionName: 'accumulateProtocolFee',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"spendProtocolFeesForIncentive"`
 */
export const simulateProtocolRevenueSpendProtocolFeesForIncentive =
  /*#__PURE__*/ createUseSimulateContract({
    abi: protocolRevenueAbi,
    functionName: 'spendProtocolFeesForIncentive',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"updateFeeParameters"`
 */
export const simulateProtocolRevenueUpdateFeeParameters =
  /*#__PURE__*/ createUseSimulateContract({
    abi: protocolRevenueAbi,
    functionName: 'updateFeeParameters',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"updateTreasury"`
 */
export const simulateProtocolRevenueUpdateTreasury =
  /*#__PURE__*/ createUseSimulateContract({
    abi: protocolRevenueAbi,
    functionName: 'updateTreasury',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link protocolRevenueAbi}__ and `functionName` set to `"withdrawProtocolFees"`
 */
export const simulateProtocolRevenueWithdrawProtocolFees =
  /*#__PURE__*/ createUseSimulateContract({
    abi: protocolRevenueAbi,
    functionName: 'withdrawProtocolFees',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link protocolRevenueAbi}__
 */
export const watchProtocolRevenueFunction =
  /*#__PURE__*/ createUseWatchContractEvent({ abi: protocolRevenueAbi })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link protocolRevenueAbi}__ and `eventName` set to `"FeeParametersUpdated"`
 */
export const watchProtocolRevenueFeeParametersUpdated =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: protocolRevenueAbi,
    eventName: 'FeeParametersUpdated',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link protocolRevenueAbi}__ and `eventName` set to `"ProtocolFeeCollected"`
 */
export const watchProtocolRevenueProtocolFeeCollected =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: protocolRevenueAbi,
    eventName: 'ProtocolFeeCollected',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link protocolRevenueAbi}__ and `eventName` set to `"ProtocolFeeWithdrawn"`
 */
export const watchProtocolRevenueProtocolFeeWithdrawn =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: protocolRevenueAbi,
    eventName: 'ProtocolFeeWithdrawn',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__
 */
export const readRebasingParityPoolFunction =
  /*#__PURE__*/ createUseReadContract({ abi: rebasingParityPoolAbi })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"LP_TOKEN"`
 */
export const readRebasingParityPoolLpToken =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'LP_TOKEN',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"PROTOCOL_REVENUE"`
 */
export const readRebasingParityPoolProtocolRevenue =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'PROTOCOL_REVENUE',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"accumulatedFees0"`
 */
export const readRebasingParityPoolAccumulatedFees0 =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'accumulatedFees0',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"accumulatedFees1"`
 */
export const readRebasingParityPoolAccumulatedFees1 =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'accumulatedFees1',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"allowedPoolId"`
 */
export const readRebasingParityPoolAllowedPoolId =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'allowedPoolId',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"claimedFeesPerLpToken0"`
 */
export const readRebasingParityPoolClaimedFeesPerLpToken0 =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'claimedFeesPerLpToken0',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"claimedFeesPerLpToken1"`
 */
export const readRebasingParityPoolClaimedFeesPerLpToken1 =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'claimedFeesPerLpToken1',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"feesPerLpToken0"`
 */
export const readRebasingParityPoolFeesPerLpToken0 =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'feesPerLpToken0',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"feesPerLpToken1"`
 */
export const readRebasingParityPoolFeesPerLpToken1 =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'feesPerLpToken1',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"getAllowedPoolId"`
 */
export const readRebasingParityPoolGetAllowedPoolId =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'getAllowedPoolId',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"getHookPermissions"`
 */
export const readRebasingParityPoolGetHookPermissions =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'getHookPermissions',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"getProtocolFees"`
 */
export const readRebasingParityPoolGetProtocolFees =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'getProtocolFees',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"getProtocolRevenue"`
 */
export const readRebasingParityPoolGetProtocolRevenue =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'getProtocolRevenue',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"getTotalAccumulatedFees"`
 */
export const readRebasingParityPoolGetTotalAccumulatedFees =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'getTotalAccumulatedFees',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"pendingFees"`
 */
export const readRebasingParityPoolPendingFees =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'pendingFees',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"poolETHBalance"`
 */
export const readRebasingParityPoolPoolEthBalance =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'poolETHBalance',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"poolManager"`
 */
export const readRebasingParityPoolPoolManager =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'poolManager',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"poolStETHBalance"`
 */
export const readRebasingParityPoolPoolStEthBalance =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'poolStETHBalance',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"poolStETHPrincipal"`
 */
export const readRebasingParityPoolPoolStEthPrincipal =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'poolStETHPrincipal',
  })

/**
 * Wraps __{@link useReadContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"totalLiquidity"`
 */
export const readRebasingParityPoolTotalLiquidity =
  /*#__PURE__*/ createUseReadContract({
    abi: rebasingParityPoolAbi,
    functionName: 'totalLiquidity',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__
 */
export const writeRebasingParityPoolFunction =
  /*#__PURE__*/ createUseWriteContract({ abi: rebasingParityPoolAbi })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"addLiquidity"`
 */
export const writeRebasingParityPoolAddLiquidity =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'addLiquidity',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterAddLiquidity"`
 */
export const writeRebasingParityPoolAfterAddLiquidity =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterAddLiquidity',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterDonate"`
 */
export const writeRebasingParityPoolAfterDonate =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterDonate',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterInitialize"`
 */
export const writeRebasingParityPoolAfterInitialize =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterInitialize',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterRemoveLiquidity"`
 */
export const writeRebasingParityPoolAfterRemoveLiquidity =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterRemoveLiquidity',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterSwap"`
 */
export const writeRebasingParityPoolAfterSwap =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterSwap',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeAddLiquidity"`
 */
export const writeRebasingParityPoolBeforeAddLiquidity =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeAddLiquidity',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeDonate"`
 */
export const writeRebasingParityPoolBeforeDonate =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeDonate',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeInitialize"`
 */
export const writeRebasingParityPoolBeforeInitialize =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeInitialize',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeRemoveLiquidity"`
 */
export const writeRebasingParityPoolBeforeRemoveLiquidity =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeRemoveLiquidity',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeSwap"`
 */
export const writeRebasingParityPoolBeforeSwap =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeSwap',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"claimFees"`
 */
export const writeRebasingParityPoolClaimFees =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'claimFees',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"removeLiquidity"`
 */
export const writeRebasingParityPoolRemoveLiquidity =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'removeLiquidity',
  })

/**
 * Wraps __{@link useWriteContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"unlockCallback"`
 */
export const writeRebasingParityPoolUnlockCallback =
  /*#__PURE__*/ createUseWriteContract({
    abi: rebasingParityPoolAbi,
    functionName: 'unlockCallback',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__
 */
export const simulateRebasingParityPoolFunction =
  /*#__PURE__*/ createUseSimulateContract({ abi: rebasingParityPoolAbi })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"addLiquidity"`
 */
export const simulateRebasingParityPoolAddLiquidity =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'addLiquidity',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterAddLiquidity"`
 */
export const simulateRebasingParityPoolAfterAddLiquidity =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterAddLiquidity',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterDonate"`
 */
export const simulateRebasingParityPoolAfterDonate =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterDonate',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterInitialize"`
 */
export const simulateRebasingParityPoolAfterInitialize =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterInitialize',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterRemoveLiquidity"`
 */
export const simulateRebasingParityPoolAfterRemoveLiquidity =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterRemoveLiquidity',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"afterSwap"`
 */
export const simulateRebasingParityPoolAfterSwap =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'afterSwap',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeAddLiquidity"`
 */
export const simulateRebasingParityPoolBeforeAddLiquidity =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeAddLiquidity',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeDonate"`
 */
export const simulateRebasingParityPoolBeforeDonate =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeDonate',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeInitialize"`
 */
export const simulateRebasingParityPoolBeforeInitialize =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeInitialize',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeRemoveLiquidity"`
 */
export const simulateRebasingParityPoolBeforeRemoveLiquidity =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeRemoveLiquidity',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"beforeSwap"`
 */
export const simulateRebasingParityPoolBeforeSwap =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'beforeSwap',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"claimFees"`
 */
export const simulateRebasingParityPoolClaimFees =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'claimFees',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"removeLiquidity"`
 */
export const simulateRebasingParityPoolRemoveLiquidity =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'removeLiquidity',
  })

/**
 * Wraps __{@link useSimulateContract}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `functionName` set to `"unlockCallback"`
 */
export const simulateRebasingParityPoolUnlockCallback =
  /*#__PURE__*/ createUseSimulateContract({
    abi: rebasingParityPoolAbi,
    functionName: 'unlockCallback',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link rebasingParityPoolAbi}__
 */
export const watchRebasingParityPoolFunction =
  /*#__PURE__*/ createUseWatchContractEvent({ abi: rebasingParityPoolAbi })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `eventName` set to `"PoolBalancesUpdated"`
 */
export const watchRebasingParityPoolPoolBalancesUpdated =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: rebasingParityPoolAbi,
    eventName: 'PoolBalancesUpdated',
  })

/**
 * Wraps __{@link useWatchContractEvent}__ with `abi` set to __{@link rebasingParityPoolAbi}__ and `eventName` set to `"RebaseYieldDistributed"`
 */
export const watchRebasingParityPoolRebaseYieldDistributed =
  /*#__PURE__*/ createUseWatchContractEvent({
    abi: rebasingParityPoolAbi,
    eventName: 'RebaseYieldDistributed',
  })
