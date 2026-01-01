# Introduction to Liquid Protocol

> A simple guide to using tokenized liquidity on Ethereum

## What is Liquid?

Liquid is a protocol that allows any ERC-20 token to become "liquid" — wrapped with built-in liquidity pools. Every liquid token is both:
- A standard ERC-20 token you can hold and transfer
- Its own automated market maker (AMM) with instant swap capability

You can interact with the entire protocol through Etherscan contract interactions. No custom frontend needed.

## The Core Metaphor

The protocol uses an intuitive temperature metaphor:

- **Cold/Solid/Ice** = Your original ERC-20 token (USDC, DAI, etc.)
  - Variable name in code: `cold`
  - Ice is the cold token for water specifically
  - Each liquid has its own solid (e.g., USDC is the solid for liquid-USDC)
- **Hot/Liquid** = The wrapped version with built-in liquidity (liquid-USDC, liquid-DAI)
  - Variable name in code: `hot`
  - Also called "hotter" when referring to other liquids in cross-swaps
- **Water** = The base Liquid instance used for cross-pool trading
- **Pool** = Hot tokens (liquids) held by the contract
- **Lake** = Water tokens held by the contract

## How to Use Liquid (via Etherscan)

All operations can be performed through Etherscan's "Write Contract" interface. No coding required.

### Step 1: Find the Liquid Contract

1. Go to Etherscan (etherscan.io for mainnet, or the appropriate network explorer)
2. Navigate to the liquid token contract address
3. Click the "Contract" tab
4. Click "Write Contract"
5. Click "Connect to Web3" to connect your wallet

### Step 2: Heat (Wrap Your Tokens)

**Goal:** Convert your ERC-20 tokens (cold) into hot tokens with built-in liquidity.

**Before you start:**
1. Go to your backing token contract (e.g., USDC)
2. Use the `approve` function to allow the liquid contract to spend your tokens
   - `spender`: The liquid contract address
   - `amount`: How much cold you want to heat (in token's decimals)

**To heat:**
1. On the liquid contract, find the `heat` function (with `uint256 cold` parameter)
2. Enter the amount (in token's decimals, e.g., `1000000000` for 1000 USDC with 6 decimals)
3. Click "Write" and confirm the transaction

**What happens:**
- You deposit 1,000 USDC (cold)
- You receive 1,000 hot tokens (liquid-USDC)
- The pool also gets 1,000 hot tokens
- Total: 2,000 hot minted from your 1,000 cold

This 2x minting creates instant liquidity. Half goes to you, half stays in the pool for trading.

### Step 3: Cool (Unwrap Back to Original Tokens)

**Goal:** Convert hot tokens back to the original cold ERC-20 tokens.

**To cool:**
1. On the liquid contract, find the `cool` function
2. Enter how many hot tokens you want to burn (e.g., `500000000` for 500 hot)
3. Click "Write" and confirm the transaction

**What happens:**
- Burns your hot tokens
- Burns matching amount from the pool
- Returns the cold backing tokens (USDC) proportional to pool reserves

The 2x burn (from you and pool) maintains symmetry with the 2x mint in heat.

### Step 4: Buy Hot with Water

**Goal:** Trade water tokens for hot tokens from the pool.

**Before you start:**
1. You need water tokens in your wallet

**To buy:**
1. On the liquid contract, find the `buy` function (the one with just `uint256 hot` parameter)
2. Enter how many hot tokens you want to buy
3. Click "Write" and confirm the transaction

**What happens:**
- Calculates water cost using: `water = pool * lake / (pool - hot) - lake`
- Transfers water from you to the pool's lake
- Transfers hot tokens from pool to you

**To check the cost before buying:**
- Use the "Read Contract" tab
- Call `buyQuote` with the amount you want to buy
- This shows how much water it will cost (no transaction needed)

### Step 5: Sell Hot for Water

**Goal:** Trade hot tokens for water tokens.

**To sell:**
1. On the liquid contract, find the `sell` function (the one with just `uint256 hot` parameter)
2. Enter how many hot tokens you want to sell
3. Click "Write" and confirm the transaction

**What happens:**
- Calculates water received using: `water = lake - pool * lake / (pool + hot)`
- Transfers hot tokens from you to the pool
- Transfers water from pool's lake to you

**To check the return before selling:**
- Use the "Read Contract" tab
- Call `sellQuote` with the amount you want to sell
- This shows how much water you'll receive

### Step 6: Cross-Liquid Swaps

**Goal:** Swap one hot token for another in a single transaction.

**Example:** Swap liquid-USDC for liquid-DAI

**To swap:**
1. On the first liquid contract (e.g., liquid-USDC), find the `buy` function with two parameters: `(uint256 hot, Liquid other)`
2. Enter the amount you want to buy of the target liquid
3. Enter the address of the target liquid contract (e.g., liquid-DAI address)
4. Click "Write" and confirm the transaction

**What happens:**
- Sells your hot liquid-USDC for water
- Buys hot liquid-DAI with that water
- All in one transaction

**To check the cost before swapping:**
- Use the "Read Contract" tab
- Call `buyQuote(uint256,Liquid)` with the amount and target liquid address
- This shows water used and how much hotter (of the other liquid) you'll receive

### Step 7: Check Pool State

**To see pool liquidity:**
1. Go to "Read Contract" tab
2. Call `balanceOf` with the liquid contract's own address
   - This shows how many hot tokens are in the pool

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
2. Use `heat(address stuff)` function (the factory function)
3. Enter your ERC-20 token address
4. Confirm transaction → new liquid token created
5. Find the new liquid contract address from the transaction logs
6. Approve and heat your tokens into this new liquid

### Workflow 2: Trade Between Two Liquid Tokens

**Example:** Trade liquid-USDC → liquid-DAI

1. On liquid-USDC contract, use `buy(uint256 hot, Liquid other)`
2. Enter amount of liquid-DAI you want
3. Enter liquid-DAI contract address
4. Confirm transaction
5. Receive liquid-DAI directly

### Workflow 3: Add Liquidity to Existing Liquid

1. Approve the backing token (cold, e.g., USDC)
2. Call `heat(amount)` on the liquid contract
3. Receive hot tokens (you get N, pool gets N)
4. Pool now has more liquidity for trading

### Workflow 4: Exit Your Position

**Option A: Cool to backing token**
1. Call `cool(amount)` on the liquid contract
2. Receive cold backing tokens based on pool reserves

**Option B: Sell for water, then cool water**
1. Call `sell(amount)` to convert hot → water
2. Go to water contract
3. Call `cool(amount)` to convert water → ice (water's cold backing token)

**Option C: Trade on external DEX**
- Hot tokens (liquids) are standard ERC-20s
- Can trade on Uniswap, Curve, or any DEX

## Reading Contract Information

### Check Your Balances

**Your hot token balance:**
1. "Read Contract" tab on liquid contract
2. Call `balanceOf(address)` with your wallet address

**Your cold backing token balance:**
1. Go to the backing token contract
2. Call `balanceOf(address)` with your wallet address

### Check Token Information

**Token name and symbol:**
- Call `name()` and `symbol()` (inherits from backing token)

**Decimals:**
- Call `decimals()` (matches backing token)

**What's the backing token?**
- Call `solid()` returns the cold backing token address

### Check if Address is a Liquid

1. Go to the water contract
2. Call `heated(address stuff)` with a backing token address
3. Returns `(address predicted, bytes32 salt)`
4. The `predicted` address is where that liquid is (or will be) deployed
5. Check if code exists at that address to see if it's already created

## Understanding Prices and Impact

### Price Impact

The constant-product formula means:
- Small trades have minimal price impact
- Large trades move the price significantly
- Infinite liquidity impossible (price approaches infinity as pool depletes)

### Checking Quotes

Always use quote functions before trading:
- `buyQuote(hot)` - Shows water cost to buy hot
- `sellQuote(hot)` - Shows water return from selling hot
- `buyQuote(hot, otherLiquid)` - Shows cost for cross-liquid swap
- `buyWithQuote(water)` - Shows hot received for spending water
- `sellForQuote(water)` - Shows hot needed to receive water

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
- Call `solid()` to see what cold token backs this liquid
- Check that backing token is legitimate

✅ **Verify the liquid is authentic (extra paranoid):**
- Go to the verified water contract on Etherscan
- Call `heated(address stuff)` with the backing token address
- Confirm the returned predicted address matches the liquid contract you're interacting with
- This ensures the liquid is legitimately created by the official water contract

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

## Why Liquid?

Liquid improves on traditional AMM designs in several key ways:

### Zero Fees Forever
- **No protocol fees**: The protocol charges zero fees on all operations (heat, cool, buy, sell, swaps)
- **Only gas costs**: You pay standard Ethereum transaction fees, nothing more
- **No governance to change this**: Fees are hardcoded as zero—no DAO can add them later
- **Developer monetization**: Protocol creators reserved a portion of Water tokens, not ongoing transaction fees

### Universal Token Connectivity
- **n pools instead of n²**: Traditional AMMs need separate pools for every token pair (USDC/DAI, USDC/WETH, DAI/WETH, etc.)
- **Single intermediary**: Water connects all liquid tokens, so you only need one pool per token
- **Cross-liquid swaps**: Trade any hot token for any other in a single transaction
- **Example**: With 100 tokens, Uniswap needs ~5,000 pairs; Liquid needs 100 pools

### No Governance Risk
- **Pure math pricing**: Prices determined solely by constant-product formula (pool × lake = k)
- **No admin keys**: No multisig, no DAO, no governance votes
- **No protocol updates**: Cannot change fee structure, formulas, or access control
- **Immutable**: What you see is what you get forever

**Note**: Backing token risk still exists. If your cold token (USDC, DAI, etc.) has governance issues or fails, the liquid token inherits that risk.

### Automatic Liquidity Creation
- **2x mint pattern**: When you heat 1,000 cold, you get 1,000 hot AND the pool gets 1,000 hot
- **Instant liquidity**: Every deposit automatically creates tradeable liquidity
- **No separate LP tokens**: You hold the hot tokens directly—no staking or complex LP positions
- **Simple exit**: Cool back to cold anytime, no unstaking required

## Comparison to Other Protocols

### vs. Uniswap

**Fees:**
- Liquid: Zero protocol fees
- Uniswap: 0.05% to 1% swap fees (varies by pool)

**Pair Management:**
- Liquid: n pools total, all connected through Water
- Uniswap: n² pairs needed for full connectivity

**Liquidity Provision:**
- Liquid: Automatic 2x mint when you heat (you get hot, pool gets hot)
- Uniswap: Manually add liquidity to specific pairs, receive separate LP tokens

**Trading:**
- Liquid: Trade hot tokens against water directly, or cross-swap any hot for any other
- Uniswap: Route through multiple pools for indirect pairs

### vs. Wrapped Tokens (WETH)

**Similar:**
- Both wrap underlying tokens (cold → hot is similar to ETH → WETH)
- Both maintain backing 1:1 on average

**Different:**
- Liquid: Built-in AMM for instant trading, 2x mint creates automatic liquidity, variable cool ratio
- WETH: No liquidity mechanism, strict 1:1 wrap/unwrap, just for compatibility

### vs. Curve/Balancer

**Formula:**
- Liquid: Constant-product (x × y = k), general-purpose
- Curve: Stableswap (optimized for low slippage on similar-priced assets)
- Balancer: Weighted pools with customizable ratios and multi-token pools

**Fees:**
- Liquid: Zero
- Curve/Balancer: Variable fees set by governance or pool creators

**Complexity:**
- Liquid: Simple wrap/unwrap + trade, single formula
- Curve/Balancer: Advanced pool configurations, multiple formulas, complex incentives

**Governance:**
- Liquid: None
- Curve/Balancer: Extensive governance for fees, pool parameters, token emissions

## Frequently Asked Questions

### How do I create a liquid for my token?

1. Go to the water contract on Etherscan
2. Use the `heat(address stuff)` factory function
3. Enter your token's address
4. Confirm the transaction
5. The new liquid address is in the transaction logs

### Can I lose money?

Yes. Risks include:
- Price impact on trades (AMM slippage)
- Backing token issues (if underlying cold token fails)
- Smart contract risk
- Market volatility between hot and cold

### Who provides the liquidity?

Everyone who heats. When you heat 1,000 USDC (cold):
- You get 1,000 hot tokens (liquid-USDC) to hold
- Pool gets 1,000 hot tokens to trade

You're both a holder and liquidity provider simultaneously.

### Are there fees?

No. The protocol charges no fees beyond standard Ethereum gas costs. There never will be fees.

The protocol developers reserved a portion of Water tokens as their monetization strategy, not ongoing transaction fees.

### Can I trade hot tokens on other DEXs?

Yes! Hot tokens (liquids) are standard ERC-20s. You can:
- Trade them on Uniswap, SushiSwap, etc.
- Add them to other liquidity pools
- Use them in any DeFi protocol that accepts ERC-20s

### What if the pool runs out?

The constant-product formula prevents complete drainage. As pool liquidity decreases, prices become increasingly unfavorable, creating natural resistance.

### How do I find all liquids?

1. Go to the water contract on Etherscan
2. Check the "Events" tab
3. Filter for `Heat(IERC20Metadata,Liquid)` events (the factory event)
4. Each event shows a new liquid and its backing token

### How are prices determined?

Pure math based on pool reserves:
```
buy:  water_cost = pool × lake / (pool - hot) - lake
sell: water_return = lake - pool × lake / (pool + hot)
```

No oracles, no governance, no external inputs.

### Can I get my exact deposit back?

On average, yes—but it varies above and below 1:1 over time.

When you cool, the amount of cold you receive depends on how much of the hot supply is in the pool versus held outside:
- **More hot in pool** (less held outside) → You get more cold per hot
- **Less hot in pool** (more held outside) → You get fewer cold per hot
- **On average across all users** → Approaches 1:1 ratio

The formula is: `cold = hot * solid.balanceOf(contract) / total_held_outside_pool`

Think of it like wrapping + being an LP simultaneously. Your share of cold backing tokens fluctuates based on pool distribution.

## Example Scenarios

### Scenario 1: Alice Adds Liquidity

**Starting state:**
- Alice has 10,000 USDC (cold)
- liquid-USDC pool has 5,000 hot tokens

**Alice's actions on Etherscan:**
1. USDC contract → `approve(liquidUSDC, 10000e6)`
2. liquid-USDC contract → `heat(10000e6)`

**Result:**
- Alice receives 10,000 hot tokens (liquid-USDC)
- Pool grows to 15,000 hot tokens
- Alice can now trade, hold, or cool

### Scenario 2: Bob Buys Hot

**Starting state:**
- Bob has 1,000 water
- liquid-USDC pool: 10,000 hot, 2,000 water

**Bob's actions on Etherscan:**
1. liquid-USDC contract → Read → `buyQuote(1000e6)`
   - Returns: ~222 water needed
2. liquid-USDC contract → Write → `buy(1000e6)`

**Result:**
- Bob receives 1,000 hot (liquid-USDC)
- Pool now: 9,000 hot, 2,222 water
- Bob paid ~222 water

### Scenario 3: Carol Swaps Liquid-USDC for Liquid-DAI

**Starting state:**
- Carol has 5,000 hot liquid-USDC

**Carol's actions on Etherscan:**
1. liquid-USDC contract → Read → `buyQuote(1000e6, liquidDAI_address)`
   - Check water used and hotter DAI received
2. liquid-USDC contract → Write → `buy(1000e6, liquidDAI_address)`

**Result:**
- Carol's hot liquid-USDC sold for water
- That water bought hotter liquid-DAI
- Carol now holds hot liquid-DAI
- Both pools' states updated

### Scenario 4: Dave Exits His Position

**Starting state:**
- Dave has 3,000 hot liquid-USDC

**Dave's actions on Etherscan:**
1. liquid-USDC contract → Read → `cool` preview (via staticcall or quote if available)
2. liquid-USDC contract → Write → `cool(3000e6)`

**Result:**
- Burns 3,000 hot from Dave
- Burns matching amount from pool
- Dave receives USDC (cold) based on pool reserves
- Pool liquidity decreases

## Advanced Usage

### Checking CREATE2 Addresses

Liquid uses deterministic addresses. Same cold backing token → same liquid address always.

**To predict a liquid address before creation:**
1. Go to the water contract on Etherscan
2. Use the "Read Contract" tab
3. Call `heated(address stuff)` with the cold backing token address
4. Returns `(address predicted, bytes32 salt)` - the future liquid contract address (works even if not created yet)

### Batch Operations

Etherscan doesn't support batch transactions directly, but you can:
1. Use a wallet like Safe (Gnosis Safe) for multi-calls
2. Write a simple contract that batches operations
3. Use Etherscan's "Write as Proxy" if available

### Reading Events

To see all activity on a liquid:
1. Go to "Events" tab on Etherscan
2. Filter by event type:
   - `Heat(Liquid,uint256)` - Deposits (heating cold → hot)
   - `Cool(Liquid,uint256,uint256)` - Withdrawals (cooling hot → cold)
   - `Bought(Liquid,uint256,uint256)` - Purchases from pool
   - `Sold(Liquid,uint256,uint256)` - Sales to pool
   - `Heat(IERC20Metadata,Liquid)` - New liquid created (factory event)

### Monitoring Pool Health

**Key metrics:**
1. Pool size: `balanceOf(liquidAddress)` - hot tokens in pool
2. Lake size: `water.balanceOf(liquidAddress)` - water in lake
3. Ratio: pool/lake indicates price level
4. Total supply: `totalSupply()` shows all hot tokens

**Health indicators:**
- Large pool + lake = good liquidity
- Very small pool = high price impact
- Zero lake = can't sell (but can still cool)

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

- Read the code: [src/Liquid.sol](src/Liquid.sol) (237 lines, well-commented)
- Technical documentation: [CLAUDE.md](CLAUDE.md)
- Development setup: [README.md](README.md)

## Summary

Using Liquid via Etherscan is straightforward:

1. **Heat** = Deposit cold backing tokens, receive hot tokens + create pool liquidity
2. **Cool** = Burn hot tokens, withdraw cold backing tokens
3. **Buy** = Trade water for hot tokens
4. **Sell** = Trade hot tokens for water
5. **BuyWith/SellFor** = Alternative forms specifying water amount instead of hot amount
6. **Cross-swap** = Trade one hot for another using water as intermediary

All operations available through Etherscan's Contract → Write Contract interface. No special tools needed.

---

*Last updated: 2025-12-31*
