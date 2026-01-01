# Liquid Protocol Design

A technical specification of the Liquid protocol's architecture, mathematics, and mechanics.

## Abstract

Liquid is an automated market maker (AMM) protocol that wraps arbitrary tokens into tradeable representations with built-in liquidity. The protocol uses a constant-product formula for price discovery and implements a symmetric mint/burn mechanism that automatically creates liquidity during the wrapping process.

## Core Concepts

### Token States

Each instance of the protocol operates on two token states:

- **Backing Token**: An external token that serves as collateral
- **Wrapped Token**: A tradeable ERC-20 token with embedded liquidity

### Liquidity Representation

The protocol maintains two balance pools per wrapped token:

- **Token Pool**: Wrapped tokens held by the protocol
- **Water Pool**: Base currency tokens held by the protocol

The base currency is itself a wrapped token instance, creating a unified token system.

## Mathematical Model

### Constant Product Invariant

For any wrapped token instance, the following invariant holds during trades:

```
pool × lake = k
```

Where:
- `pool` = wrapped token balance held by protocol
- `lake` = water token balance held by protocol
- `k` = constant (changes only during wrap/unwrap operations)

### Wrapping Operation

When a user deposits `n` backing tokens:

1. Mint `n` wrapped tokens to user
2. Mint `n` wrapped tokens to protocol pool
3. Total supply increases by `2n`

**Effect**: Creates liquidity proportional to deposits without requiring separate liquidity provision.

### Unwrapping Operation

When a user unwraps `n` wrapped tokens:

1. Calculate user's share: `s = user_balance / total_supply`
2. Calculate protocol's share: `p = pool_balance / total_supply`
3. Burn `2n × s` from user
4. Burn `2n × p` from pool
5. Return `cold = n × (backing_balance / user_balance)` backing tokens

**Invariant**: Total burned equals `2n`, maintaining symmetry with wrapping.

### Trading Operations

#### Buy (Water → Wrapped)

To purchase `h` wrapped tokens:

```
pool' = pool - h
lake' = (pool × lake) / pool'
water_cost = lake' - lake
```

Transfer:
- `h` wrapped tokens: protocol → user
- `water_cost` water tokens: user → protocol

#### Sell (Wrapped → Water)

To sell `h` wrapped tokens:

```
pool' = pool + h
lake' = (pool × lake) / pool'
water_received = lake - lake'
```

Transfer:
- `h` wrapped tokens: user → protocol
- `water_received` water tokens: protocol → user

#### Inverse Operations

**BuyWith**: Specify water input, calculate wrapped output
**SellFor**: Specify water output, calculate wrapped input

Both maintain the constant-product invariant.

### Cross-Instance Swaps

To swap between two different wrapped tokens A and B:

1. Execute operation on instance A (sell A for water, or spend water to buy A)
2. Execute inverse operation on instance B (buy B with water, or sell water for B)
3. Both operations atomic within single transaction

Four variants exist based on which token amount is specified:
- `buy(A, B)`: Specify A amount to receive
- `sell(A, B)`: Specify A amount to sell
- `buyWith(A, B)`: Specify B amount to spend
- `sellFor(A, B)`: Specify B amount to receive

## Architectural Design

### Instance Creation

Wrapped token instances are created deterministically using CREATE2:

```
salt = bytes32(uint256(uint160(backing_token_address)))
address = create2(implementation, salt, init_code)
```

**Properties**:
- Same backing token always produces same wrapped token address
- Address predictable before deployment
- Minimal proxy pattern reduces deployment cost

### Factory Pattern

The base water instance serves as factory:

```
function heat(backing_token) → wrapped_instance
```

Only the designated water instance can create new wrapped instances. This centralizes instance registry while keeping the protocol permissionless.

### Access Control Model

**Public Operations** (no restrictions):
- Wrap backing tokens into wrapped tokens
- Unwrap wrapped tokens into backing tokens
- Trade wrapped tokens for water
- Trade water for wrapped tokens
- Cross-instance swaps

**Protected Operations** (only callable by verified instances):
- Internal balance updates during cross-swaps
- Hook functions for multi-instance coordination

**Verification Method**: Caller address must match predicted CREATE2 address for its backing token.

## Security Model

### Reentrancy Protection

All state-changing operations are protected against reentrancy using transient storage (EIP-1153):

```
before operation: set guard = 1
during operation: revert if guard = 1
after operation: clear guard
```

Transient storage automatically clears after transaction completion.

### Token Transfer Safety

All token transfers use safe transfer wrappers that:
- Handle non-standard return values
- Revert on transfer failure
- Prevent silent failures

### Invariant Preservation

The protocol enforces several invariants:

1. **Constant Product**: `pool × lake` unchanged by trades
2. **Symmetry**: Total minted = Total burned over time
3. **Backing Solvency**: Backing token balance ≥ redemption obligations
4. **Atomicity**: Multi-step operations complete or revert entirely

### Permission Model

- No admin keys
- No upgradeable components
- No pause functionality
- No fee switches
- Immutable after deployment

## Economic Properties

### Price Discovery

Price of wrapped token in water terms:

```
price = lake / pool
```

Price adjusts automatically as:
- Demand increases → pool decreases → price increases
- Supply increases → pool increases → price decreases

### Slippage

For a buy of size `h`:

```
slippage = (marginal_price - average_price) / average_price
marginal_price = lake / (pool - h)
average_price = water_cost / h
```

Slippage increases non-linearly with trade size.

### Liquidity Depth

Total value locked in instance:

```
TVL = pool × price + lake
    = pool × (lake / pool) + lake
    = 2 × lake
```

Liquidity depth scales linearly with water pool size.

### Arbitrage Resistance

The protocol prevents simple arbitrage cycles:

1. Wrap → Sell → Buy → Unwrap
2. Heat → Cool (immediate reversal)

Both cycles result in net loss due to:
- AMM slippage on trades
- Proportional burning mechanics on unwrap

## Implementation Requirements

### Token Interface Compatibility

Backing tokens must implement:
- `balanceOf(address) → uint256`
- `transfer(address, uint256) → bool`
- `transferFrom(address, address, uint256) → bool`
- `approve(address, uint256) → bool`

Metadata extension (optional but recommended):
- `name() → string`
- `symbol() → string`
- `decimals() → uint8`

### Wrapped Token Interface

Each wrapped instance must implement full ERC-20:
- All standard transfer operations
- Total supply tracking
- Allowance mechanism
- Event emissions

Plus protocol-specific operations:
- Wrap/unwrap functions
- Trading functions
- Quote functions (view-only price queries)
- Cross-instance swap functions

### State Requirements

Minimal state per instance:
- Backing token reference (immutable)
- Water instance reference (immutable)
- ERC-20 balance mapping
- ERC-20 allowance mapping
- Reentrancy guard (transient)

### Computational Complexity

All operations O(1):
- Wrap: 2 mints + 1 transfer
- Unwrap: 2 burns + 1 transfer
- Trade: 2 transfers + arithmetic
- Cross-swap: 4 transfers + arithmetic

No loops, no unbounded operations.

## Protocol Topology

### Network Structure

```
                    WATER (base instance)
                         |
         +---------------+---------------+
         |               |               |
    Instance A      Instance B      Instance C
    (wraps USDC)   (wraps DAI)    (wraps WETH)
```

- One designated water instance serves as base currency
- All other instances wrap different backing tokens
- All instances can trade against water
- Any two instances can swap via water intermediary

### Routing

Direct trade: `Token ↔ Water`
Cross-instance: `Token A ↔ Water ↔ Token B`

No multi-hop routing required. All swaps are at most 2 hops.

### Composability

Instances are independently deployable and tradeable. No global state synchronization required except during cross-instance swaps (which are atomic).

## Extensions and Variations

### Quote Functions

Non-state-changing functions that return expected trade results:

```
buyQuote(amount) → water_cost
sellQuote(amount) → water_received
buyWithQuote(water) → amount_received
sellForQuote(water) → amount_to_sell
```

Enable off-chain price discovery and UI integration.

### Batch Operations

Multiple wraps/unwraps/trades can be batched in single transaction using multicall pattern. Protocol itself doesn't implement batching but is compatible with standard multicall wrappers.

### Flash Operations

Not explicitly supported but compatible with flash loan patterns:
1. Borrow tokens
2. Execute operations
3. Repay + fee

Provided the constant-product invariant is maintained.

## Comparison to Related Designs

### vs. Uniswap V2

**Similarities**:
- Constant-product formula
- Permissionless pool creation
- No oracle dependencies

**Differences**:
- Liquid: n pools for n tokens (each vs water)
- Uniswap: n² pairs for n tokens (each vs each)
- Liquid: Zero fees, immutable
- Uniswap: 0.3% fee, governance-upgradeable
- Liquid: Automatic liquidity via 2x mint
- Uniswap: Requires explicit liquidity provision

### vs. Curve

**Similarities**:
- AMM-based price discovery
- Multi-token support

**Differences**:
- Liquid: Constant-product (xy=k)
- Curve: Stableswap curve (hybrid constant-sum/product)
- Liquid: General purpose
- Curve: Optimized for like-kind assets
- Liquid: No governance
- Curve: DAO-controlled

### vs. Wrapped Tokens (WETH)

**Similarities**:
- 1:1 wrapping of underlying asset
- Permissionless wrap/unwrap

**Differences**:
- Liquid: Built-in AMM liquidity
- WETH: No liquidity mechanism
- Liquid: 2x mint creates pool depth
- WETH: 1:1 mint only
- Liquid: Tradeable within protocol
- WETH: Requires external DEX

## Formal Properties

### Correctness Properties

1. **Conservation**: Total value in = Total value out (excluding fees)
2. **Determinism**: Same inputs always produce same outputs
3. **Atomicity**: Operations complete fully or revert entirely
4. **Isolation**: Instances cannot interfere with each other except during explicit cross-swaps

### Liveness Properties

1. **Progress**: Operations always terminate (no infinite loops)
2. **Availability**: Protocol always accepts valid operations (no pause state)
3. **Censorship Resistance**: No ability to block specific users

### Safety Properties

1. **Solvency**: Backing tokens sufficient for all unwrap obligations
2. **Invariant Preservation**: Mathematical invariants maintained across all operations
3. **Access Control**: Protected functions only callable by authorized instances

## Conclusion

Liquid protocol implements a minimal, immutable AMM design that unifies token wrapping with liquidity provision. The constant-product formula ensures deterministic price discovery, while the 2x mint mechanism automatically creates tradeable depth. Zero fees and no governance reduce protocol complexity and eliminate capture risk, at the cost of no protocol revenue mechanism.

The design trades off flexibility (no fee extraction, no governance upgrades) for simplicity and trust-minimization. This positions it as infrastructure rather than a profit-generating protocol.
