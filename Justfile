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

# Add liquidity to the RebasingParityPool
add-liquidity AMOUNT="0.1":
    #!/bin/bash
    set -e
    echo "Adding {{AMOUNT}} ETH + {{AMOUNT}} stETH liquidity to RebasingParityPool..."

    POOL_ADDRESS=$(jq -r '.contracts.RebasingParityPool' ui/src/deployments/deployments-localhost.json)
    STETH_ADDRESS=$(jq -r '.contracts.StETH' ui/src/deployments/deployments-localhost.json)
    POOL_MANAGER=$(jq -r '.contracts.PoolManager' ui/src/deployments/deployments-localhost.json)
    POOL_DATA=$(jq -r '.poolKey' ui/src/deployments/deployments-localhost.json)

    CURRENCY0=$(echo $POOL_DATA | jq -r '.currency0')
    CURRENCY1=$(echo $POOL_DATA | jq -r '.currency1')
    FEE=$(echo $POOL_DATA | jq -r '.fee')
    TICK_SPACING=$(echo $POOL_DATA | jq -r '.tickSpacing')
    HOOKS=$(echo $POOL_DATA | jq -r '.hooks')

    AMOUNT_WEI=$(cast --to-wei {{AMOUNT}} eth)

    echo "First, minting stETH for liquidity provision..."
    cast send $STETH_ADDRESS "mint(address,uint256)" 0xf39Fd6e51aad88F6F4ce6aB8827279cffFb92266 $AMOUNT_WEI \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

    echo "Approving PoolManager to spend stETH..."
    cast send $STETH_ADDRESS "approve(address,uint256)" $POOL_MANAGER $AMOUNT_WEI \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

    echo "Adding liquidity..."
    cast send $POOL_ADDRESS "addLiquidity((address,address,uint24,int24,address),uint256)" \
        "($CURRENCY0,$CURRENCY1,$FEE,$TICK_SPACING,$HOOKS)" $AMOUNT_WEI \
        --value $AMOUNT_WEI \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

    echo "✅ Liquidity added successfully!"

# Check pool token holdings
check-pool-balances:
    #!/bin/bash
    set -e
    echo "Checking RebasingParityPool token holdings..."

    POOL_ADDRESS=$(jq -r '.contracts.RebasingParityPool' ui/src/deployments/deployments-localhost.json)
    echo "Pool address: $POOL_ADDRESS"
    echo ""

    # Get ETH balance in pool
    ETH_BALANCE_WEI=$(cast call $POOL_ADDRESS "poolETHBalance()" --rpc-url http://localhost:8545)
    ETH_BALANCE=$(cast --from-wei $ETH_BALANCE_WEI eth)

    # Get stETH balance in pool
    STETH_BALANCE_WEI=$(cast call $POOL_ADDRESS "poolStETHBalance()" --rpc-url http://localhost:8545)
    STETH_BALANCE=$(cast --from-wei $STETH_BALANCE_WEI eth)

    # Get total liquidity
    TOTAL_LIQ_WEI=$(cast call $POOL_ADDRESS "totalLiquidity()" --rpc-url http://localhost:8545)
    TOTAL_LIQ=$(cast --from-wei $TOTAL_LIQ_WEI eth)

    # Get accumulated fees
    FEES_DATA=$(cast call $POOL_ADDRESS "getTotalAccumulatedFees()" --rpc-url http://localhost:8545)
    FEES0_WEI=$(echo $FEES_DATA | cut -d' ' -f1)
    FEES1_WEI=$(echo $FEES_DATA | cut -d' ' -f2)
    FEES0=$(cast --from-wei $FEES0_WEI eth)
    FEES1=$(cast --from-wei $FEES1_WEI eth)

    echo "📊 Pool Token Holdings:"
    echo "  ETH Balance:    $ETH_BALANCE ETH"
    echo "  stETH Balance:  $STETH_BALANCE stETH"
    echo "  Total Liquidity: $TOTAL_LIQ ETH equivalent"
    echo ""
    echo "💰 Accumulated Fees:"
    echo "  ETH Fees:       $FEES0 ETH"
    echo "  stETH Fees:     $FEES1 stETH"

# Swap ETH for stETH via Universal Router
swap-eth-to-steth AMOUNT="0.01":
    #!/bin/bash
    STETH_ADDRESS=$(jq -r '.contracts.StETH' ui/src/deployments/deployments-localhost.json)
    HOOKS=$(jq -r '.contracts.RebasingParityPool' ui/src/deployments/deployments-localhost.json)
    AMOUNT_WEI=$(cast --to-wei {{AMOUNT}} eth)

    # V4_SWAP command (0x00) with pool key and swap params
    POOL_KEY="(0x0000000000000000000000000000000000000000,$STETH_ADDRESS,3000,60,$HOOKS)"
    SWAP_PARAMS="(true,$AMOUNT_WEI,0,0x)"
    SWAP_DATA=$(cast abi-encode 'f((address,address,uint24,int24,address),(bool,int256,uint160,bytes))' "$POOL_KEY" "$SWAP_PARAMS")

    cast send 0xef740bf23acae26f6492b10de645d6b98dc8eaf3 "execute(bytes,bytes[])" "0x00" "[$SWAP_DATA]" \
        --value $AMOUNT_WEI \
        --rpc-url http://localhost:8545 \
        --private-key 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

# Run frontend
dev:
    cd ui && bun run dev

# Run tests with coverage report for src/ directory
coverage:
    forge coverage --report summary --report lcov --match-path "src/*" --ir-minimum
    @echo ""
    @echo "📊 Coverage report generated!"
    @echo "📝 View detailed HTML report by running: genhtml lcov.info --output-directory coverage && open coverage/index.html"

# Run tests with coverage and generate HTML report
coverage-html:
    forge coverage --report lcov --match-path "src/*" --ir-minimum
    genhtml lcov.info --output-directory coverage
    @echo "📊 HTML coverage report generated in coverage/ directory"

# create a control flow graph with surya
generate-control-flow:
    surya graph  src/*.sol | dot -Tpng

generate-inheriance-graph:
    surya inheritance src/*.sol | dot -Tpng
