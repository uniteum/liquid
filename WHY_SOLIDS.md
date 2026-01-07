# Why You Should Make and Trade Solids

> **For the crypto hobbyist who's tired of fragmented liquidity and wants to launch tokens the right way.**

## What Are Solids?

Solids are ERC-20 tokens with **built-in ETH liquidity**. Every Solid token you make comes with an automated market maker (AMM) baked directly into the token contract itself.

No external DEXs. No liquidity fragmentation. No complicated pool deployments.

**Just make a token, and it's instantly tradeable.**

## The Problem with Normal Tokens

You've probably been through this before:

1. Make an ERC-20 token
2. Deploy it to mainnet
3. Now what? It's worthless without liquidity
4. Set up a Uniswap pool (more gas, more complexity)
5. Provide initial liquidity (lock up capital)
6. Hope traders find your pool
7. Deal with liquidity fragmentation across multiple DEXs

**With Solids, steps 3-7 disappear.**

## How Solids Work

### Creating a Solid (Making)

Making a new Solid requires a **minimum of 0.001 ETH** plus gas. Thanks to EIP-1167 minimal proxy cloning, the gas cost is incredibly low - only **~198,000 gas**. At typical gas prices, that's:

- **10 gwei** (quiet times): ~$0.60 in gas → **~$3.60 total minimum**
- **25 gwei** (moderate): ~$1.50 in gas → **~$4.50 total minimum**
- **50 gwei** (busy): ~$3.00 in gas → **~$6.00 total minimum**

**But here's the key:** You should consider sending **more ETH** than the minimum. The ETH you send establishes the initial pool value and your token's starting price. More ETH = better initial liquidity and higher intrinsic value.

```solidity
// Make a new Solid token - consider sending more than the minimum!
solid.make{value: 1 ether}("MyToken", "MTK");  // Better starting price
```

**How the AMM works:**

The AMM assumes both sides of the pool have **equal value**. When you make a Solid:

- **50% of total supply** goes to you (the maker) - exactly **5,000 mol** worth
- **50% goes to the pool** - also **5,000 mol**
- Your ETH goes entirely into the pool, paired with those 5,000 mol tokens
- A **deterministic address** (same name+symbol always produces same address)
- An **instantly tradeable token** with built-in liquidity

Total supply: **6.02214076 billion** tokens (10,000 mol × Avogadro's number, with 18 decimals)

**Starting price scales linearly with your ETH:**
- Send 0.001 ETH → 5,000 mol tokens worth 0.001 ETH → 1 mol = 0.0000002 ETH
- Send 1 ETH → 5,000 mol tokens worth 1 ETH → 1 mol = 0.0002 ETH
- Send 10 ETH → 5,000 mol tokens worth 10 ETH → 1 mol = 0.002 ETH

The clever bit: the decimal point lands right after the 6, mirroring how Avogadro's number is written: **6.02214076** × 10²³. And as the maker, you get exactly 5,000 mol - half the supply, representing half the value.

### Trading Solids

**Deposit ETH, buy tokens:**
```solidity
// Buy tokens by depositing ETH
solid.deposit{value: 1 ether}();
// Returns tokens based on constant-product formula
```

**Withdraw tokens, get ETH:**
```solidity
// Sell tokens back for ETH
solid.withdraw(1000000000);
```

**Increase the ETH pool (add intrinsic value):**

Simply send ETH directly to the token contract address (like you would send to any wallet). This permanently increases the intrinsic value and price floor of all tokens - the ETH can never be withdrawn except through selling tokens on the AMM.

The AMM uses the **constant-product formula** (x × y = k) just like Uniswap, but it's built into the token itself.

## Why Solids Are Better

### 1. Zero Setup Friction

**Traditional approach:**
- Deploy token contract: ~2,000,000 gas (~$50+ at 25 gwei)
- Approve router: ~50,000 gas (~$1)
- Make Uniswap pool: ~4,000,000 gas (~$100+)
- Add liquidity: ~150,000 gas (~$4)
- **Total: $155+ and 4 transactions** (at 25 gwei)

**Solids approach (using EIP-1167 cloning):**
- Make token: ~198,000 gas (~$1.50 at 25 gwei) + 0.001 ETH fee (~$3)
- **Total: ~$4.50 and 1 transaction**

You save **97%** on total costs plus all the complexity. The gas portion is negligible - most of your cost is the 0.001 ETH creation fee.

### 2. Liquidity Can't Leave - Only Grow

With traditional DEX pools, liquidity providers can withdraw at any time, killing your token's tradability.

**With Solids, the initial 50% token liquidity is permanently locked in the contract.** The tokens in the pool can never be removed (only traded). Your token is always tradeable.

**Even better:** The ETH pool represents **intrinsic value** that can only increase. Anyone can send ETH directly to the contract to permanently boost the floor price, but that ETH can never be withdrawn except by selling tokens through the AMM. This creates a constantly rising price floor.

### 3. Fair Launch by Default

- **50% to maker** (you) - 5,000 mol
- **50% to pool** (everyone else) - 5,000 mol
- No presales, no VC allocation, no team vesting
- The economics are transparent and hardcoded
- **Equal value principle:** The AMM assumes your 5,000 mol and the pool's 5,000 mol have equal value, determined by the ETH you send

This is what fair launches should look like. You get half the supply, but the market gets the other half at a price you set with your initial ETH.

### 4. Deterministic Addresses

The same name and symbol always produce the same contract address. This means:
- **No frontrunning** - if someone tries to steal your token name, they make the same address you would have
- **Predictable deployments** - you can calculate addresses off-chain
- **No name squatting** - first person to make("Bitcoin", "BTC") owns it forever

### 5. Chemistry-Inspired Token Economics with Intrinsic Value

The total supply is **6.02214076 billion** tokens (10,000 mol × Avogadro's number, scaled by 18 decimals).

Why? Because if you're going to make internet money, you might as well make it represent actual physical quantities. The decimal point lands exactly where it appears in Avogadro's number: **6.02214076**. This isn't accidental - it's 10,000 mol worth of tokens.

**The ETH pool = intrinsic value:**
- Starts with whatever ETH the maker sends (minimum 0.001 ETH)
- Can only increase when people send ETH to the contract
- Can never be withdrawn except by selling tokens through the AMM
- Creates a **permanent price floor** that can only rise

It's nerdy. It's fun. It's memorable. And unlike most tokens, Solids have actual backing value.

## Real Use Cases for Hobbyists

### Community Tokens

Launch a token for your Discord, DAO, or group chat in one transaction. Instant tradability means your community can start trading immediately. Community members can even boost the token's intrinsic value by sending ETH directly to it.

### Experimental Economics

Want to test token bonding curves, game theory, or coordination mechanisms? Solids remove all the setup overhead so you can focus on the experiment.

### Memecoins Done Right

Every memecoin needs liquidity. With Solids, you skip straight to the fun part - building community and culture - without worrying about pools and liquidity management.

### NFT Project Tokens

Already have an NFT project? Launch a Solid as your ecosystem token. The fair launch mechanics and permanent liquidity make it perfect for community governance tokens.

### Personal Currency

Make a token representing you. Trade it with friends. Use it as social money. With a ~$4 entry price (total), why not?

## Technical Details (For the Curious)

### Constant-Product AMM

When you deposit ETH (buy tokens):
```
tokens_out = pool_tokens - (pool_tokens × pool_eth) / (pool_eth + eth_in)
```

When you withdraw tokens (sell for ETH):
```
eth_out = pool_eth - (pool_eth × pool_tokens) / (pool_tokens + tokens_in)
```

**Key insight:** The pool assumes **equal value** on both sides. If the pool has 5,000 mol tokens and 1 ETH, it values 5,000 mol = 1 ETH. Your starting price is determined by the ETH you send when making the Solid.

Same formula as Uniswap v2, but gas-optimized and built into the token.

### Security Features

- **Reentrancy protection** via EIP-1153 transient storage
- **Deterministic deployments** using OpenZeppelin Clones (EIP-1167)
- **Immutable parameters** - supply and distribution can't change
- **No admin keys** - completely decentralized after creation

### Gas Costs

Thanks to EIP-1167 minimal proxy cloning, Solids are extremely gas-efficient:

- **Make new Solid**: ~198,000 gas
  - At 10 gwei: **$0.60**
  - At 25 gwei: **$1.50**
  - At 50 gwei: **$3.00**
- **Deposit ETH**: ~50,000 gas ($0.30-$1.50)
- **Withdraw tokens**: ~60,000 gas ($0.40-$1.80)

**Why so cheap?** EIP-1167 clones don't redeploy the full contract bytecode. They deploy a tiny proxy that delegates to the NOTHING template. This makes the gas portion **10-50x cheaper** than deploying a traditional token contract.

Compare:
- Traditional ERC-20 + Uniswap setup: ~$155 total (mostly gas)
- Solids: ~$4.50 total (mostly the 0.001 ETH fee, gas is only ~$1.50)

## Getting Started

### Using Etherscan to Interact with Solids

You don't need to write any code - you can create and trade Solids directly through Etherscan.io!

#### 1. Find the NOTHING Contract

The "NOTHING" contract is the factory for all Solids. Go to its address on Etherscan (deployed at a deterministic address on mainnet and L2s).

#### 2. Make Your Solid via Etherscan

1. On Etherscan, go to the **Contract** tab
2. Click **Write Contract**
3. Click **Connect to Web3** and connect your wallet (MetaMask, WalletConnect, etc.)
4. Find the **make** function
5. Enter the following:
   - **payableAmount (ether)**: Enter at least `0.001` (or more for better initial liquidity!)
   - **name (string)**: Your token name (e.g., `"MyToken"`)
   - **symbol (string)**: Your token symbol (e.g., `"MTK"`)
6. Click **Write** and confirm the transaction

That's it! Your Solid is now created with instant liquidity.

#### 3. Find Your New Solid's Address

After the transaction confirms:
1. Click on the transaction hash
2. Look in the **Logs** section
3. Find the **Make** event - it will show your new Solid's contract address
4. Click on that address to view your new token contract

#### 4. Trade Your Solid via Etherscan

To **buy tokens** (deposit ETH):
1. Go to your Solid's contract on Etherscan
2. Click **Contract** → **Write Contract**
3. Connect your wallet
4. Find the **deposit** function
5. Enter ETH amount in **payableAmount**
6. Click **Write** and confirm

To **sell tokens** (withdraw ETH):
1. Same contract, **Write Contract** tab
2. Find the **withdraw** function
3. Enter the amount of tokens to sell (in wei, with 18 decimals)
   - Example: `1000000000000000000` = 1 token
4. Click **Write** and confirm

To **boost intrinsic value** (add ETH to the pool):
- Simply send ETH directly to the Solid's contract address from your wallet
- This permanently increases the price floor for everyone!

#### 5. Check Pool Status

To see the current pool state:
1. Go to **Read Contract** tab
2. Find the **pool** function
3. Click **Query** - it returns:
   - **solPool**: SOL tokens in the pool
   - **ethPool**: ETH in the pool (in wei)

You can also check:
- **balanceOf**: Your token balance (enter your address)
- **totalSupply**: Always 6.02214076e27 (10,000 mol)
- **name** and **symbol**: Token metadata

## FAQ

**Q: Can I remove liquidity?**
A: No. The 50% token pool liquidity is permanent. The ETH pool can only grow, never shrink (except through token sales). This is a feature, not a bug - it creates a rising price floor.

**Q: What if someone else makes my token name?**
A: They can't "steal" it - the same name+symbol always produces the same address. Whoever makes it first owns the maker share.

**Q: Can I make multiple Solids?**
A: Yes! Send at least 0.001 ETH per token (but consider sending more for better initial liquidity). Make as many as you want.

**Q: Should I send more than 0.001 ETH when making a Solid?**
A: Absolutely! The ETH you send determines your token's starting price. More ETH = higher initial value and better liquidity. The price scales linearly with your ETH contribution.

**Q: Can I increase the ETH pool after making a token?**
A: Yes! Anyone can send ETH directly to the contract address (just like sending to a regular wallet). This permanently increases the intrinsic value and price floor of all tokens.

**Q: What blockchain is this on?**
A: Ethereum mainnet and major L2s (Base, Arbitrum, Optimism, Polygon).

**Q: Is this audited?**
A: The code uses battle-tested OpenZeppelin primitives and standard AMM math. Review the code yourself - it's only 86 lines.

**Q: What's the catch?**
A: No catch. It's an experiment in minimal viable liquidity. The 0.001 ETH fee prevents spam.

**Q: Can I use this for serious projects?**
A: The contracts are simple and secure, but do your own research. Start small, test thoroughly.

## Philosophy

Solids are built on four principles:

1. **Simplicity** - One transaction to launch a tradeable token
2. **Permanence** - Liquidity that can't be rugged, only strengthened
3. **Fairness** - 50/50 split, no presales, no special allocations
4. **Intrinsic Value** - ETH backing that can only increase, creating a rising price floor

We believe tokens should have actual backing value, not just speculation. The ETH pool represents real value that can never be extracted except through the AMM.

## Try It Today

The future of token launches is simple, fair, and permanent.

**Make your first Solid. See how it feels to launch a token with instant liquidity.**

Then make another one for fun.

---

**Ready to start?** Check out the [deployment guide](README.md) or dive into the [technical docs](CLAUDE.md).

**Still skeptical?** Read the [smart contract code](src/Solid.sol) - it's only 86 lines. No hidden surprises.

**Built by crypto hobbyists, for crypto hobbyists.**

*Make something. Make it Solid.*
