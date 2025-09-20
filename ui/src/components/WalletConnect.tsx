import { useAccount, useConnect, useDisconnect } from 'wagmi'
import { Button } from '@/components/ui/button'
import { Wallet, LogOut, AlertCircle, ChevronDown } from 'lucide-react'
import { useEffect, useState } from 'react'
import {
  DropdownMenu,
  DropdownMenuContent,
  DropdownMenuItem,
  DropdownMenuTrigger,
} from '@/components/ui/dropdown-menu'

export function WalletConnect() {
  const { address, isConnected } = useAccount()
  const { connect, connectors, isPending, error } = useConnect()
  const { disconnect } = useDisconnect()
  const [isDropdownOpen, setIsDropdownOpen] = useState(false)

  // Debug: Log available connectors
  useEffect(() => {
    console.log('Available connectors:', connectors.map(c => ({ id: c.id, name: c.name })))
    if (error) {
      console.error('Connection error:', error)
    }
  }, [connectors, error])

  const handleConnect = async (connector: any) => {
    try {
      console.log('Connecting with connector:', connector.name)
      await connect({ connector })
      setIsDropdownOpen(false)
    } catch (err) {
      console.error('Failed to connect wallet:', err)
      alert(`Failed to connect wallet: ${err instanceof Error ? err.message : 'Unknown error'}`)
    }
  }

  const getConnectorIcon = (connectorId: string) => {
    switch (connectorId) {
      case 'metaMask':
        return '🦊'
      case 'injected':
        return '💰'
      default:
        return '🔗'
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
      <DropdownMenu open={isDropdownOpen} onOpenChange={setIsDropdownOpen}>
        <DropdownMenuTrigger asChild>
          <Button
            variant="outline"
            size="sm"
            disabled={isPending}
          >
            <Wallet className="h-4 w-4 mr-2" />
            {isPending ? 'Connecting...' : 'Connect Wallet'}
            <ChevronDown className="h-4 w-4 ml-2" />
          </Button>
        </DropdownMenuTrigger>
        <DropdownMenuContent align="end">
          {connectors.map((connector) => (
            <DropdownMenuItem
              key={connector.id}
              onClick={() => handleConnect(connector)}
              disabled={isPending}
            >
              <span className="mr-2">{getConnectorIcon(connector.id)}</span>
              {connector.name}
              {connector.id === 'injected' && (
                <span className="ml-auto text-xs text-muted-foreground">
                  Browser Extension
                </span>
              )}
            </DropdownMenuItem>
          ))}
        </DropdownMenuContent>
      </DropdownMenu>
      {error && (
        <div title={error.message}>
          <AlertCircle className="h-4 w-4 text-red-500" />
        </div>
      )}
    </div>
  )
}