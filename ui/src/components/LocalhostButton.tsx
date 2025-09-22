import { useChainId, useSwitchChain } from 'wagmi'
import { Button } from '@/components/ui/button'
import { Badge } from '@/components/ui/badge'

const UNICHAIN_FORK_ID = 31337 // Standard localhost chain ID for development

export function LocalhostButton() {
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()

  const isConnectedToFork = chainId === UNICHAIN_FORK_ID

  // Show current chain for debugging
  console.log('Current chain ID:', chainId)

  return (
    <div className="flex items-center gap-2">
      <Button
        variant={isConnectedToFork ? "default" : "outline"}
        size="sm"
        onClick={() => {
          switchChain({ chainId: UNICHAIN_FORK_ID })
        }}
        className="text-xs flex items-center gap-2"
      >
        {isConnectedToFork ? (
          <>
            <span className="w-2 h-2 bg-green-500 rounded-full animate-pulse" />
            localhost:8545
            <Badge variant="secondary" className="ml-1 text-[10px] px-1 py-0">
              Connected
            </Badge>
          </>
        ) : (
          <>
            <span className="w-2 h-2 bg-red-500 rounded-full" />
            Switch to localhost:8545
          </>
        )}
      </Button>
      {!isConnectedToFork && chainId && (
        <Badge variant="outline" className="text-[10px]">
          Chain: {chainId}
        </Badge>
      )}
    </div>
  )
}