default:
    @just --list

# Start local anvil node forked from Unichain mainnet with localhost chain ID
anvil:
    anvil --fork-url $INFURA_UNICHAIN_MAINNET_RPC --chain-id 31337

# Deploy contracts and generate UI types
deploy:
    forge script script/00_DeployAll.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80
    cd ui && bun run wagmi:generate

# Generate wagmi types
generate:
    cd ui && bun run wagmi:generate

# Send 1 ETH from anvil default wallet to specified address
fund ADDRESS="0xA0c5Df94F8dd2f9aB6a4AD7A323a924670603Df8":
    cast send {{ADDRESS}} --value 1ether --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Mint stETH tokens to specified address
mint-steth AMOUNT="10" ADDRESS="0x59b670e9fA9D0A427751Af201D676719a970857b":
    cast send $(jq -r '.contracts.StETH' ui/src/deployments/deployments-localhost.json) "mint(address,uint256)" {{ADDRESS}} {{AMOUNT}}000000000000000000 --rpc-url http://localhost:8545 --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Check stETH balance for specified address
check-steth ADDRESS="0xA0c5Df94F8dd2f9aB6a4AD7A323a924670603Df8":
    @echo "Checking stETH contract at: $(jq -r '.contracts.StETH' ui/src/deployments/deployments-localhost.json)"
    @echo "Contract code size: $(cast code $(jq -r '.contracts.StETH' ui/src/deployments/deployments-localhost.json) --rpc-url http://localhost:8545 | wc -c) bytes"
    @echo "stETH balance for {{ADDRESS}}:"
    @balance_wei=$(cast call $(jq -r '.contracts.StETH' ui/src/deployments/deployments-localhost.json) "balanceOf(address)" {{ADDRESS}} --rpc-url http://localhost:8545 | cast --to-dec) && cast --from-wei $balance_wei eth

# Run frontend
dev:
    cd ui && bun run dev

# create a control flow graph with surya
generate-control-flow:
    surya graph  src/*.sol | dot -Tpng

generate-inheriance-graph:
    surya inheritance src/*.sol | dot -Tpng
