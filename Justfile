default:
    @just --list

# Start local anvil node
anvil:
    anvil

# Deploy contracts and generate UI types
deploy:
    forge script script/00_DeployAll.s.sol --broadcast --rpc-url http://localhost:8545
    cd ui && bun run wagmi:generate

# Generate wagmi types
generate:
    cd ui && bun run wagmi:generate

# Run frontend
dev:
    cd ui && bun run dev

# create a control flow graph with surya
generate-control-flow:
    surya graph  src/*.sol | dot -Tpng

generate-inheriance-graph:
    surya inheritance src/*.sol | dot -Tpng
