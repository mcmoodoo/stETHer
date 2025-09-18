infura_key := "4656866d4b76456fb395cd6c1b744830"
fork_url := "https://arbitrum-mainnet.infura.io/v3/" + infura_key
chain_id := "1337"

# Show available commands
default:
    @just --list

# Deploy everything
dev:
    ./deploy.sh

# Run local Anvil with Arbitrum fork
anvil:
    anvil --fork-url {{fork_url}} --chain-id {{chain_id}}

# Run tests (use -v for verbose)
test *args="":
    forge test {{args}}

# Build project
build:
    forge build

# Clean build artifacts
clean:
    forge clean

# Deploy to local anvil
deploy:
    forge script script/Anvil.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

# Stop anvil processes
stop:
    -pkill -f "anvil.*fork-url"