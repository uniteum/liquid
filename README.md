# Liquid

Liquid is a liquidity protocol on Ethereum where liquids are ERC-20 tokens with built-in liquidity.

## Overview

- **Built-in Liquidity**

For comprehensive documentation, see [CLAUDE.md](CLAUDE.md).

## Quick Start

```bash
# Clone and install
git clone git@github.com:uniteum/liquid.git
cd liquid

# Build
forge build

# Test
forge test
```

## Environment Setup

### Environment Variables

Set these in your `.bashrc` or `.zshrc`:

```bash
# Required for deployment (keep secure!)
export tx_key=<YOUR_PRIVATE_WALLET_KEY>
export ETHERSCAN_API_KEY=<YOUR_ETHERSCAN_API_KEY>

# Chain selection (optional)
export chain=11155111  # Sepolia testnet
# export chain=1       # Ethereum mainnet
# export chain=8453    # Base
# export chain=137     # Polygon
```

Get your ETHERSCAN_API_KEY at [Etherscan](https://etherscan.io/myaccount).

## Development

### Build

```bash
forge build
```

### Test

```bash
# Run all tests
forge test

# Run specific test
forge test --match-test testForgeSimple

# Run with gas report
forge test --gas-report

# Run with verbosity
forge test -vvv
```

### Format

```bash
forge fmt
```

### Gas Snapshots

```bash
forge snapshot
```

## Deployment

### Deploy to Testnet (Sepolia)

```bash
chain=11155111
forge script script/Liquid.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
```

## Documentation

- [CLAUDE.md](CLAUDE.md) - Comprehensive protocol documentation
- [Foundry Book](https://book.getfoundry.sh/) - Foundry development framework

## Security

This codebase uses:
- Solidity 0.8.30+ with built-in overflow checks
- EIP-1153 transient storage for reentrancy protection
- Deterministic CREATE2 deployments

See [CLAUDE.md](CLAUDE.md) for detailed security considerations.
