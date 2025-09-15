# Makefile for v4-constant-sum project

# Variables
INFURA_KEY = 4656866d4b76456fb395cd6c1b744830
FORK_URL = https://arbitrum-mainnet.infura.io/v3/$(INFURA_KEY)
CHAIN_ID = 1337

# Default target
.PHONY: help
help:
	@echo "Available commands:"
	@echo "  make dev         - 🚀 Deploy everything in one command (recommended)"
	@echo "  make anvil       - Run local Anvil instance with Arbitrum fork"
	@echo "  make test        - Run all tests"
	@echo "  make test-v      - Run tests with verbose output"
	@echo "  make build       - Build the project"
	@echo "  make clean       - Clean build artifacts"
	@echo "  make deploy      - Deploy contracts to local anvil"
	@echo "  make stop        - Stop all anvil processes"

# Run Anvil with Arbitrum fork
.PHONY: anvil
anvil:
	anvil --fork-url $(FORK_URL) -vvvv --chain-id $(CHAIN_ID)

# Run tests
.PHONY: test
test:
	forge test

# Run tests with verbose output
.PHONY: test-v
test-v:
	forge test -vvv

# Build the project
.PHONY: build
build:
	forge build

# Clean build artifacts
.PHONY: clean
clean:
	forge clean

# 🚀 One-command deployment (recommended)
.PHONY: dev
dev:
	./deploy.sh

# Deploy to local anvil (manual)
.PHONY: deploy
deploy:
	forge script script/Anvil.s.sol --broadcast --rpc-url http://localhost:8545 --private-key 0x59c6995e998f97a5a0044966f0945389dc9e86dae88c7a8412f4603b6b78690d

# Stop all anvil processes
.PHONY: stop
stop:
	pkill -f "anvil.*fork-url" || true

# Install dependencies
.PHONY: install
install:
	forge install

# Update dependencies
.PHONY: update
update:
	forge update

# Format code
.PHONY: fmt
fmt:
	forge fmt

# Check formatting
.PHONY: fmt-check
fmt-check:
	forge fmt --check

# Gas snapshot
.PHONY: snapshot
snapshot:
	forge snapshot

# Coverage report
.PHONY: coverage
coverage:
	forge coverage

# Run slither static analysis
.PHONY: slither
slither:
	slither . --config-file slither.config.json

# Run specific test file
.PHONY: test-file
test-file:
	@echo "Usage: make test-file FILE=<test-file-name>"
	@echo "Example: make test-file FILE=ParityPool"
	forge test --match-path test/$(FILE).t.sol -vvv

# Run specific test function
.PHONY: test-fn
test-fn:
	@echo "Usage: make test-fn FN=<function-name>"
	@echo "Example: make test-fn FN=test_swap"
	forge test --match-test $(FN) -vvv