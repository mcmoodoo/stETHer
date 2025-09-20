import { http, createConfig } from 'wagmi'
import { mainnet, sepolia, localhost } from 'wagmi/chains'
import { injected, metaMask } from 'wagmi/connectors'

export const config = createConfig({
  chains: [mainnet, sepolia, localhost],
  connectors: [
    injected(),
    metaMask(),
  ],
  transports: {
    [mainnet.id]: http(),
    [sepolia.id]: http(),
    [localhost.id]: http('http://127.0.0.1:8545'),
  },
})

declare module 'wagmi' {
  interface Register {
    config: typeof config
  }
}