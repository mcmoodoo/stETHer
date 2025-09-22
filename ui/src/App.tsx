import { useState, useEffect } from 'react'
import { useAccount, useBalance, useWriteContract, useWaitForTransactionReceipt } from 'wagmi'
import { readContract, waitForTransactionReceipt } from 'wagmi/actions'
import { config } from './wagmi'
import { parseEther, encodeAbiParameters } from 'viem'
import { getContractAddresses, getPoolKey, type DeploymentAddresses, type PoolKeyData } from './deployments'
import {
  readRebasingParityPoolPoolEthBalance,
  readRebasingParityPoolPoolStEthBalance,
  readRebasingParityPoolTotalLiquidity,
  readRebasingParityPoolAccumulatedFees0,
  readRebasingParityPoolAccumulatedFees1,
  readParityLpBalanceOf,
} from './generated'
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from '@/components/ui/card'
import { Button } from '@/components/ui/button'
import { Input } from '@/components/ui/input'
import { Label } from '@/components/ui/label'
import { Separator } from '@/components/ui/separator'
import { Badge } from '@/components/ui/badge'
import { ArrowUpDown } from 'lucide-react'
import { WalletConnect } from '@/components/WalletConnect'
import { LocalhostButton } from '@/components/LocalhostButton'

// Constants
const UNIVERSAL_ROUTER = '0xef740bf23acae26f6492b10de645d6b98dc8eaf3'
const V4_SWAP_COMMAND = '0x10'
const V4_ACTIONS = '0x060c0f' // SWAP_EXACT_IN_SINGLE(0x06) + SETTLE_ALL(0x0c) + TAKE_ALL(0x0f)
const SLIPPAGE_TOLERANCE = 0.01 // 1%

// Universal Router ABI for execute function
const UNIVERSAL_ROUTER_ABI = [
  {
    "inputs": [
      {"internalType": "bytes", "name": "commands", "type": "bytes"},
      {"internalType": "bytes[]", "name": "inputs", "type": "bytes[]"},
      {"internalType": "uint256", "name": "deadline", "type": "uint256"}
    ],
    "name": "execute",
    "outputs": [],
    "stateMutability": "payable",
    "type": "function"
  }
] as const

// ERC20 ABI for allowance and approve
const ERC20_ABI = [
  {
    "inputs": [
      {"internalType": "address", "name": "owner", "type": "address"},
      {"internalType": "address", "name": "spender", "type": "address"}
    ],
    "name": "allowance",
    "outputs": [{"internalType": "uint256", "name": "", "type": "uint256"}],
    "stateMutability": "view",
    "type": "function"
  },
  {
    "inputs": [
      {"internalType": "address", "name": "spender", "type": "address"},
      {"internalType": "uint256", "name": "amount", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"internalType": "bool", "name": "", "type": "bool"}],
    "stateMutability": "nonpayable",
    "type": "function"
  }
] as const

function App() {
  const [fromAmount, setFromAmount] = useState('')
  const [toAmount, setToAmount] = useState('')
  const [isETHToStETH, setIsETHToStETH] = useState(true)
  const [isSwapping, setIsSwapping] = useState(false)
  const [swapStatus, setSwapStatus] = useState('')
  
  const { address, isConnected, chain } = useAccount()
  const { data: ethBalance } = useBalance({
    address: address,
  })

  // Contract addresses state
  const [contractAddresses, setContractAddresses] = useState<DeploymentAddresses | null>(null)
  const [poolKeyData, setPoolKeyData] = useState<PoolKeyData | null>(null)
  const [isLoadingAddresses, setIsLoadingAddresses] = useState(true)
  const [addressError, setAddressError] = useState<string | null>(null)

  // stETH balance - must be after contractAddresses state
  const { data: stethBalance } = useBalance({
    address: address,
    token: contractAddresses?.StETH as `0x${string}`,
  })

  // Load contract addresses
  useEffect(() => {
    const loadAddresses = async () => {
      if (!chain?.id) {
        setIsLoadingAddresses(false)
        setAddressError('No chain connected')
        return
      }

      try {
        setAddressError(null)
        const addresses = await getContractAddresses(chain.id)
        const poolKey = await getPoolKey(chain.id)
        setContractAddresses(addresses)
        setPoolKeyData(poolKey)
      } catch (err) {
        console.error('Failed to load contract addresses:', err)
        setAddressError('Failed to load contract addresses')
      } finally {
        setIsLoadingAddresses(false)
      }
    }

    loadAddresses()
  }, [chain?.id])

  // Write contract hook for transactions
  const { writeContract, data: hash, error: writeError, isPending: isWritePending } = useWriteContract()

  // Wait for transaction receipt
  const { isLoading: isConfirming, isSuccess: isConfirmed } = useWaitForTransactionReceipt({
    hash,
  })

  // Monitor transaction status
  useEffect(() => {
    if (isConfirming) {
      console.log('Transaction confirming...', hash)
      setSwapStatus('Transaction confirming...')
    }
    if (isConfirmed) {
      console.log('Transaction confirmed!', hash)
      setIsSwapping(false)
      setSwapStatus('Swap completed successfully!')

      // Reset form after a brief delay to show success message
      setTimeout(() => {
        setFromAmount('')
        setToAmount('')
        setSwapStatus('')
      }, 3000)
    }
  }, [isConfirming, isConfirmed, hash])

  // Generated hooks for contract data
  const { data: poolEthBalance } = readRebasingParityPoolPoolEthBalance({
    address: contractAddresses?.RebasingParityPool,
  })

  const { data: poolStEthBalance } = readRebasingParityPoolPoolStEthBalance({
    address: contractAddresses?.RebasingParityPool,
  })

  const { data: totalLiquidity } = readRebasingParityPoolTotalLiquidity({
    address: contractAddresses?.RebasingParityPool,
  })

  const { data: fees0 } = readRebasingParityPoolAccumulatedFees0({
    address: contractAddresses?.RebasingParityPool,
  })

  const { data: fees1 } = readRebasingParityPoolAccumulatedFees1({
    address: contractAddresses?.RebasingParityPool,
  })

  const { data: lpBalance } = readParityLpBalanceOf({
    address: contractAddresses?.ParityLP,
    args: address ? [address] : undefined,
  })

  // Format balances
  const formatBalance = (balance: bigint | undefined) => {
    if (!balance) return '0.0000'
    return (Number(balance) / 1e18).toFixed(4)
  }
  
  const fromToken = isETHToStETH ? 'ETH' : 'stETH'
  const toToken = isETHToStETH ? 'stETH' : 'ETH'
  const fee = isETHToStETH ? 0 : 0.1
  
  
  const getTokenBalance = (token: string) => {
    if (token === 'ETH') {
      return formatBalance(ethBalance?.value)
    }
    if (token === 'stETH') {
      return formatBalance(stethBalance?.value)
    }
    return '0.0'
  }
  
  const calculateOutput = (input: string) => {
    if (!input) return ''
    const amount = parseFloat(input)
    if (isNaN(amount)) return ''
    
    if (isETHToStETH) {
      return amount.toString()
    } else {
      return (amount * (1 - fee / 100)).toFixed(6)
    }
  }
  
  const handleFromAmountChange = (value: string) => {
    setFromAmount(value)
    setToAmount(calculateOutput(value))
  }
  
  const handleSwapDirection = () => {
    setIsETHToStETH(!isETHToStETH)
    setFromAmount(toAmount)
    setToAmount(fromAmount)
  }

  const handleSwap = async () => {
    if (!isConnected || !fromAmount || !contractAddresses || !poolKeyData) {
      console.log('Cannot swap - missing requirements')
      return
    }

    setIsSwapping(true)
    setSwapStatus('')

    try {
      console.log('Swap details:', {
        from: fromToken,
        to: toToken,
        amount: fromAmount,
        expectedOutput: toAmount,
        fee: fee,
      })

      // Convert amount to wei
      const amountWei = parseEther(fromAmount)

      if (isETHToStETH) {
        // ETH -> stETH swap using Universal Router V4_SWAP
        console.log('Executing ETH -> stETH swap:', {
          zeroForOne: true,
          amountSpecified: amountWei.toString(),
          poolKey: poolKeyData
        })

        const deadline = Math.floor(Date.now() / 1000) + 3600 // 1 hour from now

        try {
          // V4_SWAP command with proper Universal Router encoding
          const commands = V4_SWAP_COMMAND

          // Encode actions sequence
          const actions = V4_ACTIONS // 0x060c0f

          // Encode swap parameters following Universal Router format
          const swapParams = encodeAbiParameters(
            [
              {
                type: 'tuple',
                components: [
                  { name: 'currency0', type: 'address' },
                  { name: 'currency1', type: 'address' },
                  { name: 'fee', type: 'uint24' },
                  { name: 'tickSpacing', type: 'int24' },
                  { name: 'hooks', type: 'address' }
                ]
              }, // PoolKey
              { type: 'bool' },    // zeroForOne
              { type: 'uint128' }, // amountIn
              { type: 'uint128' }, // amountOutMinimum
              { type: 'bytes' }    // hookData
            ],
            [
              poolKeyData,
              true, // zeroForOne (ETH -> stETH)
              BigInt(amountWei.toString()),
              BigInt(Math.floor(parseFloat(toAmount) * 1e18 * (1 - SLIPPAGE_TOLERANCE))), // slippage protection
              '0x' // empty hook data
            ]
          )

          // Encode parameters for SETTLE_ALL and TAKE_ALL actions
          // SETTLE_ALL: (Currency currency, uint256 maxAmount)
          const settleParams = encodeAbiParameters(
            [{ type: 'address' }, { type: 'uint256' }],
            [poolKeyData.currency0, BigInt(amountWei.toString())] // ETH, maxAmount
          )

          // TAKE_ALL: (Currency currency, uint256 minAmount)
          const takeParams = encodeAbiParameters(
            [{ type: 'address' }, { type: 'uint256' }],
            [poolKeyData.currency1, BigInt(Math.floor(parseFloat(toAmount) * 1e18 * (1 - SLIPPAGE_TOLERANCE)))] // stETH, minAmount
          )

          // Universal Router V4_SWAP expects: (bytes actions, bytes[] params)
          // Where params is an array of encoded parameters for each action
          const actionParamsArray = [swapParams, settleParams, takeParams]

          const v4SwapInput = encodeAbiParameters(
            [{ type: 'bytes' }, { type: 'bytes[]' }],
            [actions as `0x${string}`, actionParamsArray]
          )

          console.log('Executing ETH->stETH swap via Universal Router:', {
            commands,
            actions,
            v4SwapInput,
            value: amountWei.toString()
          })

          await writeContract({
            address: UNIVERSAL_ROUTER as `0x${string}`,
            abi: UNIVERSAL_ROUTER_ABI,
            functionName: 'execute',
            args: [
              commands as `0x${string}`,
              [v4SwapInput],
              BigInt(deadline)
            ],
            value: amountWei
          })

          console.log('ETH->stETH swap transaction submitted!')

        } catch (error) {
          console.error('ETH->stETH swap failed:', error)
          throw error
        }

      } else {
        // stETH -> ETH swap using Universal Router V4_SWAP with approval handling
        console.log('Executing stETH -> ETH swap:', {
          zeroForOne: false,
          amountSpecified: amountWei.toString(),
          poolKey: poolKeyData
        })

        const deadline = Math.floor(Date.now() / 1000) + 3600 // 1 hour from now

        try {
          // Check current allowance for stETH
          setSwapStatus('Checking allowance...')
          const currentAllowance = await readContract(config, {
            address: contractAddresses.StETH as `0x${string}`,
            abi: ERC20_ABI,
            functionName: 'allowance',
            args: [address as `0x${string}`, UNIVERSAL_ROUTER]
          })

          // If allowance is insufficient, request approval first
          if (currentAllowance < BigInt(amountWei.toString())) {
            console.log('Insufficient allowance, requesting approval...')
            setSwapStatus('Requesting approval...')

            await writeContract({
              address: contractAddresses.StETH as `0x${string}`,
              abi: ERC20_ABI,
              functionName: 'approve',
              args: [UNIVERSAL_ROUTER, BigInt(amountWei.toString())]
            })

            console.log('Approval transaction submitted')
            setSwapStatus('Approval pending...')

            // Wait for approval confirmation using the hash from the hook
            if (hash) {
              await waitForTransactionReceipt(config, { hash })
              console.log('Approval confirmed')
              setSwapStatus('Preparing swap...')
            }
          }

          // V4_SWAP command with proper Universal Router encoding
          const commands = V4_SWAP_COMMAND

          // Encode actions sequence
          const actions = V4_ACTIONS // 0x060c0f

          // Encode swap parameters following Universal Router format
          const swapParams = encodeAbiParameters(
            [
              {
                type: 'tuple',
                components: [
                  { name: 'currency0', type: 'address' },
                  { name: 'currency1', type: 'address' },
                  { name: 'fee', type: 'uint24' },
                  { name: 'tickSpacing', type: 'int24' },
                  { name: 'hooks', type: 'address' }
                ]
              }, // PoolKey
              { type: 'bool' },    // zeroForOne
              { type: 'uint128' }, // amountIn
              { type: 'uint128' }, // amountOutMinimum
              { type: 'bytes' }    // hookData
            ],
            [
              poolKeyData,
              false, // zeroForOne (false for stETH -> ETH)
              BigInt(amountWei.toString()),
              BigInt(Math.floor(parseFloat(toAmount) * 1e18 * (1 - SLIPPAGE_TOLERANCE))), // slippage protection
              '0x' // empty hook data
            ]
          )

          // Encode parameters for SETTLE_ALL and TAKE_ALL actions
          // SETTLE_ALL: (Currency currency, uint256 maxAmount)
          const settleParams = encodeAbiParameters(
            [{ type: 'address' }, { type: 'uint256' }],
            [poolKeyData.currency1, BigInt(amountWei.toString())] // stETH, maxAmount
          )

          // TAKE_ALL: (Currency currency, uint256 minAmount)
          const takeParams = encodeAbiParameters(
            [{ type: 'address' }, { type: 'uint256' }],
            [poolKeyData.currency0, BigInt(Math.floor(parseFloat(toAmount) * 1e18 * (1 - SLIPPAGE_TOLERANCE)))] // ETH, minAmount
          )

          // Universal Router V4_SWAP expects: (bytes actions, bytes[] params)
          // Where params is an array of encoded parameters for each action
          const actionParamsArray = [swapParams, settleParams, takeParams]

          const v4SwapInput = encodeAbiParameters(
            [{ type: 'bytes' }, { type: 'bytes[]' }],
            [actions as `0x${string}`, actionParamsArray]
          )

          console.log('Executing stETH->ETH swap via Universal Router:', {
            commands,
            actions,
            v4SwapInput
          })

          setSwapStatus('Executing swap...')

          await writeContract({
            address: UNIVERSAL_ROUTER as `0x${string}`,
            abi: UNIVERSAL_ROUTER_ABI,
            functionName: 'execute',
            args: [
              commands as `0x${string}`,
              [v4SwapInput],
              BigInt(deadline)
            ]
            // No value needed for stETH -> ETH swap
          })

          console.log('stETH->ETH swap transaction submitted!')

        } catch (error) {
          console.error('stETH->ETH swap failed:', error)
          throw error
        }
      }

    } catch (error) {
      console.error('Swap failed:', error)

      // Improved error handling with specific error messages
      let errorMessage = 'Unknown error occurred'
      if (error instanceof Error) {
        if (error.message.includes('User rejected')) {
          errorMessage = 'Transaction was rejected by user'
        } else if (error.message.includes('insufficient funds')) {
          errorMessage = 'Insufficient funds for transaction'
        } else if (error.message.includes('allowance')) {
          errorMessage = 'Token allowance error'
        } else if (error.message.includes('slippage')) {
          errorMessage = 'Price slippage too high, try again'
        } else {
          errorMessage = error.message
        }
      }

      setSwapStatus(`Error: ${errorMessage}`)

      // Clear error status after 5 seconds
      setTimeout(() => {
        setSwapStatus('')
      }, 5000)

    } finally {
      setIsSwapping(false)
      // Don't clear swapStatus immediately in finally block, let it show for errors
    }
  }

  return (
    <div className="min-h-screen bg-background flex items-center justify-center p-4">
      <div className="w-full max-w-6xl grid grid-cols-1 lg:grid-cols-3 gap-6">
        
        {/* Swap Interface */}
        <div className="lg:col-span-2">
          <Card className="w-full max-w-md mx-auto">
            <CardHeader>
              <CardTitle className="flex items-center justify-between">
                Parity Pool
                <div className="flex items-center gap-2">
                  <LocalhostButton />
                  <WalletConnect />
                </div>
              </CardTitle>
              <CardDescription>
                Trade ETH and stETH at 1:1 ratio with asymmetric fees
              </CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              {/* From Token */}
              <div className="space-y-2">
                <Label htmlFor="from-amount">From</Label>
                <div className="relative">
                  <Input
                    id="from-amount"
                    placeholder="0.0"
                    value={fromAmount}
                    onChange={(e) => handleFromAmountChange(e.target.value)}
                    className="pr-20"
                  />
                  <div className="absolute inset-y-0 right-0 flex items-center pr-3">
                    <Badge variant="secondary">{fromToken}</Badge>
                  </div>
                </div>
                <div className="text-sm text-muted-foreground">
                  Balance: {isConnected ? getTokenBalance(fromToken) : '0.0'} {fromToken}
                </div>
              </div>

              {/* Swap Direction Button */}
              <div className="flex justify-center">
                <Button
                  variant="outline"
                  size="sm"
                  onClick={handleSwapDirection}
                  className="rounded-full"
                >
                  <ArrowUpDown className="h-4 w-4" />
                </Button>
              </div>

              {/* To Token */}
              <div className="space-y-2">
                <Label htmlFor="to-amount">To</Label>
                <div className="relative">
                  <Input
                    id="to-amount"
                    placeholder="0.0"
                    value={toAmount}
                    readOnly
                    className="pr-20 bg-muted"
                  />
                  <div className="absolute inset-y-0 right-0 flex items-center pr-3">
                    <Badge variant="secondary">{toToken}</Badge>
                  </div>
                </div>
                <div className="text-sm text-muted-foreground">
                  Balance: {isConnected ? getTokenBalance(toToken) : '0.0'} {toToken}
                </div>
              </div>

              {/* Fee Display */}
              <div className="p-3 bg-muted/50 rounded-lg">
                <div className="flex justify-between text-sm">
                  <span>Trading Fee:</span>
                  <span className={fee === 0 ? "text-green-600" : "text-orange-600"}>
                    {fee}%
                  </span>
                </div>
                {fee === 0 && (
                  <div className="text-xs text-green-600 mt-1">
                    No fee! This direction is incentivized
                  </div>
                )}
              </div>

              {/* Swap Button */}
              <Button
                className="w-full"
                size="lg"
                disabled={!isConnected || !fromAmount || isLoadingAddresses || !contractAddresses || !poolKeyData || isSwapping || isWritePending || isConfirming}
                onClick={handleSwap}
              >
                {!isConnected
                  ? 'Connect Wallet to Swap'
                  : isLoadingAddresses
                  ? 'Loading Contracts...'
                  : !contractAddresses || !poolKeyData
                  ? 'Contracts Not Deployed'
                  : !fromAmount
                  ? 'Enter Amount'
                  : isWritePending
                  ? 'Confirm in Wallet...'
                  : isConfirming
                  ? 'Transaction Confirming...'
                  : isSwapping
                  ? (swapStatus || 'Preparing Swap...')
                  : `Swap ${fromToken} for ${toToken}`
                }
              </Button>

              {/* Contract Status */}
              {addressError && (
                <div className="p-3 bg-orange-50 border border-orange-200 rounded-lg">
                  <p className="text-sm text-orange-600">
                    ⚠️ {addressError}
                  </p>
                </div>
              )}

              {contractAddresses && (
                <div className="p-3 bg-green-50 border border-green-200 rounded-lg">
                  <p className="text-sm text-green-600">
                    ✅ Contracts loaded successfully
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    LP Balance: {formatBalance(lpBalance)} tokens
                  </p>
                </div>
              )}

              {/* Transaction Status */}
              {hash && (
                <div className={`p-3 rounded-lg border ${
                  isConfirmed ? 'bg-green-50 border-green-200' : 'bg-blue-50 border-blue-200'
                }`}>
                  <p className={`text-sm ${isConfirmed ? 'text-green-600' : 'text-blue-600'}`}>
                    {isConfirmed ? '✅ Swap Complete!' : '⏳ Transaction Pending...'}
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    Hash: {hash.slice(0, 10)}...{hash.slice(-8)}
                  </p>
                </div>
              )}

              {/* Swap Status Indicator */}
              {swapStatus && (
                <div className={`p-3 rounded-lg border ${
                  swapStatus.includes('Error')
                    ? 'bg-red-50 border-red-200'
                    : swapStatus.includes('completed successfully')
                    ? 'bg-green-50 border-green-200'
                    : 'bg-blue-50 border-blue-200'
                }`}>
                  <p className={`text-sm ${
                    swapStatus.includes('Error')
                      ? 'text-red-600'
                      : swapStatus.includes('completed successfully')
                      ? 'text-green-600'
                      : 'text-blue-600'
                  }`}>
                    {swapStatus.includes('Error')
                      ? '❌'
                      : swapStatus.includes('completed successfully')
                      ? '✅'
                      : '⏳'
                    } {swapStatus}
                  </p>
                </div>
              )}

              {writeError && (
                <div className="p-3 bg-red-50 border border-red-200 rounded-lg">
                  <p className="text-sm text-red-600">
                    ❌ Transaction Failed
                  </p>
                  <p className="text-xs text-gray-500 mt-1">
                    {writeError.message}
                  </p>
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Pool Details */}
        <div className="space-y-6">
          <Card>
            <CardHeader>
              <CardTitle>Pool Details</CardTitle>
              <CardDescription>ETH/stETH Parity Pool</CardDescription>
            </CardHeader>
            <CardContent className="space-y-4">
              <div className="space-y-3">
                <div className="flex justify-between">
                  <span className="text-sm font-medium">Pool Type:</span>
                  <span className="text-sm">Parity (1:1)</span>
                </div>
                <Separator />
                <div className="flex justify-between">
                  <span className="text-sm font-medium">ETH Balance:</span>
                  <span className="text-sm">{formatBalance(poolEthBalance)} ETH</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm font-medium">stETH Balance:</span>
                  <span className="text-sm">{formatBalance(poolStEthBalance)} stETH</span>
                </div>
                <Separator />
                <div className="flex justify-between">
                  <span className="text-sm font-medium">Total Liquidity:</span>
                  <span className="text-sm">{formatBalance(totalLiquidity)} LP</span>
                </div>
                <div className="flex justify-between">
                  <span className="text-sm font-medium">Accumulated Fees:</span>
                  <span className="text-sm">{formatBalance(fees0)} ETH / {formatBalance(fees1)} stETH</span>
                </div>
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>Fee Structure</CardTitle>
              <CardDescription>Asymmetric fees to incentivize rebalancing</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between items-center">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">ETH → stETH:</span>
                  <Badge variant="secondary" className="text-green-600">0% Fee</Badge>
                </div>
              </div>
              <div className="flex justify-between items-center">
                <div className="flex items-center gap-2">
                  <span className="text-sm font-medium">stETH → ETH:</span>
                  <Badge variant="secondary" className="text-orange-600">0.1% Fee</Badge>
                </div>
              </div>
              <Separator />
              <div className="text-xs text-muted-foreground">
                Lower fees encourage ETH deposits to rebalance the pool when stETH accumulates yield.
              </div>
            </CardContent>
          </Card>

          <Card>
            <CardHeader>
              <CardTitle>stETH Yield</CardTitle>
              <CardDescription>Rebasing token with 5% APY</CardDescription>
            </CardHeader>
            <CardContent className="space-y-3">
              <div className="flex justify-between">
                <span className="text-sm font-medium">Current APY:</span>
                <span className="text-sm text-green-600">5.00%</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm font-medium">Last Rebase:</span>
                <span className="text-sm">--</span>
              </div>
              <div className="flex justify-between">
                <span className="text-sm font-medium">Share Price:</span>
                <span className="text-sm">1.000000 ETH</span>
              </div>
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  )
}

export default App
