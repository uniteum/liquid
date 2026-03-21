# CLAUDE.md - Liquid Protocol

> Context guide for AI-assisted development of the Liquid protocol.

## Meta: Maintaining This Document

### Purpose
This file provides context for AI assistants (primarily Claude) to understand the Liquid protocol codebase. It is optimized for token efficiency and accuracy.

### When to Update

**Update IMMEDIATELY when:**
- User provides feedback contradicting this documentation
- Core protocol mechanics change (formulas, operations, invariants)
- New functions or contracts are added
- File structure changes significantly
- Test patterns or development workflows change

**Update PROACTIVELY when:**
- You discover inaccuracies while working on tasks
- Line counts or file sizes drift significantly from stated values
- Code examples become outdated or incorrect
- Better explanations or examples become apparent

### How to Update

**Optimization Guidelines:**
- Keep total length under 650 lines (currently ~611 lines)
- Prioritize formulas, patterns, and non-obvious mechanics
- Remove redundant explanations
- Use concise code examples over prose
- Reference other docs instead of duplicating content
- Update line counts when files change significantly (>10% drift)

**What to Include:**
- Core operations with exact formulas
- Non-obvious architectural patterns (CREATE2, factory, etc.)
- Common pitfalls or gotchas
- Test patterns that save time
- Quick reference for frequent operations

**What to Exclude:**
- Standard Solidity/Foundry knowledge
- Extensive background on ERC-20, AMMs, etc.
- Detailed explanations available in official docs
- Verbose examples when concise ones suffice

### Validation Process

**Before finalizing updates:**
1. Verify formulas against actual code in [src/Liquid.sol](src/Liquid.sol)
2. Check that line counts are approximately correct
3. Test code examples compile/run if they've changed
4. Ensure Quick Reference section remains accurate
5. Confirm total length stays token-efficient

### Related Documentation Files

- [README.md](README.md) - User-facing introduction
- [foundry.toml](foundry.toml) - Build configuration (authoritative source)
- [src/Liquid.sol](src/Liquid.sol) - Source of truth for all mechanics

**If user feedback conflicts with CLAUDE.md:** Update this file to reflect reality, then confirm the change with the user.

## Overview

**Liquid** is a constant-product AMM protocol on Ethereum where any ERC-20 token can be wrapped into a "liquid" token with built-in liquidity.

### Core Metaphor

- **Solid** = Backing token
- **Liquid** = Wrapped token with AMM liquidity
- **Hub** = Central Liquid token (wraps "Uniteum 1", symbol "1") used for cross-pool swaps
- **Spoke** = Liquid token paired with Hub token forming a liquidity pool
- **Mass** = Solid backing tokens held by contract
- **Pool** = Spoke tokens held by contract
- **Lake** = Hub tokens held by contract
- **Fluid** = Name of other liquid in cross-swaps

Note that token amounts are specified by lowercasing and pluralizing the corresponding token: solids, liquids, hubs, spokes, fluids.

### Key File

**[src/Liquid.sol](src/Liquid.sol)** (~197 lines) - Single contract implementing entire protocol

## Core Operations

### 1. Heat (Solid → Liquid)

```solidity
function heat(uint256 m, uint256 e) external returns (uint256 u, uint256 p)
```

**What it does:**
- User deposits `m` solid tokens and optionally `e` hub tokens
- Contract mints liquid tokens split between the pool and user to preserve the P/T ratio
- When `e = 0`: mints `2m` liquid, split by current P/T ratio (u + p = 2m)
- When `e > 0`: hub tokens augment the effective mass; the P/T ratio is still preserved

**Example:**
```solidity
// User has 1000 USDC
usdc.approve(address(liquidUSDC), 1000);
liquidUSDC.heat(1000, 0);
// User now has: 1000 liquid (liquid-USDC)
// Pool now has: 1000 liquid (liquid-USDC)
```

### 2. Cool (Liquid → Solid)

```solidity
function cool(uint256 u, uint256 e) external returns (uint256 m, uint256 p)
```

**What it does:**
- Burns liquid proportionally from both user and pool, preserving P/T ratio
- Optionally withdraws `e` hub tokens from the pool's lake
- Returns backing tokens based on formula below
- Burns total of `u + p` from user and pool (maintaining symmetry with heat)

**Formula:**
```solidity
T = totalSupply
P = balanceOf(address(this))  // pool balance
U = T - P                     // unpooled (user-held) liquid
s = u * T / U / 2             // solid returned
p = 2 * s - u                 // pool burn amount
```

### 3. Sell (Liquid → Hub)

```solidity
function sell(uint256 s) external returns (uint256 e)
```

**Constant Product Formula:**
```solidity
(S, E) = pool()              // S = spoke balance, E = hub balance
e = E - (E * S + E - 1) / (S + s)
```

**What it does:**
- Calculates hub received for selling `s` spokes to pool
- Transfers spokes from user to pool
- Transfers hub from pool to user

### 4. Buy (Hub → Liquid)

```solidity
function buy(uint256 e) external returns (uint256 s)
```

**Formula:**
```solidity
(S, E) = pool()              // S = spoke balance, E = hub balance
s = S - (S * E) / (E + e)
```

**What it does:**
- Buys spokes by spending exactly `e` hub tokens
- Transfers hub from user to pool
- Transfers spokes from pool to user

### 5. Cross-Liquid Swaps

```solidity
function sellFor(ILiquid that, uint256 s) external
    returns (uint256 e, uint256 thats)
function sellsFor(ILiquid that, uint256 s) public view
    returns (uint256 e, uint256 thats)
```

**What it does:**
- Swaps between two different Liquid pools using hub as intermediary
- `sellFor(that, spokes)`: Sell `spokes` from this pool, buy from `that` pool
- Example: Sell liquid-USDC to buy liquid-DAI in single transaction
- Both pools maintain their AMM invariants

## Factory Pattern

### Creating New Liquids

```solidity
function make(IERC20Metadata backing) public returns (ILiquid liquid)
function made(IERC20Metadata backing) public view returns (bool cloned, address home, bytes32 salt)
```

**How it works:**
- Uses CREATE2 with `bytes32(uint160(address(backing)))` as salt
- Same backing token always produces same Liquid address
- Uses EIP-1167 minimal proxy (OpenZeppelin Clones)
- Can be called from any Liquid instance (delegates to HUB)
- `made()` returns whether a liquid already exists for the given backing token

**Example:**
```solidity
IERC20Metadata usdc = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
Liquid liquidUSDC = Liquid(address(hub.make(usdc)));
// liquidUSDC address is deterministic based on USDC address
```

## Architecture

### Contract Structure

```solidity
contract Liquid is ILiquid, ERC20, ReentrancyGuardTransient {
    Liquid public immutable HUB = this;
    IERC20Metadata public solid;  // Backing token
}
```

### State Variables

- `HUB` - Immutable self-reference (main instance for factory)
- `solid` - The backing ERC-20 token for this Liquid

### Key Functions

**Balance Queries:**
- `pool()` - Returns `(uint256 P, uint256 E)` where P is spoke balance and E is hub balance
- `mass()` - Returns backing tokens held by contract
- `zzUpdate()` - Internal token transfer (callable only by other Liquids)

**Access Control:**
- `onlyLiquid` modifier - Ensures caller is registered Liquid instance
- Hub operations guarded by `if (this == HUB)` checks within functions
- Protects `_buy()`, `zzUpdate()` from external manipulation

## Mathematical Invariants

### 1. Constant Product AMM

```
P * E = k  (constant before and after trades)
```

### 2. Heat/Cool Symmetry

```
Total minted in heat = 2 * solid (split between user and pool)
Total burned in cool = u + p (from user and pool)
```

### 3. P/T Ratio Preservation

```
P/T before heat/cool = P/T after heat/cool
```

Heat and cool preserve the pool-to-total-supply ratio. They do NOT restore it to 1/2.
Only buy/sell change the P/T ratio. This creates arbitrage opportunities:
- After buy (P/T < 1/2): heating is favorable (u > s)
- After sell (P/T > 1/2): cooling is favorable (s > u)

### 4. Backing Token Conservation

```
solid.balanceOf(address(liquid)) = sum of all heated solid - sum of all cooled solid
```

## Security

### Reentrancy Protection

```solidity
modifier nonReentrant() {
    // Uses EIP-1153 transient storage
    // from OpenZeppelin ReentrancyGuardTransient
}
```

- Applied to `heat` and `cool` (the only functions that call external ERC-20 tokens via `solid.safeTransfer*`)
- `sell`, `buy`, `sellFor` do NOT need `nonReentrant` — they only interact with trusted Liquid instances via `zzUpdate`/`_update`
- Transient storage clears after transaction

### Access Control

```solidity
modifier onlyLiquid() {
    (, address home,) = HUB.made(Liquid(msg.sender).solid());
    if (msg.sender != address(HUB) && msg.sender != home) {
        revert Unauthorized();
    }
    _;
}
```

- Only registered Liquid instances can call cross-pool functions
- Validates caller by checking predicted CREATE2 address
- Applied to: `zzUpdate()`

### Safe Token Handling

```solidity
using SafeERC20 for IERC20Metadata;
```

- All token transfers use SafeERC20
- Handles non-standard ERC-20 implementations
- No raw `transfer()` or `transferFrom()` calls

### Token Approval Requirements

**IMPORTANT:** Token approval is ONLY required for heat operations.

**Requires approval:**
- `heat(solid)` - User must approve liquid contract to spend backing tokens

**NO approval needed (only requires msg.sender ownership):**
- `cool(liquid)` - Burns from msg.sender's balance
- `buy(hub)` - Transfers hub from msg.sender
- `sell(liquid)` - Transfers liquid from msg.sender
- Cross-swaps - Use msg.sender's tokens

The contract uses `transferFrom(msg.sender, ...)` which works directly when msg.sender owns the tokens being transferred.

## Development Workflow

### Build & Test

```bash
forge build          # Compile contracts
forge test           # Run test suite
forge test -vvv      # Verbose output with logs
forge fmt            # Format code
```

### Running Specific Tests

```bash
forge test --match-test test_HeatCool
forge test --match-test test_HeatSellCoolBuy
forge test --match-contract SolidInvariant  # Run invariant tests
```

### Invariant Test Profiles

Invariant tests can be configured for different thoroughness levels:

```bash
# Quick (64 runs, 128 depth) - ~4 seconds
FOUNDRY_PROFILE=quick forge test --match-contract SolidInvariant

# Default (256 runs, 500 depth) - ~170 seconds
forge test --match-contract SolidInvariant

# CI (512 runs, 1000 depth) - thorough testing
FOUNDRY_PROFILE=ci forge test --match-contract SolidInvariant

# Deep (1024 runs, 2000 depth) - very thorough
FOUNDRY_PROFILE=deep forge test --match-contract SolidInvariant
```

**When to use each:**
- `quick` - During active development (fast feedback)
- `default` - Before commits (good coverage)
- `ci` - In CI/CD pipelines
- `deep` - Before production deploys or major releases

### Bash Tool Usage

- **Avoid compound statements** (`; && |`). Use separate, parallel Bash tool calls instead so each command can be individually matched by permission rules.
- Only use compound statements when there's a genuine dependency that can't be expressed otherwise.

### Code Style

**NatSpec:**
- Use `/** */` multi-line block notation (never `///`)
- Always multi-line format even for single-line comments
- Include `@notice` for public descriptions
- Add `@param` and `@return` as needed

**Formatting:**
- Run `forge fmt` before committing
- Follows Foundry's default style guide

### Code Quality & Linting

**CRITICAL: All generated code MUST be lint-free.**

**Pre-commit checklist:**
1. Run `forge fmt` on all modified `.sol` files
2. Verify compilation: `forge build`
3. Run affected tests: `forge test`
4. Check for warnings in compiler output

**Solidity Style Rules:**
- **Function visibility order**: external → public → internal → private
- **Function declaration formatting**: When parameters don't fit on one line:
  ```solidity
  // CORRECT: Multi-line with proper indentation
  function longFunctionName(uint256 param1, uint256 param2)
      public
      returns (uint256 result1, uint256 result2)
  {
      // body
  }

  // WRONG: Single line when too long
  function longFunctionName(uint256 param1, uint256 param2) public returns (uint256 result1, uint256 result2) {
  ```
- **Imports**: One per line, sorted alphabetically
- **Line length**: Max 120 characters (forge fmt default)
- **Indentation**: 4 spaces (configured in foundry.toml)

**Common Linting Fixes:**
- Add blank line before function if missing
- Remove trailing whitespace
- Ensure consistent spacing around operators
- Format multi-line function signatures consistently

**When writing code:**
1. Write the code
2. Mentally verify it follows forge fmt rules
3. If unsure, assume forge fmt will reformat and write cleanly
4. After file operations, expect forge fmt may auto-format

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

    function setUp() public virtual override {
        super.setUp();
        owen = newUser("owen");
        W = new Liquid(owen.newToken("W", SUPPLY));
        owen.heat(W, SUPPLY, 0);
        U = W.make(owen.newToken("U", SUPPLY));
        V = W.make(owen.newToken("V", SUPPLY));
    }
}
```

### Test User Pattern

```solidity
contract LiquidUser is User {
    function heat(ILiquid U, uint256 s, uint256 e) public returns (uint256 u, uint256 p) { }
    function cool(ILiquid U, uint256 u, uint256 e) public returns (uint256 s, uint256 p) { }
    function sell(ILiquid U, uint256 liquid) public returns (uint256 water) { }
    function buy(ILiquid U, uint256 water) public returns (uint256 liquid) { }
    function liquidate(ILiquid U) public returns (uint256 liquid, uint256 solid) { }
}
```

**LiquidUser** wraps operations with automatic logging and balance tracking.

### Example Test

```solidity
function test_FixedHeatCool(uint256 s) public returns (uint256 u, uint256 p) {
    giveAlex();
    owen.heat(U, GIFT, GIFT);          // Create pool with solid and hub
    (uint256 P, uint256 E) = U.pool();
    assertEq(P, 2 * GIFT, "Pool had unexpected U");
    assertEq(E, GIFT, "Pool had unexpected E");

    (u, p) = alex.heat(U, DOLLIP, 0);
    assertEq(u, DOLLIP, "alex liquid != solid");

    // Full liquidation
    (u, s) = alex.liquidate(U);
    assertEq(u, s, "alex liquid != solid");
}
```

## Deployment

### Environment Variables

```bash
export tx_key=<YOUR_PRIVATE_WALLET_KEY>
export ETHERSCAN_API_KEY=<YOUR_ETHERSCAN_API_KEY>
export chain=11155111  # Sepolia testnet
```

### Deploy Script

### Supported Networks

See [foundry.toml](foundry.toml) for full chain configuration:
- Ethereum (1, 11155111)
- Arbitrum (42161, 421614)
- Base (8453, 84532)
- Optimism (10, 11155420)
- Polygon (137, 80002)
- BNB Chain (56, 97)

## Configuration

### Solidity Settings

From [foundry.toml](foundry.toml):

```toml
solc = "0.8.30"           # Required for EIP-1153
evm_version = "cancun"
optimizer = true
optimizer_runs = 200
via_ir = true
bytecode_hash = "none"
cbor_metadata = false
always_use_create_2_factory = true
```

**Key Requirements:**
- Solidity 0.8.30+ for transient storage (EIP-1153)
- Cancun EVM for latest features
- CREATE2 for deterministic deployments

## Common Operations

### Creating a New Liquid

```solidity
// From hub instance
IERC20Metadata dai = IERC20Metadata(0x6B175474E89094C44Da98b954EedeAC495271d0F);
ILiquid liquidDAI = hub.make(dai);
```

### Adding Liquidity

```solidity
// User deposits backing token (solid)
dai.approve(address(liquidDAI), 1000 ether);
(uint256 u, uint256 p) = liquidDAI.heat(1000 ether, 0);
// User receives u liquid tokens, pool grows by p tokens
```

### Removing Liquidity

```solidity
// User withdraws backing token (solid)
(uint256 solid, uint256 poolBurn) = liquidDAI.cool(500 ether, 0);
// User receives DAI, burns liquid from self (500) and pool (poolBurn)
```

### Trading

```solidity
// Buy liquid with hub
uint256 spokes = liquidDAI.buy(100 ether);  // Spend 100 hub, receive spokes

// Sell liquid for hub
uint256 hubs = liquidDAI.sell(50 ether);   // Sell 50 spokes, receive hub

// Cross-liquid swap
(uint256 hubs, uint256 thats) = liquidDAI.sellFor(liquidUSDC, 100 ether);
```

## Key Differences from Unit Protocol

**This is NOT the algebraic Unit protocol described in previous documentation:**

❌ No algebraic composition (kg*m/s^2)
❌ No rational exponents
❌ No symbolic algebra
❌ No reciprocal relationships with geometric mean
❌ No forge operations with three-way relationships

✅ Simple constant-product AMM
✅ Single token wrapping
✅ Standard liquidity pool mechanics
✅ Cross-pool swaps via hub intermediary

## Reference Documentation

- **[README.md](README.md)** - Quick start guide
- **[foundry.toml](foundry.toml)** - Build configuration
- **[Foundry Book](https://book.getfoundry.sh/)** - Foundry framework docs
- **[OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)** - Dependency docs

## Events

```solidity
event Heat(ILiquid indexed liquid, uint256 m, uint256 e, uint256 u, uint256 p);
event Cool(ILiquid indexed liquid, uint256 u, uint256 e, uint256 m, uint256 p);
event Buy(ILiquid indexed liquid, uint256 s, uint256 e);
event Sell(ILiquid indexed liquid, uint256 s, uint256 e);
event Make(ILiquid indexed liquid, IERC20Metadata indexed solid);
```

## Errors

```solidity
error Nothing();        // Zero address token
error Unauthorized();   // Non-liquid caller
```

## Quick Reference

### Pool State Queries

```solidity
(uint256 P, uint256 E) = liquid.pool();    // P = spoke balance, E = hub balance
uint256 mass = liquid.mass();              // Backing token balance
```

### Quote Functions

```solidity
uint256 hubs = liquid.sells(50 ether);                         // Hub from selling spokes
uint256 spokes = liquid.buys(100 ether);                       // Spokes from buying with hub
(uint256 hubs, uint256 thats) = liquid.sellsFor(other, 50 ether);  // Cross-swap quote
```

### Metadata

```solidity
string memory name = liquid.name();              // From backing token
string memory symbol = liquid.symbol();          // backing symbol + "_L"
uint8 decimals = liquid.decimals();              // From backing token
IERC20Metadata backing = liquid.solid();         // Get backing token
```

---

*This document is optimized for AI-assisted development. For human-readable introduction, see [README.md](README.md).*
