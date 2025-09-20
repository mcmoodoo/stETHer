import { http, createConfig } from 'wagmi'
import { mainnet, sepolia, localhost } from 'wagmi/chains'
import { injected, metaMask, walletConnect } from 'wagmi/connectors'

// Define Unichain mainnet
const unichain = {
  id: 130,
  name: 'Unichain',
  nativeCurrency: {
    decimals: 18,
    name: 'Ether',
    symbol: 'ETH',
  },
  rpcUrls: {
    default: { http: ['http://127.0.0.1:8545'] }, // Local fork
  },
  blockExplorers: {
    default: { name: 'Uniscan', url: 'https://uniscan.xyz' },
  },
} as const

export const config = createConfig({
  chains: [unichain, mainnet, sepolia, localhost],
  connectors: [
    injected(),
    metaMask(),
  ],
  transports: {
    [unichain.id]: http('http://127.0.0.1:8545'),
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