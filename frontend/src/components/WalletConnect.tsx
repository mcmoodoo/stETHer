import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { Button } from '@/components/ui/button'
import { Wallet, LogOut, AlertCircle } from 'lucide-react'
import { useEffect } from 'react'

export function WalletConnect() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending, error } = useConnect()
  const { disconnect } = useDisconnect()

  // Debug: Log available connectors
  useEffect(() => {
    console.log('Available connectors:', connectors.map(c => ({ id: c.id, name: c.name })))
    if (error) {
      console.error('Connection error:', error)
    }
  }, [connectors, error])

  const handleConnect = async () => {
    try {
      // Check if MetaMask is installed
      if (typeof window !== 'undefined' && !window.ethereum) {
        alert('MetaMask is not installed. Please install MetaMask and try again.')
        return
      }

      // Try MetaMask connector first
      const metaMaskConnector = connectors.find(
        (connector) => connector.id === 'metaMask' || connector.name.toLowerCase().includes('metamask')
      )
      
      // Then try injected connector
      const injectedConnector = connectors.find(
        (connector) => connector.id === 'injected'
      )
      
      const connectorToUse = metaMaskConnector || injectedConnector || connectors[0]
      
      if (connectorToUse) {
        console.log('Connecting with connector:', connectorToUse.name)
        await connect({ connector: connectorToUse })
      } else {
        console.error('No suitable connector found')
        alert('No wallet connector found. Please make sure you have a wallet installed.')
      }
    } catch (err) {
      console.error('Failed to connect wallet:', err)
      alert(`Failed to connect wallet: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  if (isConnected && address) {
    return (
      <Button variant="outline" size="sm" onClick={() => disconnect()}>
        <LogOut className="h-4 w-4 mr-2" />
        {address.slice(0, 6)}...{address.slice(-4)}
      </Button>
    )
  }

  return (
    <div className="flex items-center gap-2">
      <Button
        variant="outline"
        size="sm"
        onClick={handleConnect}
        disabled={isPending}
      >
        <Wallet className="h-4 w-4 mr-2" />
        {isPending ? 'Connecting...' : 'Connect Wallet'}
      </Button>
      {error && (
        <AlertCircle className="h-4 w-4 text-red-500" title={error.message} />
      )}
    </div>
  )
}