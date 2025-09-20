import { defineConfig } from '@wagmi/cli'
import { foundry, react } from '@wagmi/cli/plugins'

export default defineConfig({
  out: 'src/generated.ts',
  contracts: [],
  plugins: [
    foundry({
      project: '../',
      include: [
        'RebasingParityPool.sol/RebasingParityPool.json',
        'ParityLP.sol/ParityLP.json',
        'ProtocolRevenue.sol/ProtocolRevenue.json',
      ],
      exclude: [
        '**/*.dbg.json',
        '**/test/**',
        '**/script/**',
        '**/*Test*',
        '**/mock*/**',
        '**/Mock*',
      ],
      namePrefix: '',
    }),
    react({
      // Use a custom hook naming function to avoid conflicts
      getHookName: ({ type, contractName, itemName }) => {
        const safeType = type || 'use'
        const safeContract = contractName || 'Contract'
        const safeItem = itemName || 'Function'

        const hookType = safeType.charAt(0).toLowerCase() + safeType.slice(1)
        // Remove common conflicting prefixes/suffixes
        const cleanContractName = safeContract
          .replace(/Contract$/, '')
          .replace(/^I/, '') // Remove interface prefix
          .replace(/^StETH$/, 'StEth') // Fix StETH naming conflict
        const cleanItemName = safeItem
          .replace(/^_/, '') // Remove underscore prefix
          .replace(/\$$/, '') // Remove dollar suffix

        return `${hookType}${cleanContractName}${cleanItemName.charAt(0).toUpperCase() + cleanItemName.slice(1)}`
      },
    }),
  ],
})