default:
    @just --list

# Start local anvil node forked from Unichain mainnet
anvil:
    anvil --fork-url $INFURA_UNICHAIN_MAINNET_RPC

# Deploy contracts and generate UI types
deploy:
    forge script script/00_DeployAll.s.sol --broadcast --rpc-url http://localhost:8545
    cd ui && bun run wagmi:generate

# Generate wagmi types
generate:
    cd ui && bun run wagmi:generate

# Send 1 ETH from anvil default wallet to specified address
fund ADDRESS="0xA0c5Df94F8dd2f9aB6a4AD7A323a924670603Df8":
    cast send {{ADDRESS}} --value 1ether --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Run frontend
dev:
    cd ui && bun run dev

# create a control flow graph with surya
generate-control-flow:
    surya graph  src/*.sol | dot -Tpng

generate-inheriance-graph:
    surya inheritance src/*.sol | dot -Tpng
