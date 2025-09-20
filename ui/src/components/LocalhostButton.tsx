import { useChainId, useSwitchChain } from 'wagmi'
import { Button } from '@/components/ui/button'
import { localhost } from 'wagmi/chains'

export function LocalhostButton() {
  const chainId = useChainId()
  const { switchChain } = useSwitchChain()

  if (chainId === localhost.id) {
    return null // Hide when already on localhost
  }

  return (
    <Button
      variant="outline"
      size="sm"
      onClick={() => switchChain({ chainId: localhost.id })}
      className="text-xs"
    >
      localhost:8545
    </Button>
  )
}