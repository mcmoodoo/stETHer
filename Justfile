default:
    @just --list

# Start local anvil node forked from Unichain mainnet with localhost chain ID
anvil:
    anvil --fork-url $INFURA_UNICHAIN_MAINNET_RPC --chain-id 31337

# Deploy contracts and generate UI types
deploy:
    forge script script/DeployAll.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    cd ui && bun run wagmi:generate

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