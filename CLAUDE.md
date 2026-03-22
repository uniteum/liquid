# CLAUDE.md - Liquid Protocol

> Context guide for AI-assisted development. Read [src/Liquid.sol](src/Liquid.sol) (~197 lines) for implementation details — it's short enough to read directly.

## Domain Vocabulary

These terms are used throughout the codebase and are not obvious from code alone:

- **Solid** = Backing token
- **Liquid** = Wrapped token with AMM liquidity
- **Hub** = Central Liquid token (wraps "Uniteum 1", symbol "1") used for cross-pool swaps
- **Spoke** = Liquid token paired with Hub token forming a liquidity pool
- **Mass** = Solid backing tokens held by contract
- **Pool** = Spoke tokens held by contract
- **Lake** = Hub tokens held by contract
- **Fluid** = Name of other liquid in cross-swaps

Token amounts are specified by lowercasing and pluralizing: solids, liquids, hubs, spokes, fluids.

## Non-Obvious Mechanics

### P/T Ratio Preservation

Heat and cool preserve the pool-to-total-supply ratio (P/T). They do NOT restore it to 1/2.
Only buy/sell change the P/T ratio. This creates arbitrage opportunities:
- After buy (P/T < 1/2): heating is favorable (u > s)
- After sell (P/T > 1/2): cooling is favorable (s > u)

### Token Approval

Approval is ONLY required for `heat` (solid → liquid). All other operations (`cool`, `buy`, `sell`, cross-swaps) use `transferFrom(msg.sender, ...)` or `_burn(msg.sender, ...)` directly.

### Reentrancy

- `nonReentrant` is on `heat` and `cool` only (they call external ERC-20s via `solid.safeTransfer*`)
- `sell`, `buy`, `sellFor` don't need it — they only interact with trusted Liquid instances

## Key Differences from Unit Protocol

**This is NOT the algebraic Unit protocol described in previous documentation.** No algebraic composition, rational exponents, symbolic algebra, reciprocal relationships, or forge operations. This is a simple constant-product AMM with single token wrapping and cross-pool swaps via hub intermediary.

## Development Workflow

```bash
forge build          # Compile
forge test           # Run tests
forge test -vvv      # Verbose
forge fmt            # Format
```

### Bash Tool Usage

- **Avoid compound statements** (`; && |`). Use separate, parallel Bash tool calls instead so each command can be individually matched by permission rules.
- Only use compound statements when there's a genuine dependency that can't be expressed otherwise.

## Test Patterns

### Base Test Setup

```solidity
contract LiquidTest is BaseTest {
    ILiquid public W;   // Hub (Water)
    ILiquid public U;   // First liquid
    ILiquid public V;   // Second liquid
    LiquidUser public owen;  // Test users
    LiquidUser public alex;
    LiquidUser public beck;
}
```

**LiquidUser** wraps operations with automatic logging and balance tracking. Always use LiquidUser methods (`owen.heat(U, ...)`) rather than calling contracts directly.

## Deployment

### Environment Variables

```bash
export tx_key=<YOUR_PRIVATE_WALLET_KEY>
export ETHERSCAN_API_KEY=<YOUR_ETHERSCAN_API_KEY>
export chain=11155111  # Sepolia testnet
```

### Supported Networks

See [foundry.toml](foundry.toml) for full chain configuration:
Ethereum, Arbitrum, Base, Optimism, Polygon, BNB Chain (mainnets and testnets).

## Reference Documentation

- [README.md](README.md) - User-facing introduction
- [foundry.toml](foundry.toml) - Build configuration (authoritative)
- [src/Liquid.sol](src/Liquid.sol) - Source of truth for all mechanics
