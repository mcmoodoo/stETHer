import { useState, useEffect } from 'react'
import { useAccount, useBalance } from 'wagmi'
import { getContractAddresses } from './deployments'
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

function App() {
  const [fromAmount, setFromAmount] = useState('')
  const [toAmount, setToAmount] = useState('')
  const [isETHToStETH, setIsETHToStETH] = useState(true)
  
  const { address, isConnected, chain } = useAccount()
  const { data: ethBalance } = useBalance({
    address: address,
  })

  // Contract addresses state
  const [contractAddresses, setContractAddresses] = useState<any>(null)
  const [isLoadingAddresses, setIsLoadingAddresses] = useState(true)
  const [addressError, setAddressError] = useState<string | null>(null)

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
        setContractAddresses(addresses)
      } catch (err) {
        console.error('Failed to load contract addresses:', err)
        setAddressError('Failed to load contract addresses')
      } finally {
        setIsLoadingAddresses(false)
      }
    }

    loadAddresses()
  }, [chain?.id])

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
    return '0.0' // TODO: Add stETH balance fetching
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
                disabled={!isConnected || !fromAmount || isLoadingAddresses || !contractAddresses}
              >
                {!isConnected
                  ? 'Connect Wallet to Swap'
                  : isLoadingAddresses
                  ? 'Loading Contracts...'
                  : !contractAddresses
                  ? 'Contracts Not Deployed'
                  : !fromAmount
                  ? 'Enter Amount'
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
