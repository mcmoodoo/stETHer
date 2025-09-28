default:
    @just --list

# Start local anvil node forked from Unichain mainnet with localhost chain ID
anvil:
    anvil --fork-url $INFURA_UNICHAIN_MAINNET_RPC --chain-id 31337

# Deploy contracts and generate UI types
deploy:
    forge script script/DeployAll.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    cd ui && bun run wagmi:generate

# Start local development environment (anvil + deploy)
local-dev:
    #!/bin/bash
    echo "🚀 Starting local development environment..."

    # Clean up any existing anvil processes
    echo "0. Cleaning up any existing processes..."
    pkill -f "anvil.*31337" 2>/dev/null || true
    sleep 1

    echo "1. Starting fresh Unichain fork on localhost:8545..."
    anvil --fork-url $INFURA_UNICHAIN_MAINNET_RPC --chain-id 31337 > anvil.log 2>&1 &
    ANVIL_PID=$!
    echo "   Anvil PID: $ANVIL_PID"

    echo "2. Waiting for anvil to start..."
    sleep 5

    # Wait for anvil to be ready
    echo "3. Checking anvil connectivity..."
    for i in {1..10}; do
        if curl -s http://localhost:8545 > /dev/null 2>&1; then
            echo "   Anvil ready!"
            break
        fi
        if [ $i -eq 10 ]; then
            echo "❌ Anvil failed to start after 10 attempts"
            kill $ANVIL_PID 2>/dev/null
            exit 1
        fi
        echo "   Attempt $i: waiting..."
        sleep 1
    done

    echo "4. Deploying contracts..."
    if forge script script/DeployAll.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80; then
        echo "✅ Deployment successful!"
        echo "5. Generating wagmi types..."
        cd ui && bun run wagmi:generate
        echo "🎉 Local development environment ready!"
        echo "   Anvil running on localhost:8545 (PID: $ANVIL_PID)"
        echo "   Use 'just stop-anvil' to stop the fork"
    else
        echo "❌ Deployment failed. Stopping anvil..."
        kill $ANVIL_PID 2>/dev/null
        exit 1
    fi

# Test deployment to verify setup (deploys a simple test contract)
test-deploy-unichain:
    #!/bin/bash
    echo "🧪 Running test deployment to Unichain Mainnet..."
    echo ""

    # Load environment variables from .env if it exists
    if [ -f .env ]; then
        echo "📋 Loading environment variables from .env..."
        export $(cat .env | grep -v '^#' | xargs)
    fi

    # Check required environment variables
    if [ -z "$INFURA_UNICHAIN_MAINNET_RPC" ]; then
        echo "❌ Error: INFURA_UNICHAIN_MAINNET_RPC environment variable not set"
        exit 1
    fi

    if [ -z "$PRIVATE_KEY" ]; then
        echo "❌ Error: PRIVATE_KEY environment variable not set"
        exit 1
    fi

    echo "📊 Checking balance..."
    SENDER=$(cast wallet address --private-key $PRIVATE_KEY)
    BALANCE=$(cast balance $SENDER --rpc-url $INFURA_UNICHAIN_MAINNET_RPC)
    echo "   Sender: $SENDER"
    echo "   Balance: $(cast from-wei $BALANCE) ETH"

    echo ""
    echo "🚀 Deploying test contract..."

    forge script script/TestDeploy.s.sol:TestDeployScript \
        --rpc-url $INFURA_UNICHAIN_MAINNET_RPC \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --verify \
        --chain 130 \
        -vvv

    echo ""
    echo "✅ Test deployment complete!"

# Estimate gas costs for Unichain mainnet deployment
estimate-deploy-cost:
    #!/bin/bash
    echo "💰 Estimating deployment costs for Unichain Mainnet..."
    echo ""

    # Load environment variables from .env if it exists
    if [ -f .env ]; then
        echo "📋 Loading environment variables from .env..."
        export $(cat .env | grep -v '^#' | xargs)
    fi

    # Check required environment variables
    if [ -z "$INFURA_UNICHAIN_MAINNET_RPC" ]; then
        echo "❌ Error: INFURA_UNICHAIN_MAINNET_RPC environment variable not set"
        echo "   Set it in .env or as an environment variable"
        exit 1
    fi

    if [ -z "$PRIVATE_KEY" ]; then
        echo "❌ Error: PRIVATE_KEY environment variable not set"
        echo "   Set it in .env or as an environment variable"
        exit 1
    fi

    echo "🔍 Running deployment simulation to estimate gas..."
    echo ""

    # Run forge script simulation without broadcasting
    OUTPUT=$(forge script script/DeployAll.s.sol \
        --rpc-url $INFURA_UNICHAIN_MAINNET_RPC \
        --private-key $PRIVATE_KEY \
        -vvv 2>&1)

    # Extract gas usage from the output
    echo "$OUTPUT" | grep -E "gas:|Gas Used:|Transaction:|Contract deployment:" | head -20

    echo ""
    echo "📊 Gas Estimation Summary:"
    echo "========================="

    # Get total gas from simulation
    TOTAL_GAS=$(echo "$OUTPUT" | grep -E "gas used:" | awk '{sum += $3} END {print sum}')

    if [ -z "$TOTAL_GAS" ]; then
        # Fallback: estimate based on typical contract sizes
        echo "⚠️  Could not extract exact gas from simulation"
        echo "   Using typical estimates for contract deployments:"
        echo ""
        echo "   StETH deployment: ~1,500,000 gas"
        echo "   ProtocolRevenue deployment: ~500,000 gas"
        echo "   RebasingParityPool deployment: ~3,000,000 gas"
        echo "   Pool initialization: ~300,000 gas"
        echo "   Initial liquidity: ~200,000 gas"
        echo "   --------------------------------"
        TOTAL_GAS=5500000
        echo "   Estimated total: ~5,500,000 gas"
    else
        echo "   Total gas estimated: $TOTAL_GAS"
    fi

    # Get current gas price from network
    echo ""
    echo "🔍 Fetching current gas price..."
    GAS_PRICE_WEI=$(cast gas-price --rpc-url $INFURA_UNICHAIN_MAINNET_RPC 2>/dev/null)

    if [ -z "$GAS_PRICE_WEI" ]; then
        # Fallback to a reasonable default (2 gwei for L2)
        GAS_PRICE_WEI=2000000000
        echo "   Using default gas price: 2 gwei"
    else
        GAS_PRICE_GWEI=$(echo "scale=2; $GAS_PRICE_WEI / 1000000000" | bc)
        echo "   Current gas price: $GAS_PRICE_GWEI gwei"
    fi

    # Calculate total cost in ETH
    TOTAL_COST_WEI=$(echo "$TOTAL_GAS * $GAS_PRICE_WEI" | bc)
    TOTAL_COST_ETH=$(echo "scale=6; $TOTAL_COST_WEI / 1000000000000000000" | bc)

    echo ""
    echo "💵 Cost Estimation:"
    echo "==================="
    echo "   Total Gas: $TOTAL_GAS"
    echo "   Gas Price: $(echo "scale=2; $GAS_PRICE_WEI / 1000000000" | bc) gwei"
    echo "   Total Cost: $TOTAL_COST_ETH ETH"

    # Fetch ETH price in USD (using public API)
    echo ""
    echo "🔍 Fetching current ETH price..."
    ETH_PRICE=$(curl -s "https://api.coingecko.com/api/v3/simple/price?ids=ethereum&vs_currencies=usd" | jq -r '.ethereum.usd' 2>/dev/null)

    if [ ! -z "$ETH_PRICE" ]; then
        TOTAL_USD=$(echo "scale=2; $TOTAL_COST_ETH * $ETH_PRICE" | bc)
        echo "   ETH Price: \$$ETH_PRICE USD"
        echo "   Total Cost: \$$TOTAL_USD USD"
    else
        echo "   Could not fetch ETH price"
    fi

    echo ""
    echo "📝 Note: These are estimates. Actual costs may vary based on:"
    echo "   - Network congestion"
    echo "   - Contract optimization"
    echo "   - Exact bytecode size"
    echo "   - Pool initialization parameters"
    echo ""
    echo "💡 Tip: Add 10-20% buffer for safety"

    # Calculate buffer amounts
    if [ ! -z "$TOTAL_COST_ETH" ]; then
        BUFFER_ETH=$(echo "scale=6; $TOTAL_COST_ETH * 1.2" | bc)
        echo "   Recommended balance: $BUFFER_ETH ETH"

        if [ ! -z "$ETH_PRICE" ]; then
            BUFFER_USD=$(echo "scale=2; $BUFFER_ETH * $ETH_PRICE" | bc)
            echo "   Recommended balance: \$$BUFFER_USD USD"
        fi
    fi

# Deploy to Unichain mainnet (requires INFURA_UNICHAIN_MAINNET_RPC and PRIVATE_KEY env vars)
deploy-unichain-mainnet:
    #!/bin/bash
    echo "🚀 Deploying to Unichain Mainnet..."
    echo ""

    # Load environment variables from .env if it exists
    if [ -f .env ]; then
        echo "📋 Loading environment variables from .env..."
        export $(cat .env | grep -v '^#' | xargs)
    fi

    # Check required environment variables
    if [ -z "$INFURA_UNICHAIN_MAINNET_RPC" ]; then
        echo "❌ Error: INFURA_UNICHAIN_MAINNET_RPC environment variable not set"
        echo "   Set it in .env or as an environment variable"
        exit 1
    fi

    if [ -z "$PRIVATE_KEY" ]; then
        echo "❌ Error: PRIVATE_KEY environment variable not set"
        echo "   Set it in .env or as an environment variable"
        exit 1
    fi

    # Confirm deployment
    echo "⚠️  WARNING: You are about to deploy to Unichain Mainnet!"
    echo "   RPC URL: $INFURA_UNICHAIN_MAINNET_RPC"
    echo "   Chain ID: 130"
    echo ""
    read -p "Are you sure you want to continue? (yes/no): " CONFIRM

    if [ "$CONFIRM" != "yes" ]; then
        echo "Deployment cancelled"
        exit 0
    fi

    echo ""
    echo "📝 Running deployment script..."

    # Run the deployment
    if forge script script/DeployAll.s.sol:DeployAllScript \
        --rpc-url $INFURA_UNICHAIN_MAINNET_RPC \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --chain 130 \
        --sender $(cast wallet address --private-key $PRIVATE_KEY) \
        --gas-estimate-multiplier 110 \
        --slow \
        -vvv; then

        echo ""
        echo "✅ Deployment successful!"
        echo ""
        echo "📋 Next steps:"
        echo "1. Check deployment addresses in ui/src/deployments/deployments-unichain.json"
        echo "2. Verify contracts on Uniscan if needed"
        echo "3. Update UI configuration to use mainnet"
        echo "4. Test the deployed contracts"
    else
        echo ""
        echo "❌ Deployment failed. Please check the error messages above."
        exit 1
    fi

# Verify contracts on Unichain block explorer
verify-unichain-contracts:
    #!/bin/bash
    echo "🔍 Verifying contracts on Unichain..."
    echo ""

    # Load environment variables from .env if it exists
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi

    # Check for Etherscan API key (works on Uniscan too)
    if [ -z "$ETHERSCAN_API_KEY" ]; then
        echo "⚠️  Warning: ETHERSCAN_API_KEY not set in .env"
        echo "   This key works on both Etherscan and Uniscan"
        echo "   Get your API key from: https://etherscan.io/myapikey"
        echo "   Then add to .env: ETHERSCAN_API_KEY=your_key_here"
        echo ""
        read -p "Continue without API key? (y/n): " CONTINUE
        if [ "$CONTINUE" != "y" ]; then
            exit 0
        fi
    fi

    if [ ! -f ui/src/deployments/deployments-unichain.json ]; then
        echo "❌ No deployment file found. Deploy first with 'just deploy-unichain-mainnet'"
        exit 1
    fi

    # Extract addresses from deployment file
    STETH=$(jq -r '.contracts.StETH' ui/src/deployments/deployments-unichain.json)
    PROTOCOL_REVENUE=$(jq -r '.contracts.ProtocolRevenue' ui/src/deployments/deployments-unichain.json)
    REBASING_POOL=$(jq -r '.contracts.RebasingParityPool' ui/src/deployments/deployments-unichain.json)
    PARITY_LP=$(jq -r '.contracts.ParityLP' ui/src/deployments/deployments-unichain.json)

    echo "📋 Deployed contracts:"
    echo "   StETH: $STETH"
    echo "   ProtocolRevenue: $PROTOCOL_REVENUE"
    echo "   RebasingParityPool: $REBASING_POOL"
    echo "   ParityLP: $PARITY_LP"
    echo ""

    # Try to verify with forge verify-contract
    # Note: This may fail if Unichain doesn't have a compatible explorer API yet

    echo "1. Verifying StETH..."
    forge verify-contract \
        --chain 130 \
        --watch \
        $STETH \
        src/StETH.sol:StETH \
        --etherscan-api-key ${ETHERSCAN_API_KEY} \
        || echo "   ⚠️  Could not auto-verify StETH (check API key)"

    echo ""
    echo "2. Verifying ProtocolRevenue..."
    forge verify-contract \
        --chain 130 \
        --watch \
        $PROTOCOL_REVENUE \
        src/ProtocolRevenue.sol:ProtocolRevenue \
        --constructor-args $(cast abi-encode "constructor(address)" "0x1234567890123456789012345678901234567890") \
        --etherscan-api-key ${ETHERSCAN_API_KEY} \
        || echo "   ⚠️  Could not auto-verify ProtocolRevenue"

    echo ""
    echo "3. Verifying RebasingParityPool..."
    forge verify-contract \
        --chain 130 \
        --watch \
        $REBASING_POOL \
        src/RebasingParityPool.sol:RebasingParityPool \
        --constructor-args $(cast abi-encode "constructor(address,address)" "0x1F98400000000000000000000000000000000004" "0x1234567890123456789012345678901234567890") \
        --etherscan-api-key ${ETHERSCAN_API_KEY} \
        || echo "   ⚠️  Could not auto-verify RebasingParityPool"

    echo ""
    echo "4. Verifying ParityLP..."
    forge verify-contract \
        --chain 130 \
        --watch \
        $PARITY_LP \
        src/ParityLP.sol:ParityLP \
        --constructor-args $(cast abi-encode "constructor(address)" "$REBASING_POOL") \
        --etherscan-api-key ${ETHERSCAN_API_KEY} \
        || echo "   ⚠️  Could not auto-verify ParityLP"

    echo ""
    echo "📝 Note: If automatic verification fails, you may need to verify manually on Uniscan"
    echo "   Visit: https://uniscan.io/ (if available)"
    echo ""
    echo "Alternative: Generate verification data for manual submission:"
    echo "   forge verify-contract --show-standard-json-input <address> <contract>"

# Verify Unichain deployment
verify-unichain-deployment:
    #!/bin/bash
    echo "🔍 Verifying Unichain deployment..."

    # Load environment variables from .env if it exists
    if [ -f .env ]; then
        export $(cat .env | grep -v '^#' | xargs)
    fi

    if [ -z "$INFURA_UNICHAIN_MAINNET_RPC" ]; then
        echo "❌ Error: INFURA_UNICHAIN_MAINNET_RPC not set"
        exit 1
    fi

    forge script script/VerifyDeployment.s.sol:VerifyDeploymentScript \
        --rpc-url $INFURA_UNICHAIN_MAINNET_RPC \
        --chain 130

# Add liquidity to Unichain pool
add-liquidity-unichain:
    #!/bin/bash
    echo "💧 Adding liquidity to Unichain pool..."
    echo ""

    # Load environment variables from .env if it exists
    if [ -f .env ]; then
        echo "📋 Loading environment variables from .env..."
        export $(cat .env | grep -v '^#' | xargs)
    fi

    if [ -z "$INFURA_UNICHAIN_MAINNET_RPC" ]; then
        echo "❌ Error: INFURA_UNICHAIN_MAINNET_RPC not set"
        exit 1
    fi

    if [ -z "$PRIVATE_KEY" ]; then
        echo "❌ Error: PRIVATE_KEY not set"
        exit 1
    fi

    # Check balance first
    SENDER=$(cast wallet address --private-key $PRIVATE_KEY)
    BALANCE=$(cast balance $SENDER --rpc-url $INFURA_UNICHAIN_MAINNET_RPC)
    echo "Wallet: $SENDER"
    echo "Balance: $(cast from-wei $BALANCE) ETH"
    echo ""

    MIN_BALANCE=10000000000000000  # 0.01 ETH in wei
    if [ "$BALANCE" -lt "$MIN_BALANCE" ]; then
        echo "❌ Insufficient balance. Need at least 0.01 ETH"
        echo "   Please add funds to your wallet"
        exit 1
    fi

    forge script script/AddLiquidity.s.sol:AddLiquidityScript \
        --rpc-url $INFURA_UNICHAIN_MAINNET_RPC \
        --private-key $PRIVATE_KEY \
        --broadcast \
        --chain 130 \
        -vvv

# Stop the local anvil fork
stop-anvil:
    #!/bin/bash
    echo "🛑 Stopping anvil..."
    pkill -f "anvil.*31337" || echo "No anvil process found"
    rm -f anvil.log
    echo "✅ Anvil stopped"

# Check if contracts are deployed and working
check-deployment:
    #!/bin/bash
    echo "🔍 Checking deployment status..."

    if ! curl -s http://localhost:8545 > /dev/null; then
        echo "❌ Anvil not running on localhost:8545"
        exit 1
    fi

    if [ ! -f ui/src/deployments/deployments-localhost.json ]; then
        echo "❌ Deployment file not found"
        exit 1
    fi

    echo "✅ Anvil running on localhost:8545"
    echo "✅ Deployment file exists"

    # Check contract addresses
    STETH=$(jq -r '.contracts.StETH' ui/src/deployments/deployments-localhost.json)
    POOL=$(jq -r '.contracts.RebasingParityPool' ui/src/deployments/deployments-localhost.json)

    echo "📋 Deployed contracts:"
    echo "   StETH: $STETH"
    echo "   RebasingParityPool: $POOL"

    # Check if contracts have code
    if cast code $STETH --rpc-url http://localhost:8545 | grep -q "0x"; then
        echo "✅ StETH contract deployed"
    else
        echo "❌ StETH contract not found"
    fi

    if cast code $POOL --rpc-url http://localhost:8545 | grep -q "0x"; then
        echo "✅ RebasingParityPool contract deployed"
    else
        echo "❌ RebasingParityPool contract not found"
    fi

# Generate wagmi types
generate:
    cd ui && bun run wagmi:generate

# Run frontend
dev:
    cd ui && bun run dev

# Run all tests
test:
    forge test

# Run rebasing pool tests only
test-rebasing:
    forge test --match-path "**/rebasing/*.sol" -v

# Run tests with coverage report for src/ directory
coverage:
    forge coverage --report summary --report lcov --match-path "src/*" --ir-minimum
    @echo ""
    @echo "📊 Coverage report generated!"
    @echo "📝 To view detailed HTML report: genhtml lcov.info --output-directory coverage && open coverage/index.html"

# Create a control flow graph with surya (requires surya and graphviz)
generate-control-flow FILE="src/RebasingParityPool.sol":
    surya graph {{FILE}} | dot -Tpng > control-flow.png
    @echo "📊 Control flow graph saved as control-flow.png"

# Create inheritance graph with surya (requires surya and graphviz)
generate-inheritance:
    surya inheritance src/*.sol | dot -Tpng > inheritance.png
    @echo "📊 Inheritance graph saved as inheritance.png"

# Build contracts
build:
    forge build

# Clean build artifacts
clean:
    forge clean

# Install/update dependencies
install:
    forge install

# Format code
fmt:
    forge fmt

# Lint and format check
check:
    forge fmt --check
    forge build