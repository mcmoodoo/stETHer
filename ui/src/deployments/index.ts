import type { Address } from 'viem'

export interface DeploymentAddresses {
  PoolManager: Address
  StETH: Address
  ProtocolRevenue: Address
  RebasingParityPool: Address
  ParityLP: Address
}

export interface PoolKeyData {
  currency0: Address
  currency1: Address
  fee: number
  tickSpacing: number
  hooks: Address
}

export interface DeploymentData {
  network: string
  chainId: number
  timestamp: number
  deployer: Address
  contracts: DeploymentAddresses
  poolKey: PoolKeyData
}

// Network mapping
const NETWORK_FILES = {
  localhost: 'deployments-localhost.json',
  sepolia: 'deployments-sepolia.json',
  mainnet: 'deployments-mainnet.json',
} as const

type NetworkName = keyof typeof NETWORK_FILES

// Cache for loaded deployments
const deploymentCache = new Map<string, DeploymentData>()

/**
 * Load deployment addresses for a specific network
 * Returns null if deployment file doesn't exist
 */
export async function loadDeploymentAddresses(
  network: NetworkName
): Promise<DeploymentData | null> {
  // Check cache first
  if (deploymentCache.has(network)) {
    return deploymentCache.get(network)!
  }

  try {
    const filename = NETWORK_FILES[network]
    // Dynamic import of the JSON file
    const deploymentModule = await import(`./${filename}`)
    const deployment = deploymentModule.default as DeploymentData

    // Cache the result
    deploymentCache.set(network, deployment)
    return deployment
  } catch (error) {
    console.warn(`No deployment found for network: ${network}`, error)
    return null
  }
}

/**
 * Get deployment addresses for a specific chain ID
 */
export async function getDeploymentByChainId(
  chainId: number
): Promise<DeploymentData | null> {
  // Map chain IDs to network names
  const networkMap: Record<number, NetworkName> = {
    1: 'mainnet',
    11155111: 'sepolia',
    31337: 'localhost',
    1337: 'localhost',
  }

  const network = networkMap[chainId]
  if (!network) {
    console.warn(`Unsupported chain ID: ${chainId}`)
    return null
  }

  return loadDeploymentAddresses(network)
}

/**
 * Get contract addresses for the current chain
 * Returns zero addresses if no deployment found
 */
export async function getContractAddresses(
  chainId: number
): Promise<DeploymentAddresses> {
  const deployment = await getDeploymentByChainId(chainId)

  if (!deployment) {
    // Return zero addresses as fallback
    const ZERO_ADDRESS = '0x0000000000000000000000000000000000000000' as Address
    return {
      PoolManager: ZERO_ADDRESS,
      StETH: ZERO_ADDRESS,
      ProtocolRevenue: ZERO_ADDRESS,
      RebasingParityPool: ZERO_ADDRESS,
      ParityLP: ZERO_ADDRESS,
    }
  }

  return deployment.contracts
}

/**
 * Check if deployment exists for a network
 */
export async function hasDeployment(network: NetworkName): Promise<boolean> {
  const deployment = await loadDeploymentAddresses(network)
  return deployment !== null
}

/**
 * Get the pool key data for a deployment
 */
export async function getPoolKey(chainId: number): Promise<PoolKeyData | null> {
  const deployment = await getDeploymentByChainId(chainId)
  return deployment?.poolKey || null
}