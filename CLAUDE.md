# CLAUDE.md - Liquid Protocol

> Context guide for AI-assisted development of the Liquid protocol.

## Overview

**Liquid** is a constant-product AMM protocol on Ethereum where any ERC-20 token can be wrapped into a "liquid" token with built-in liquidity.

### Core Metaphor

- **Ice/Solid** = External ERC-20 backing token
- **Liquid** = Wrapped ERC-20 with AMM liquidity
- **Water** = Base Liquid instance used for cross-pool swaps
- **Pool** = Liquid tokens held by contract
- **Lake** = Water tokens held by contract

### Key File

**[src/Liquid.sol](src/Liquid.sol)** (232 lines) - Single contract implementing entire protocol

## Core Operations

### 1. Liquify (Solid → Liquid)

```solidity
function liquify(uint256 solids) external nonReentrant
```

**What it does:**
- User deposits `solids` of backing token
- Contract mints `solids` to pool AND `solids` to user (2x mint)
- Result: User owns `solids` liquids, pool grows by `solids`

**Example:**
```solidity
// User has 1000 USDC
usdc.approve(address(liquidUSDC), 1000);
liquidUSDC.liquify(1000);
// User now has: 1000 liquid-USDC
// Pool now has: 1000 liquid-USDC
```

### 2. Solidify (Liquid → Solid)

```solidity
function solidify(uint256 liquids) external nonReentrant returns (uint256 solids)
```

**What it does:**
- Burns liquids proportionally from both user and pool
- Returns backing tokens based on: `liquids * (backing_balance / user_held_liquids)`
- Burns total of `2 * liquids` (maintaining symmetry with liquify)

**Formula:**
```solidity
pool_burn = 2 * liquids * pool / totalSupply
user_burn = 2 * liquids * held / totalSupply
solids = liquids * solid.balanceOf(address(this)) / held
```

### 3. Buy (Water → Liquid)

```solidity
function buy(uint256 liquids) external returns (uint256 water)
```

**Constant Product Formula:**
```solidity
// Invariant: pool * lake = k
water = pool * lake / (pool - liquids) - lake
```

**What it does:**
- Calculates water cost for buying `liquids` from pool
- Transfers water from user to pool's lake
- Transfers liquids from pool to user

### 4. Sell (Liquid → Water)

```solidity
function sell(uint256 liquids) external returns (uint256 water)
```

**Formula:**
```solidity
water = lake - pool * lake / (pool + liquids)
```

**What it does:**
- Calculates water received for selling `liquids` to pool
- Transfers liquids from user to pool
- Transfers water from pool's lake to user

### 5. Cross-Liquid Swaps

```solidity
function buy(uint256 liquids, Liquid other) external
    returns (uint256 water, uint256 others)
```

**What it does:**
- Swaps between two different Liquid pools using water as intermediary
- Example: Swap liquid-USDC for liquid-DAI in single transaction
- Both pools maintain their AMM invariants

## Factory Pattern

### Creating New Liquids

```solidity
function make(IERC20Metadata stuff) public returns (Liquid liquid)
```

**How it works:**
- Uses CREATE2 with `bytes32(uint160(address(stuff)))` as salt
- Same backing token always produces same Liquid address
- Uses EIP-1167 minimal proxy (OpenZeppelin Clones)
- Only callable from main WATER instance

**Example:**
```solidity
IERC20Metadata usdc = IERC20Metadata(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
Liquid liquidUSDC = water.make(usdc);
// liquidUSDC address is deterministic based on USDC address
```

## Architecture

### Contract Structure

```solidity
contract Liquid is ERC20, ReentrancyGuardTransient {
    Liquid public immutable WATER = this;
    IERC20Metadata public solid;  // Backing token
    mapping(address => IERC20Metadata) public solidOf;  // Registry
}
```

### State Variables

- `WATER` - Immutable self-reference (main instance for factory)
- `solid` - The backing ERC-20 token for this Liquid
- `solidOf[liquidAddress]` - Maps Liquid addresses to their backing tokens

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

### 2. Liquify/Solidify Symmetry

```
Total minted in liquify = 2 * solids
Total burned in solidify = 2 * liquids
```

### 3. Backing Token Conservation

```
solid.balanceOf(address(liquid)) = sum of all liquified solids - sum of all solidified returns
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
    if (address(WATER.solidOf(msg.sender)) == address(0)) {
        revert Unauthorized();
    }
    _;
}
```

- Only registered Liquid instances can call cross-pool functions
- Prevents unauthorized pool manipulation
- Applied to: `bought()`, `sold()`, `update()`

### Safe Token Handling

```solidity
using SafeERC20 for IERC20Metadata;
```

- All token transfers use SafeERC20
- Handles non-standard ERC-20 implementations
- No raw `transfer()` or `transferFrom()` calls

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
forge test --match-test test_MeltFreeze
forge test --match-test test_MeltSellFreezeBuy
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
        owen.liquify(W, 1e9);
        U = W.make(owen.newToken("U", 1e9));
        V = W.make(owen.newToken("V", 1e9));
    }
}
```

### Test User Pattern

```solidity
contract LiquidUser is User {
    function liquify(Liquid U, uint256 solids) public { }
    function solidify(Liquid U, uint256 liquids) public returns (uint256 solids) { }
    function sell(Liquid U, uint256 liquids) public returns (uint256 water) { }
    function liquidate(Liquid U) public returns (uint256 liquids, uint256 solids) { }
}
```

**LiquidUser** wraps operations with automatic logging and balance tracking.

### Example Test

```solidity
function test_MeltFreeze() public returns (uint256 liquids, uint256 solids) {
    giveaway();                        // Distribute tokens to users
    owen.liquify(U, 500);
    alex.liquify(U, 500);
    beck.liquify(U, 500);

    liquids = 100;
    solids = alex.solidify(U, liquids);
    assertEq(liquids, solids, "alex liquids != solids");

    // Full liquidation
    (liquids, solids) = alex.liquidate(U);
    assertEq(liquids, solids, "alex liquids != solids");
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
Liquid liquidDAI = water.make(dai);
```

### Adding Liquidity

```solidity
// User deposits backing token
dai.approve(address(liquidDAI), 1000 ether);
liquidDAI.liquify(1000 ether);
// User receives 1000 liquid-DAI, pool grows by 1000
```

### Removing Liquidity

```solidity
// User withdraws backing token
uint256 solids = liquidDAI.solidify(500 ether);
// User receives DAI, burns liquid-DAI from self and pool
```

### Trading

```solidity
// Buy liquid with water
uint256 waterCost = liquidDAI.buy(100 ether);

// Sell liquid for water
uint256 waterReceived = liquidDAI.sell(50 ether);

// Cross-liquid swap
(uint256 waterUsed, uint256 usdcReceived) = liquidDAI.buy(100 ether, liquidUSDC);
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
event Liquify(Liquid indexed liquid, uint256 liquids);
event Solidify(Liquid indexed liquid, uint256 liquids, uint256 solids);
event Bought(Liquid indexed liquid, uint256 liquids, uint256 water);
event Sold(Liquid indexed liquid, uint256 liquids, uint256 water);
event Made(IERC20Metadata indexed solid, Liquid indexed liquid);
```

## Errors

```solidity
error Nothing();                                          // Zero address token
error Drained(Liquid liquid, uint256 pool, uint256 liquids);  // Insufficient pool
error Unauthorized();                                     // Non-liquid caller
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
uint256 water = liquid.buyQuote(100 ether);            // Cost to buy
uint256 water = liquid.sellQuote(50 ether);            // Return from sell
(uint256 water, uint256 others) = liquid.buyQuote(100 ether, otherLiquid);
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
