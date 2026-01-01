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
- Keep total length under 600 lines (currently ~596 lines)
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

- **Ice/Solid/Cold** = External ERC-20 backing token (variable: `cold`)
- **Liquid/Hot** = Wrapped ERC-20 with AMM liquidity (variable: `hot`)
- **Hotter** = Variable name for other liquid amounts in cross-swaps
- **Water** = Base Liquid instance used for cross-pool swaps
- **Pool** = Liquid tokens held by contract
- **Lake** = Water tokens held by contract

### Key File

**[src/Liquid.sol](src/Liquid.sol)** (238 lines) - Single contract implementing entire protocol

## Core Operations

### 1. Heat (Cold → Hot)

```solidity
function heat(uint256 cold) external nonReentrant
```

**What it does:**
- User deposits `cold` of backing token
- Contract mints `cold` to pool AND `cold` to user (2x mint)
- Result: User owns `cold` hot tokens, pool grows by `cold`

**Example:**
```solidity
// User has 1000 USDC
usdc.approve(address(liquidUSDC), 1000);
liquidUSDC.heat(1000);
// User now has: 1000 hot (liquid-USDC)
// Pool now has: 1000 hot (liquid-USDC)
```

### 2. Cool (Hot → Cold)

```solidity
function cool(uint256 hot) external nonReentrant returns (uint256 cold)
```

**What it does:**
- Burns hot proportionally from both user and pool
- Returns backing tokens based on: `hot * (backing_balance / user_held_hot)`
- Burns total of `2 * hot` (maintaining symmetry with heat)

**Formula:**
```solidity
ours = 2 * hot * pool / totalSupply      // pool burn
mine = 2 * hot * held / totalSupply      // user burn
cold = hot * solid.balanceOf(address(this)) / held
```

### 3. Buy (Water → Hot)

```solidity
function buy(uint256 hot) external returns (uint256 water)
```

**Constant Product Formula:**
```solidity
// Invariant: pool * lake = k
drained = pool - hot
filled = pool * lake / drained
water = filled - lake
```

**What it does:**
- Calculates water cost for buying `hot` from pool
- Transfers water from user to pool's lake
- Transfers hot from pool to user

### 4. Sell (Hot → Water)

```solidity
function sell(uint256 hot) external returns (uint256 water)
```

**Formula:**
```solidity
filled = pool + hot
drained = pool * lake / filled
water = lake - drained
```

**What it does:**
- Calculates water received for selling `hot` to pool
- Transfers hot from user to pool
- Transfers water from pool's lake to user

### 5. BuyWith (Water → Hot, specifying water amount)

```solidity
function buyWith(uint256 water) external returns (uint256 hot)
```

**What it does:**
- Buys hot by spending exactly `water` amount
- Inverse of `buy(hot)` - you specify water input instead of hot output

### 6. SellFor (Hot → Water, specifying water amount)

```solidity
function sellFor(uint256 water) external returns (uint256 hot)
```

**What it does:**
- Sells hot to receive exactly `water` amount
- Inverse of `sell(hot)` - you specify water output instead of hot input

### 7. Cross-Liquid Swaps

```solidity
function buy(uint256 hot, Liquid other) external
    returns (uint256 water, uint256 hotter)
function sell(uint256 hot, Liquid other) external
    returns (uint256 water, uint256 hotter)
function buyWith(uint256 hotter, Liquid other) external
    returns (uint256 water, uint256 hot)
function sellFor(uint256 hotter, Liquid other) external
    returns (uint256 water, uint256 hot)
```

**What it does:**
- Swaps between two different Liquid pools using water as intermediary
- Example: Swap liquid-USDC for liquid-DAI in single transaction
- Both pools maintain their AMM invariants
- Four variants for different use cases (specify input/output on either side)

## Factory Pattern

### Creating New Liquids

```solidity
function heat(IERC20Metadata stuff) public returns (Liquid liquid)
```

**How it works:**
- Uses CREATE2 with `bytes32(uint160(address(stuff)))` as salt
- Same backing token always produces same Liquid address
- Uses EIP-1167 minimal proxy (OpenZeppelin Clones)
- Only callable from main WATER instance

**Example:**
```solidity
IERC20Metadata usdc = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
Liquid liquidUSDC = water.heat(usdc);
// liquidUSDC address is deterministic based on USDC address
```

### Convenience: Create and Heat in One Call

```solidity
function heat(uint256 cold, IERC20Metadata stuff) external
```

**What it does:**
- Creates new liquid for `stuff` (if doesn't exist)
- Heats `cold` amount into that liquid
- Transfers the resulting hot tokens to msg.sender

**Example:**
```solidity
// Create liquid-USDC and heat 1000 USDC in one transaction
usdc.approve(address(water), 1000);
water.heat(1000, usdc);
// Creates liquidUSDC if needed, heats 1000, sends hot tokens to msg.sender
```

## Architecture

### Contract Structure

```solidity
contract Liquid is ERC20, ReentrancyGuardTransient {
    Liquid public immutable WATER = this;
    IERC20Metadata public solid;  // Backing token
}
```

### State Variables

- `WATER` - Immutable self-reference (main instance for factory)
- `solid` - The backing ERC-20 token for this Liquid

### Key Functions

**Internal Accounting:**
- `balances()` - Returns `(pool, lake)` balances
- `update()` - Internal token transfer (callable only by other Liquids)

**Access Control:**
- `onlyLiquid` modifier - Ensures caller is registered Liquid instance
- Protects `bought()`, `sold()`, `update()` from external manipulation

## Mathematical Invariants

### 1. Constant Product AMM

```
pool * lake = k  (constant before and after trades)
```

### 2. Heat/Cool Symmetry

```
Total minted in heat = 2 * cold
Total burned in cool = 2 * hot
```

### 3. Backing Token Conservation

```
solid.balanceOf(address(liquid)) = sum of all heated cold - sum of all cooled cold
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
    Liquid liquid = Liquid(msg.sender);
    (address predicted,) = WATER.heated(liquid.solid());
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
- `heat(cold)` - User must approve liquid contract to spend backing tokens

**NO approval needed (only requires msg.sender ownership):**
- `cool(hot)` - Burns from msg.sender's balance
- `buy(hot)` - Transfers water from msg.sender
- `sell(hot)` - Transfers hot from msg.sender
- `buy(hot, other)` - Cross-swap using msg.sender's hot

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
```

### Code Style

**NatSpec:**
- Use `/** */` multi-line block notation (never `///`)
- Always multi-line format even for single-line comments
- Include `@notice` for public descriptions
- Add `@param` and `@return` as needed

**Formatting:**
- Run `forge fmt` before committing
- Follows Foundry's default style guide

## Test Patterns

### Base Test Setup

```solidity
contract LiquidTest is BaseTest {
    Liquid public W;    // Water
    Liquid public U;    // First liquid
    Liquid public V;    // Second liquid
    LiquidUser public owen;  // Test users
    LiquidUser public alex;
    LiquidUser public beck;

    function setUp() public virtual override {
        super.setUp();
        owen = newUser("owen");
        W = new Liquid(owen.newToken("W", 1e9));
        owen.heat(W, 1e9);
        U = W.heat(owen.newToken("U", 1e9));
        V = W.heat(owen.newToken("V", 1e9));
    }
}
```

### Test User Pattern

```solidity
contract LiquidUser is User {
    function heat(Liquid U, uint256 cold) public { }
    function cool(Liquid U, uint256 hot) public returns (uint256 cold) { }
    function sell(Liquid U, uint256 hot) public returns (uint256 water) { }
    function liquidate(Liquid U) public returns (uint256 hot, uint256 cold) { }
}
```

**LiquidUser** wraps operations with automatic logging and balance tracking.

### Example Test

```solidity
function test_HeatCool() public returns (uint256 hot, uint256 cold) {
    giveaway();                        // Distribute tokens to users
    owen.heat(U, 500);
    alex.heat(U, 500);
    beck.heat(U, 500);

    hot = 100;
    cold = alex.cool(U, hot);
    assertEq(hot, cold, "alex hot != cold");

    // Full liquidation
    (hot, cold) = alex.liquidate(U);
    assertEq(hot, cold, "alex hot != cold");
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

Note: Ice.s.sol deploys the initial WATAR token which serves as the base water instance.

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
// From water instance
IERC20Metadata dai = IERC20Metadata(0x6B175474E89094C44Da98b954EedeAC495271d0F);
Liquid liquidDAI = water.heat(dai);
```

### Adding Liquidity

```solidity
// User deposits backing token (cold)
dai.approve(address(liquidDAI), 1000 ether);
liquidDAI.heat(1000 ether);
// User receives 1000 hot (liquid-DAI), pool grows by 1000
```

### Removing Liquidity

```solidity
// User withdraws backing token (cold)
uint256 cold = liquidDAI.cool(500 ether);
// User receives DAI, burns hot (liquid-DAI) from self and pool
```

### Trading

```solidity
// Buy hot with water
uint256 waterCost = liquidDAI.buy(100 ether);

// Sell hot for water
uint256 waterReceived = liquidDAI.sell(50 ether);

// Cross-liquid swap
(uint256 waterUsed, uint256 hotter) = liquidDAI.buy(100 ether, liquidUSDC);
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
✅ Cross-pool swaps via water intermediary

## Reference Documentation

- **[README.md](README.md)** - Quick start guide
- **[foundry.toml](foundry.toml)** - Build configuration
- **[Foundry Book](https://book.getfoundry.sh/)** - Foundry framework docs
- **[OpenZeppelin Contracts](https://docs.openzeppelin.com/contracts/)** - Dependency docs

## Events

```solidity
event Heat(Liquid indexed liquid, uint256 hot);
event Cool(Liquid indexed liquid, uint256 hot, uint256 cold);
event Bought(Liquid indexed liquid, uint256 hot, uint256 water);
event Sold(Liquid indexed liquid, uint256 hot, uint256 water);
event Heat(IERC20Metadata indexed solid, Liquid indexed liquid);
```

## Errors

```solidity
error Nothing();                                     // Zero address token
error Drained(Liquid liquid, uint256 pool, uint256 hot);  // Insufficient pool
error Unauthorized();                                // Non-liquid caller
```

## Quick Reference

### Pool State Queries

```solidity
uint256 pool = liquid.balanceOf(address(liquid));      // Pool liquids
uint256 lake = water.balanceOf(address(liquid));       // Pool water
(uint256 pool, uint256 lake) = liquid.balances();      // Both at once
```

### Quote Functions

```solidity
uint256 water = liquid.buyQuote(100 ether);               // Cost to buy
uint256 water = liquid.sellQuote(50 ether);               // Return from sell
(uint256 water, uint256 hotter) = liquid.buyQuote(100 ether, otherLiquid);
uint256 hot = liquid.buyWithQuote(100 ether);             // Hot from water
uint256 hot = liquid.sellForQuote(50 ether);              // Hot from selling water
```

### Metadata

```solidity
string memory name = liquid.name();        // From backing token
string memory symbol = liquid.symbol();    // From backing token
uint8 decimals = liquid.decimals();        // From backing token
IERC20Metadata backing = liquid.solid();   // Get backing token
```

---

*This document is optimized for AI-assisted development. For human-readable introduction, see [README.md](README.md).*
