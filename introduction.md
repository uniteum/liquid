# Introduction to Liquid Protocol

> A simple guide to using tokenized liquidity on Ethereum

## What is Liquid?

Liquid is a protocol that allows any ERC-20 token to become "liquid" — wrapped with built-in liquidity pools. Every liquid token is both:
- A standard ERC-20 token you can hold and transfer
- Its own automated market maker (AMM) with instant swap capability

You can interact with the entire protocol through Etherscan contract interactions. No custom frontend needed.

## The Core Metaphor

The protocol uses an intuitive water metaphor:

- **Solid** = Your original ERC-20 token (USDC, DAI, etc.)
  - Note: Ice is the solid for water specifically
  - Each liquid has its own solid (e.g., USDC is the solid for liquid-USDC)
- **Liquid** = The wrapped version with built-in liquidity (liquid-USDC, liquid-DAI)
- **Water** = The base Liquid instance used for cross-pool trading
- **Pool** = Liquid tokens held by the contract
- **Lake** = Water tokens held by the contract

## How to Use Liquid (via Etherscan)

All operations can be performed through Etherscan's "Write Contract" interface. No coding required.

### Step 1: Find the Liquid Contract

1. Go to Etherscan (etherscan.io for mainnet, or the appropriate network explorer)
2. Navigate to the liquid token contract address
3. Click the "Contract" tab
4. Click "Write Contract"
5. Click "Connect to Web3" to connect your wallet

### Step 2: Liquify (Wrap Your Tokens)

**Goal:** Convert your ERC-20 tokens (e.g., USDC) into liquid tokens with built-in liquidity.

**Before you start:**
1. Go to your backing token contract (e.g., USDC)
2. Use the `approve` function to allow the liquid contract to spend your tokens
   - `spender`: The liquid contract address
   - `amount`: How much you want to liquify (in token's decimals)

**To liquify:**
1. On the liquid contract, find the `liquify` function
2. Enter the amount (in token's decimals, e.g., `1000000000` for 1000 USDC with 6 decimals)
3. Click "Write" and confirm the transaction

**What happens:**
- You deposit 1,000 USDC
- You receive 1,000 liquid-USDC tokens
- The pool also gets 1,000 liquid-USDC tokens
- Total: 2,000 liquid-USDC minted from your 1,000 USDC

This 2x minting creates instant liquidity. Half goes to you, half stays in the pool for trading.

### Step 3: Solidify (Unwrap Back to Original Tokens)

**Goal:** Convert liquid tokens back to the original ERC-20 tokens.

**To solidify:**
1. On the liquid contract, find the `solidify` function
2. Enter how many liquid tokens you want to burn (e.g., `500000000` for 500 liquid-USDC)
3. Click "Write" and confirm the transaction

**What happens:**
- Burns your liquid tokens
- Burns matching amount from the pool
- Returns the backing tokens (USDC) proportional to pool reserves

The 2x burn (from you and pool) maintains symmetry with the 2x mint in liquify.

### Step 4: Buy Liquid with Water

**Goal:** Trade water tokens for liquid tokens from the pool.

**Before you start:**
1. You need water tokens in your wallet

**To buy:**
1. On the liquid contract, find the `buy` function (the one with just `uint256 liquids` parameter)
2. Enter how many liquid tokens you want to buy
3. Click "Write" and confirm the transaction

**What happens:**
- Calculates water cost using: `water = pool * lake / (pool - liquids) - lake`
- Transfers water from you to the pool's lake
- Transfers liquid tokens from pool to you

**To check the cost before buying:**
- Use the "Read Contract" tab
- Call `buyQuote` with the amount you want to buy
- This shows how much water it will cost (no transaction needed)

### Step 5: Sell Liquid for Water

**Goal:** Trade liquid tokens for water tokens.

**To sell:**
1. On the liquid contract, find the `sell` function (the one with just `uint256 liquids` parameter)
2. Enter how many liquid tokens you want to sell
3. Click "Write" and confirm the transaction

**What happens:**
- Calculates water received using: `water = lake - pool * lake / (pool + liquids)`
- Transfers liquid tokens from you to the pool
- Transfers water from pool's lake to you

**To check the return before selling:**
- Use the "Read Contract" tab
- Call `sellQuote` with the amount you want to sell
- This shows how much water you'll receive

### Step 6: Cross-Liquid Swaps

**Goal:** Swap one liquid token for another in a single transaction.

**Example:** Swap liquid-USDC for liquid-DAI

**To swap:**
1. On the first liquid contract (e.g., liquid-USDC), find the `buy` function with two parameters: `(uint256 liquids, Liquid other)`
2. Enter the amount you want to buy of the target liquid
3. Enter the address of the target liquid contract (e.g., liquid-DAI address)
4. Click "Write" and confirm the transaction

**What happens:**
- Sells your liquid-USDC for water
- Buys liquid-DAI with that water
- All in one transaction

**To check the cost before swapping:**
- Use the "Read Contract" tab
- Call `buyQuote(uint256,Liquid)` with the amount and target liquid address
- This shows water used and how much of the other liquid you'll receive

### Step 7: Check Pool State

**To see pool liquidity:**
1. Go to "Read Contract" tab
2. Call `balanceOf` with the liquid contract's own address
   - This shows how many liquid tokens are in the pool

**To see pool's water balance:**
1. Go to the water contract
2. Call `balanceOf` with the liquid contract's address
   - This shows how many water tokens are in the lake

**Quick way to see both:**
1. On the liquid contract, call `balances()`
2. Returns `(pool, lake)` - both balances at once

## Common Workflows

### Workflow 1: Create Liquidity for Your Token

1. Go to the water contract on Etherscan
2. Use `make(address stuff)` function
3. Enter your ERC-20 token address
4. Confirms transaction → new liquid token created
5. Find the new liquid contract address from the transaction logs
6. Approve and liquify your tokens into this new liquid

### Workflow 2: Trade Between Two Liquid Tokens

**Example:** Trade liquid-USDC → liquid-DAI

1. On liquid-USDC contract, use `buy(uint256 liquids, Liquid other)`
2. Enter amount of liquid-DAI you want
3. Enter liquid-DAI contract address
4. Confirm transaction
5. Receive liquid-DAI directly

### Workflow 3: Add Liquidity to Existing Liquid

1. Approve the backing token (e.g., USDC)
2. Call `liquify(amount)` on the liquid contract
3. Receive liquid tokens (you get N, pool gets N)
4. Pool now has more liquidity for trading

### Workflow 4: Exit Your Position

**Option A: Solidify to backing token**
1. Call `solidify(amount)` on the liquid contract
2. Receive backing tokens based on pool reserves

**Option B: Sell for water, then solidify water**
1. Call `sell(amount)` to convert liquid → water
2. Go to water contract
3. Call `solidify(amount)` to convert water → ice (water's solid)

**Option C: Trade on external DEX**
- Liquid tokens are standard ERC-20s
- Can trade on Uniswap, Curve, or any DEX

## Reading Contract Information

### Check Your Balances

**Your liquid token balance:**
1. "Read Contract" tab on liquid contract
2. Call `balanceOf(address)` with your wallet address

**Your backing token balance:**
1. Go to the backing token contract
2. Call `balanceOf(address)` with your wallet address

### Check Token Information

**Token name and symbol:**
- Call `name()` and `symbol()` (inherits from backing token)

**Decimals:**
- Call `decimals()` (matches backing token)

**What's the backing token?**
- Call `solid()` returns the backing token address

### Check if Address is a Liquid

1. Go to the water contract
2. Call `solidOf(address)` with the potential liquid address
3. If it returns non-zero address, it's a registered liquid
4. The returned address is that liquid's backing token

## Understanding Prices and Impact

### Price Impact

The constant-product formula means:
- Small trades have minimal price impact
- Large trades move the price significantly
- Infinite liquidity impossible (price approaches infinity as pool depletes)

### Checking Quotes

Always use quote functions before trading:
- `buyQuote(amount)` - Shows water cost to buy
- `sellQuote(amount)` - Shows water return from sell
- `buyQuote(amount, otherLiquid)` - Shows cost for cross-liquid swap

These are read-only calls (no gas cost, no transaction needed).

### Understanding Slippage

If pool state changes between your quote and transaction:
- Buy might cost more water than quoted
- Sell might return less water than quoted
- Cross-liquid swaps may get different amounts

The AMM formula automatically adjusts based on current pool state.

## Security Considerations

### Before Interacting with a Liquid

✅ **Verify the backing token:**
- Call `solid()` to see what token backs this liquid
- Check that backing token is legitimate

✅ **Check pool liquidity:**
- Call `balances()` to see pool size
- Larger pools generally have better prices

✅ **Use quote functions:**
- Always check quotes before large trades
- Understand price impact

### Risks to Understand

❌ **Backing token risk:**
- If the underlying token is malicious or fails, the liquid inherits that risk

❌ **AMM economics:**
- Price impact on large trades
- Possible MEV/sandwich attacks
- Standard DEX trading risks

❌ **Smart contract risk:**
- While using standard patterns, all contracts carry risk
- Verify contract source code on Etherscan

### Approvals

When you approve a contract:
- It can spend up to that amount of your tokens
- Use reasonable approval amounts
- You can revoke by calling `approve(contract, 0)`

## Comparison to Other Protocols

### vs. Uniswap

**Trading:**
- Liquid: Trade liquid tokens against water directly through contract
- Uniswap: Trade token pairs through router contract

**Liquidity:**
- Liquid: Automatic 2x mint when you liquify (you get half, pool gets half)
- Uniswap: Manually add/remove liquidity, receive separate LP tokens

### vs. Wrapped Tokens (WETH)

**Similar:**
- Both wrap underlying tokens 1:1

**Different:**
- Liquid: Built-in AMM for instant trading
- WETH: No liquidity, just wrapped for compatibility

### vs. Curve/Balancer

**Formula:**
- Liquid: Constant-product (x × y = k)
- Curve: Stableswap (optimized for low slippage)
- Balancer: Weighted pools with customizable ratios

**Complexity:**
- Liquid: Simple wrap/unwrap + trade
- Curve/Balancer: Advanced pool configurations

## Frequently Asked Questions

### How do I create a liquid for my token?

1. Go to the water contract on Etherscan
2. Use the `make(address)` function
3. Enter your token's address
4. Confirm the transaction
5. The new liquid address is in the transaction logs

### Can I lose money?

Yes. Risks include:
- Price impact on trades (AMM slippage)
- Backing token issues (if underlying token fails)
- Smart contract risk
- Market volatility between liquid and solid

### Who provides the liquidity?

Everyone who liquifies. When you liquify 1,000 USDC:
- You get 1,000 liquid-USDC to hold
- Pool gets 1,000 liquid-USDC to trade

You're both a holder and liquidity provider simultaneously.

### Are there fees?

No. The protocol charges no fees beyond standard Ethereum gas costs. There never will be fees.

The protocol developers reserved a portion of Water tokens as their monetization strategy, not ongoing transaction fees.

### Can I trade liquid tokens on other DEXs?

Yes! Liquid tokens are standard ERC-20s. You can:
- Trade them on Uniswap, SushiSwap, etc.
- Add them to other liquidity pools
- Use them in any DeFi protocol that accepts ERC-20s

### What if the pool runs out?

The constant-product formula prevents complete drainage. As pool liquidity decreases, prices become increasingly unfavorable, creating natural resistance.

### How do I find all liquids?

1. Go to the water contract on Etherscan
2. Check the "Events" tab
3. Filter for `Made` events
4. Each event shows a new liquid and its backing token

### How are prices determined?

Pure math based on pool reserves:
```
buy:  water_cost = pool × lake / (pool - liquids) - lake
sell: water_return = lake - pool × lake / (pool + liquids)
```

No oracles, no governance, no external inputs.

### Can I get my exact deposit back?

On average, yes—but it varies above and below 1:1 over time.

When you solidify, the amount of solids you receive depends on how much of the liquid supply is in the pool versus held outside:
- **More liquid in pool** (less held outside) → You get more solids per liquid
- **Less liquid in pool** (more held outside) → You get fewer solids per liquid
- **On average across all users** → Approaches 1:1 ratio

The formula is: `solids = liquids * solid.balanceOf(contract) / total_held_outside_pool`

Think of it like wrapping + being an LP simultaneously. Your share of backing tokens fluctuates based on pool distribution.

## Example Scenarios

### Scenario 1: Alice Adds Liquidity

**Starting state:**
- Alice has 10,000 USDC
- liquid-USDC pool has 5,000 tokens

**Alice's actions on Etherscan:**
1. USDC contract → `approve(liquidUSDC, 10000e6)`
2. liquid-USDC contract → `liquify(10000e6)`

**Result:**
- Alice receives 10,000 liquid-USDC
- Pool grows to 15,000 liquid-USDC
- Alice can now trade, hold, or solidify

### Scenario 2: Bob Buys Liquid

**Starting state:**
- Bob has 1,000 water
- liquid-USDC pool: 10,000 liquid, 2,000 water

**Bob's actions on Etherscan:**
1. liquid-USDC contract → Read → `buyQuote(1000e6)`
   - Returns: ~222 water needed
2. liquid-USDC contract → Write → `buy(1000e6)`

**Result:**
- Bob receives 1,000 liquid-USDC
- Pool now: 9,000 liquid, 2,222 water
- Bob paid ~222 water

### Scenario 3: Carol Swaps Liquid-USDC for Liquid-DAI

**Starting state:**
- Carol has 5,000 liquid-USDC

**Carol's actions on Etherscan:**
1. liquid-USDC contract → Read → `buyQuote(1000e6, liquidDAI_address)`
   - Check water used and DAI received
2. liquid-USDC contract → Write → `buy(1000e6, liquidDAI_address)`

**Result:**
- Carol's liquid-USDC sold for water
- That water bought liquid-DAI
- Carol now holds liquid-DAI
- Both pools' states updated

### Scenario 4: Dave Exits His Position

**Starting state:**
- Dave has 3,000 liquid-USDC

**Dave's actions on Etherscan:**
1. liquid-USDC contract → Read → `solidify` preview (via staticcall or quote if available)
2. liquid-USDC contract → Write → `solidify(3000e6)`

**Result:**
- Burns 3,000 liquid-USDC from Dave
- Burns matching amount from pool
- Dave receives USDC based on pool reserves
- Pool liquidity decreases

## Advanced Usage

### Checking CREATE2 Addresses

Liquid uses deterministic addresses. Same backing token → same liquid address always.

**To predict a liquid address before creation:**
1. Compute CREATE2 address using:
   - Factory: water contract address
   - Salt: `bytes32(uint160(address(backingToken)))`
   - Bytecode: EIP-1167 minimal proxy bytecode
   - Implementation: Liquid implementation address

### Batch Operations

Etherscan doesn't support batch transactions directly, but you can:
1. Use a wallet like Safe (Gnosis Safe) for multi-calls
2. Write a simple contract that batches operations
3. Use Etherscan's "Write as Proxy" if available

### Reading Events

To see all activity on a liquid:
1. Go to "Events" tab on Etherscan
2. Filter by event type:
   - `Liquify` - Deposits
   - `Solidify` - Withdrawals
   - `Bought` - Purchases from pool
   - `Sold` - Sales to pool

### Monitoring Pool Health

**Key metrics:**
1. Pool size: `balanceOf(liquidAddress)`
2. Lake size: `water.balanceOf(liquidAddress)`
3. Ratio: pool/lake indicates price level
4. Total supply: `totalSupply()` shows all liquid tokens

**Health indicators:**
- Large pool + lake = good liquidity
- Very small pool = high price impact
- Zero lake = can't sell (but can still solidify)

## Network Information

Liquid can be deployed on any EVM chain. Check where your specific instance is deployed:

- **Ethereum Mainnet:** Chain ID 1
- **Sepolia Testnet:** Chain ID 11155111
- **Arbitrum:** Chain ID 42161
- **Base:** Chain ID 8453
- **Optimism:** Chain ID 10
- **Polygon:** Chain ID 137
- **BNB Chain:** Chain ID 56

Use the appropriate network explorer (e.g., arbiscan.io for Arbitrum, basescan.org for Base).

## Getting Help

- Read the code: [src/Liquid.sol](src/Liquid.sol) (232 lines, well-commented)
- Technical documentation: [CLAUDE.md](CLAUDE.md)
- Development setup: [README.md](README.md)

## Summary

Using Liquid via Etherscan is straightforward:

1. **Liquify** = Deposit backing tokens, receive liquid tokens + create pool liquidity
2. **Solidify** = Burn liquid tokens, withdraw backing tokens
3. **Buy** = Trade water for liquid tokens
4. **Sell** = Trade liquid tokens for water
5. **Cross-swap** = Trade one liquid for another using water as intermediary

All operations available through Etherscan's Contract → Write Contract interface. No special tools needed.

---

*Last updated: 2025-12-31*
