# Introduction to Liquid Protocol

> A simple, elegant approach to tokenized liquidity on Ethereum

## What is Liquid?

Liquid is a protocol that allows any ERC-20 token to become "liquid" — wrapped with built-in liquidity pools. Think of it as giving tokens the ability to trade themselves, without needing external liquidity providers or complex pool management.

Every liquid token is both:
- A standard ERC-20 token you can hold and transfer
- Its own automated market maker (AMM) with instant swap capability

## The Core Idea

Traditional DeFi requires you to:
1. Take your tokens (like USDC)
2. Deposit them into a separate liquidity pool
3. Manage LP positions across different protocols
4. Deal with impermanent loss and complex mechanics

With Liquid, you simply:
1. **Liquify** your tokens (USDC → liquid-USDC)
2. Done. Your tokens now have built-in liquidity.

## How It Works

### The Water Metaphor

The protocol uses an intuitive water/ice metaphor:

- **Ice/Solid** = Your original ERC-20 token (USDC, DAI, etc.)
- **Liquid** = The wrapped version with built-in liquidity (liquid-USDC, liquid-DAI)
- **Water** = The base Liquid instance used for cross-pool trading
- **Pool** = Liquid tokens held by the contract
- **Lake** = Water tokens held by the contract

### Core Operations

#### 1. Liquify (Ice → Liquid)

When you deposit 1,000 USDC into the liquid-USDC contract:
- You receive 1,000 liquid-USDC tokens
- The pool also gets 1,000 liquid-USDC tokens
- Total: 2,000 liquid-USDC minted from your 1,000 USDC deposit

This 2x minting is what creates instant liquidity. Half goes to you, half stays in the pool for trading.

#### 2. Solidify (Liquid → Ice)

When you want your USDC back:
- Burn your liquid-USDC
- Burn matching amount from pool
- Receive USDC proportional to the pool's backing reserves

The symmetry (2x mint, 2x burn) ensures the system stays balanced.

#### 3. Trading

Once tokens are liquid, you can trade them:

**Buy liquid-USDC with water:**
```
water cost = (pool × lake) / (pool - liquids_bought) - lake
```

**Sell liquid-USDC for water:**
```
water received = lake - (pool × lake) / (pool + liquids_sold)
```

This is the classic constant-product formula (`x × y = k`) from Uniswap, applied to each liquid pool.

#### 4. Cross-Liquid Swaps

Want to swap liquid-USDC for liquid-DAI?
- Contract sells your liquid-USDC for water
- Then buys liquid-DAI with that water
- All in one transaction

Water acts as the universal intermediary, like ETH does on Uniswap.

## Key Features

### 1. Deterministic Addresses

Every token always creates the same liquid wrapper address (using CREATE2). This means:
- liquid-USDC has one canonical address
- No fragmented liquidity across multiple pools
- Predictable, verifiable deployments

### 2. Single Contract Architecture

The entire protocol is one ~230 line Solidity contract. No external routers, no complex governance, no upgrade mechanisms. Just pure logic.

### 3. Built-in Reentrancy Protection

Uses EIP-1153 transient storage for gas-efficient reentrancy guards. Modern, clean, safe.

### 4. No External Oracles

Prices emerge from the constant-product formula. No oracle manipulation risk, no additional dependencies.

## Example User Journey

### Alice wants to make her USDC liquid:

1. **Approve & Liquify**
   ```solidity
   usdc.approve(address(liquidUSDC), 10000e6);
   liquidUSDC.liquify(10000e6);
   ```
   - Alice deposits 10,000 USDC
   - Gets 10,000 liquid-USDC
   - Pool grows by 10,000 liquid-USDC

2. **Bob wants to buy liquid-USDC**
   ```solidity
   uint256 waterCost = liquidUSDC.buy(1000e6);
   ```
   - Bob pays water tokens
   - Receives liquid-USDC from the pool
   - Pool shrinks, lake grows

3. **Alice wants to swap liquid-USDC → liquid-DAI**
   ```solidity
   (uint256 waterUsed, uint256 daiReceived) =
     liquidUSDC.buy(1000e6, liquidDAI);
   ```
   - One transaction, two pool trades
   - Water is the intermediary

4. **Alice solidifies back to USDC**
   ```solidity
   uint256 usdcReceived = liquidUSDC.solidify(5000e6);
   ```
   - Burns liquid-USDC from Alice and pool
   - Returns USDC from backing reserves

## Mathematical Properties

### Constant Product Invariant

For each liquid pool:
```
pool_liquids × lake_water = k (constant)
```

This is maintained across all buy/sell operations.

### Liquify/Solidify Symmetry

```
Liquify:  mint 2n tokens from n solids
Solidify: burn 2n tokens to return solids
```

The 2x factor ensures liquidity provision is built into the minting process.

### Backing Token Conservation

```
USDC in contract = all liquified USDC - all solidified USDC
```

The protocol never creates backing tokens, only wraps and unwraps them.

## Use Cases

### For Token Holders

- Add instant liquidity to any ERC-20 token
- No need to manage LP positions
- Simple wrap/unwrap mechanics

### For Traders

- Trade any liquid token against water
- Swap between any two liquid tokens
- Deterministic pricing based on pool reserves

### For Protocol Developers

- Create liquid versions of protocol tokens
- Enable instant swapping without external DEX integration
- Predictable, auditable, minimal code

## Security Model

### What Liquid Protects Against

✅ **Reentrancy attacks** - EIP-1153 transient storage guards
✅ **Unauthorized pool manipulation** - `onlyLiquid` modifier
✅ **Integer overflow** - Solidity 0.8.30+ built-in checks
✅ **Malicious tokens** - SafeERC20 wrapper

### What Liquid Does NOT Protect Against

❌ **Malicious backing tokens** - If the underlying ERC-20 is compromised, the liquid wrapper inherits that risk
❌ **Economic attacks** - Standard AMM risks (sandwich attacks, MEV, etc.)
❌ **Smart contract bugs** - While audited patterns are used, all contracts carry risk

### Assumptions

- Backing tokens implement ERC-20 correctly
- Users understand AMM mechanics
- No external dependencies (oracles, governance, etc.)

## Comparison to Other Protocols

### vs. Uniswap V2

**Similar:**
- Constant-product AMM formula
- Deterministic pool addresses (CREATE2)

**Different:**
- Liquid: Wrapped tokens with built-in pools
- Uniswap: External pools require separate LP tokens
- Liquid: 2x mint/burn symmetry
- Uniswap: LP tokens represent pool share

### vs. Wrapped Tokens (WETH)

**Similar:**
- Wrap/unwrap mechanics
- 1:1 backing ratio

**Different:**
- Liquid: Built-in AMM liquidity
- WETH: No liquidity, just wrapping

### vs. Interest-Bearing Tokens (aUSDC, cDAI)

**Similar:**
- Wrapped ERC-20 with additional functionality

**Different:**
- Liquid: Trading liquidity via AMM
- aTokens: Lending yield via interest accrual

## Architecture

### Single Contract Design

```
Liquid.sol (232 lines)
├── ERC-20 implementation (OpenZeppelin)
├── ReentrancyGuard (transient storage)
├── Factory (CREATE2 minimal proxy)
├── AMM logic (constant-product)
└── Liquify/Solidify mechanics
```

### State Variables

```solidity
Liquid public immutable WATER;        // Factory instance
IERC20Metadata public solid;          // Backing token
mapping(address => IERC20Metadata) public solidOf;  // Registry
```

### Key Functions

**User Operations:**
- `liquify(uint256 solids)` - Deposit backing token
- `solidify(uint256 liquids)` - Withdraw backing token
- `buy(uint256 liquids)` - Buy liquid with water
- `sell(uint256 liquids)` - Sell liquid for water

**Factory:**
- `make(IERC20Metadata stuff)` - Create new liquid

**Internal:**
- `update(address to, uint256 amount)` - Cross-pool transfers
- `balances()` - Get pool/lake state

## Deployment

### Network Support

Liquid can be deployed on any EVM-compatible chain:
- Ethereum (mainnet & Sepolia testnet)
- Arbitrum
- Base
- Optimism
- Polygon
- BNB Chain

### Requirements

- Solidity 0.8.30+ (for EIP-1153 transient storage)
- Cancun EVM fork (for latest features)
- CREATE2 factory support

### Process

1. Deploy water instance (the factory)
2. Call `water.make(tokenAddress)` for each token you want to liquify
3. Users can now liquify/solidify/trade

## Developer Quick Start

```bash
# Install Foundry
curl -L https://foundry.paradigm.xyz | bash
foundryup

# Clone and build
git clone git@github.com:uniteum/liquid.git
cd liquid
forge build

# Run tests
forge test

# Deploy to testnet
export tx_key=<YOUR_PRIVATE_KEY>
export chain=11155111  # Sepolia
forge script script/Liquid.s.sol \
  -f $chain \
  --private-key $tx_key \
  --broadcast
```

## Further Reading

- [README.md](README.md) - Quick start and development setup
- [CLAUDE.md](CLAUDE.md) - Comprehensive technical documentation
- [src/Liquid.sol](src/Liquid.sol) - Source code (232 lines)
- [Foundry Book](https://book.getfoundry.sh/) - Development framework

## Frequently Asked Questions

### Is this a fork of Uniswap?

No. While it uses the same constant-product formula, the architecture is completely different. Liquid wraps tokens with built-in liquidity, rather than creating separate pool contracts.

### Can I lose money using Liquid?

Yes. Like any AMM, you face:
- Price impact on large trades
- Potential losses if the backing token depegs or has issues
- Smart contract risk (though standard patterns are used)

### Who provides the liquidity?

Everyone who liquifies tokens. When you liquify 1,000 USDC:
- You get 1,000 liquid-USDC to hold
- The pool gets 1,000 liquid-USDC to trade

You are both a token holder and a liquidity provider simultaneously.

### What are the fees?

Currently, there are no protocol fees in the base implementation. This can be modified for specific deployments.

### Is it audited?

The protocol uses battle-tested components (OpenZeppelin ERC-20, SafeERC20, ReentrancyGuard) and standard AMM formulas. However, you should perform your own security review before using it in production.

### Can liquids be traded on other DEXs?

Yes! Liquid tokens are standard ERC-20s. You can trade them on Uniswap, Curve, or any other DEX just like any other token.

### What happens if the pool runs out of liquidity?

The constant-product formula prevents complete drainage. As liquidity decreases, prices become increasingly unfavorable, creating natural resistance.

## Philosophy

Liquid embraces simplicity:

- **One contract** instead of multiple interconnected systems
- **Simple operations** instead of complex pool management
- **Built-in liquidity** instead of external LP positions
- **Deterministic behavior** instead of governance parameters

The goal is to make tokenized liquidity as simple as wrapping ETH.

---

*Last updated: 2025-12-31*
