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
- Keep total length under 650 lines (currently ~641 lines)
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

- **Ice/Substance** = External ERC-20 backing token (state variable: `substance`)
- **Solid** = Backing token amount (parameter: `solid`)
- **Liquid** = Wrapped ERC-20 with AMM liquidity (parameter: `liquid`)
- **Fluids** = Variable name for other liquid amounts in cross-swaps
- **Hub** = Base Liquid instance used for cross-pool swaps
- **Pool** = Liquid tokens held by contract
- **Reserve** = Hub tokens held by contract
- **Mass** = Backing token balance held by contract

### Key File

**[src/Liquid.sol](src/Liquid.sol)** (189 lines) - Single contract implementing entire protocol

## Core Operations

### 1. Heat (Solid → Liquid)

```solidity
function heat(uint256 solid) external nonReentrant
```

**What it does:**
- User deposits `solid` of backing token
- Contract mints `solid` to pool AND `solid` to user (2x mint)
- Result: User owns `solid` liquid tokens, pool grows by `solid`

**Example:**
```solidity
// User has 1000 USDC
usdc.approve(address(liquidUSDC), 1000);
liquidUSDC.heat(1000);
// User now has: 1000 liquid (liquid-USDC)
// Pool now has: 1000 liquid (liquid-USDC)
```

### 2. Cool (Liquid → Solid)

```solidity
function cool(uint256 liquid) external nonReentrant returns (uint256 solid)
```

**What it does:**
- Burns liquid proportionally from both user and pool
- Returns backing tokens based on: `liquid * (backing_balance / user_held_liquid)`
- Burns total of `2 * liquid` (maintaining symmetry with heat)

**Formula:**
```solidity
ours = 2 * liquid * pool / totalSupply   // pool burn
mine = 2 * liquid * held / totalSupply   // user burn
solid = liquid * mass() / held           // backing tokens returned
```

### 3. Sell (Liquid → Hub)

```solidity
function sell(uint256 liquid) external returns (uint256 hub)
```

**Constant Product Formula:**
```solidity
// Invariant: pool * reserve = k
filled = pool + liquid
drained = pool * reserve / filled
hub = reserve - drained
```

**What it does:**
- Calculates hub received for selling `liquid` to pool
- Transfers liquid from user to pool
- Transfers hub from pool's reserve to user

### 4. Buy (Hub → Liquid)

```solidity
function buy(uint256 hub) external returns (uint256 liquid)
```

**Formula:**
```solidity
// Uses sells() with reversed pool/reserve (symmetric formula)
liquid = sells(hub, reserve, pool)
// Which expands to: liquid = pool - pool * reserve / (reserve + hub)
```

**What it does:**
- Buys liquid by spending exactly `hub` amount
- Transfers hub from user to pool's reserve
- Transfers liquid from pool to user

### 5. Cross-Liquid Swaps

```solidity
function sell(uint256 liquid, Liquid fluid) external
    returns (uint256 hub, uint256 fluids)
function buy(uint256 liquid, Liquid fluid) external
    returns (uint256 hub, uint256 fluids)
```

**What it does:**
- Swaps between two different Liquid pools using hub as intermediary
- `sell(liquid, fluid)`: Sell `liquid` from this pool, buy from `fluid` pool
- `buy(liquid, fluid)`: Buy `liquid` from `fluid` pool, sell to this pool
- Example: Sell liquid-USDC to buy liquid-DAI in single transaction
- Both pools maintain their AMM invariants

## Factory Pattern

### Creating New Liquids

```solidity
function liquify(IERC20Metadata stuff) public returns (Liquid fluid)
```

**How it works:**
- Uses CREATE2 with `bytes32(uint160(address(stuff)))` as salt
- Same backing token always produces same Liquid address
- Uses EIP-1167 minimal proxy (OpenZeppelin Clones)
- Only callable from main HUB instance

**Example:**
```solidity
IERC20Metadata usdc = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
Liquid liquidUSDC = hub.liquify(usdc);
// liquidUSDC address is deterministic based on USDC address
```

### Convenience: Create and Heat in One Call

```solidity
function liquify(uint256 solid, IERC20Metadata stuff) external
```

**What it does:**
- Creates new liquid for `stuff` (if doesn't exist)
- Heats `solid` amount into that liquid
- Transfers the resulting liquid tokens to msg.sender

**Example:**
```solidity
// Create liquid-USDC and heat 1000 USDC in one transaction
usdc.approve(address(hub), 1000);
hub.liquify(1000, usdc);
// Creates liquidUSDC if needed, heats 1000, sends liquid tokens to msg.sender
```

## Architecture

### Contract Structure

```solidity
contract Liquid is ERC20, ReentrancyGuardTransient {
    Liquid public immutable HUB = this;
    IERC20Metadata public substance;  // Backing token
}
```

### State Variables

- `HUB` - Immutable self-reference (main instance for factory)
- `substance` - The backing ERC-20 token for this Liquid

### Key Functions

**Balance Queries:**
- `pool()` - Returns liquid tokens held by contract
- `reserve()` - Returns hub tokens held by contract
- `mass()` - Returns backing tokens held by contract
- `update()` - Internal token transfer (callable only by other Liquids)

**Access Control:**
- `onlyLiquid` modifier - Ensures caller is registered Liquid instance
- Protects `bought()`, `sold()`, `update()` from external manipulation

## Mathematical Invariants

### 1. Constant Product AMM

```
pool * reserve = k  (constant before and after trades)
```

### 2. Heat/Cool Symmetry

```
Total minted in heat = 2 * solid
Total burned in cool = 2 * liquid
```

### 3. Backing Token Conservation

```
substance.balanceOf(address(liquid)) = sum of all heated solid - sum of all cooled solid
```

## Security

### Reentrancy Protection

```solidity
modifier nonReentrant() {
    // Uses EIP-1153 transient storage
    // from OpenZeppelin ReentrancyGuardTransient
}
```

- All state-changing functions use `nonReentrant`
- Transient storage clears after transaction
- Protects against malicious ERC-20 callbacks

### Access Control

```solidity
modifier onlyLiquid() {
    Liquid fluid = Liquid(msg.sender);
    (address predicted,) = HUB.liquified(fluid.substance());
    if (msg.sender != predicted) {
        revert Unauthorized();
    }
    _;
}
```

- Only registered Liquid instances can call cross-pool functions
- Validates caller by checking predicted CREATE2 address
- Applied to: `bought()`, `sold()`, `update()`

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
    Liquid public H;    // Hub
    Liquid public U;    // First liquid
    Liquid public V;    // Second liquid
    LiquidUser public owen;  // Test users
    LiquidUser public alex;
    LiquidUser public beck;

    function setUp() public virtual override {
        super.setUp();
        owen = newUser("owen");
        H = new Liquid(owen.newToken("H", 1e9));
        owen.heat(H, 1e9);
        U = H.liquify(owen.newToken("U", 1e9));
        V = H.liquify(owen.newToken("V", 1e9));
    }
}
```

### Test User Pattern

```solidity
contract LiquidUser is User {
    function heat(Liquid U, uint256 solid) public { }
    function cool(Liquid U, uint256 liquid) public returns (uint256 solid) { }
    function sell(Liquid U, uint256 liquid) public returns (uint256 hub) { }
    function liquidate(Liquid U) public returns (uint256 liquid, uint256 solid) { }
}
```

**LiquidUser** wraps operations with automatic logging and balance tracking.

### Example Test

```solidity
function test_HeatCool() public returns (uint256 liquid, uint256 solid) {
    giveaway();                        // Distribute tokens to users
    owen.heat(U, 500);
    alex.heat(U, 500);
    beck.heat(U, 500);

    liquid = 100;
    solid = alex.cool(U, liquid);
    assertEq(liquid, solid, "alex liquid != solid");

    // Full liquidation
    (liquid, solid) = alex.liquidate(U);
    assertEq(liquid, solid, "alex liquid != solid");
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

```bash
chain=11155111
forge script script/Ice.s.sol \
  -f $chain \
  --private-key $tx_key \
  --broadcast \
  --verify \
  --delay 10 \
  --retries 10
```

Note: Ice.s.sol deploys the initial HUB token which serves as the base hub instance.

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
Liquid liquidDAI = hub.liquify(dai);
```

### Adding Liquidity

```solidity
// User deposits backing token (solid)
dai.approve(address(liquidDAI), 1000 ether);
liquidDAI.heat(1000 ether);
// User receives 1000 liquid (liquid-DAI), pool grows by 1000
```

### Removing Liquidity

```solidity
// User withdraws backing token (solid)
uint256 solid = liquidDAI.cool(500 ether);
// User receives DAI, burns liquid (liquid-DAI) from self and pool
```

### Trading

```solidity
// Buy liquid with hub
uint256 liquid = liquidDAI.buy(100 ether);  // Spend 100 hub, receive liquid

// Sell liquid for hub
uint256 hub = liquidDAI.sell(50 ether);   // Sell 50 liquid, receive hub

// Cross-liquid swap
(uint256 hub, uint256 fluids) = liquidDAI.sell(100 ether, liquidUSDC);
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
event Heat(Liquid indexed fluid, uint256 solid);
event Cool(Liquid indexed fluid, uint256 liquid, uint256 solid);
event Buy(Liquid indexed fluid, uint256 liquid, uint256 hub);
event Sell(Liquid indexed fluid, uint256 liquid, uint256 hub);
event Liquify(IERC20Metadata indexed substance, Liquid indexed fluid);
```

## Errors

```solidity
error Nothing();        // Zero address token
error Unauthorized();   // Non-liquid caller
```

## Quick Reference

### Pool State Queries

```solidity
uint256 pool = liquid.pool();              // Pool liquid balance
uint256 reserve = liquid.reserve();        // Pool hub balance
uint256 mass = liquid.mass();              // Backing token balance
```

### Quote Functions

```solidity
uint256 hub = liquid.sells(50 ether);                       // Hub from selling liquid
uint256 liquid = liquid.buys(100 ether);                    // Liquid from buying with hub
(uint256 hub, uint256 fluids) = liquid.sells(50 ether, otherLiquid);   // Cross-swap quote
(uint256 hub, uint256 liquid) = liquid.buys(100 ether, otherLiquid);   // Cross-swap quote
```

### Metadata

```solidity
string memory name = liquid.name();              // From backing token
string memory symbol = liquid.symbol();          // From backing token
uint8 decimals = liquid.decimals();              // From backing token
IERC20Metadata backing = liquid.substance();     // Get backing token
```

---

*This document is optimized for AI-assisted development. For human-readable introduction, see [README.md](README.md).*
