#!/bin/bash

echo "📦 Extracting ABIs..."

# Create abis directory
mkdir -p frontend-package/abis

# Build contracts first
forge build

# Extract ABIs
echo "Extracting Orderbook ABI..."
jq '.abi' out/Orderbook.sol/Orderbook.json > frontend-package/abis/Orderbook.json

echo "Extracting LendingPool ABI..."
jq '.abi' out/LendingPool.sol/LendingPool.json > frontend-package/abis/LendingPool.json

echo "Creating ERC20 ABI..."
cat > frontend-package/abis/ERC20.json << 'EOF'
[
  {
    "constant": true,
    "inputs": [{"name": "_owner", "type": "address"}],
    "name": "balanceOf",
    "outputs": [{"name": "balance", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": false,
    "inputs": [
      {"name": "_spender", "type": "address"},
      {"name": "_value", "type": "uint256"}
    ],
    "name": "approve",
    "outputs": [{"name": "", "type": "bool"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [
      {"name": "_owner", "type": "address"},
      {"name": "_spender", "type": "address"}
    ],
    "name": "allowance",
    "outputs": [{"name": "", "type": "uint256"}],
    "type": "function"
  },
  {
    "constant": true,
    "inputs": [],
    "name": "decimals",
    "outputs": [{"name": "", "type": "uint8"}],
    "type": "function"
  }
]
EOF

echo "✅ ABIs exported to frontend-package/abis/"
echo ""
echo "Files created:"
echo "  - Orderbook.json"
echo "  - LendingPool.json"
echo "  - ERC20.json"