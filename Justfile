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