# Why You Should Make and Trade Solids

> **For the crypto hobbyist who's tired of fragmented liquidity and wants to launch tokens the right way.**

## What Are Solids?

Solids are ERC-20 tokens with **built-in ETH liquidity**. Every Solid token you create comes with an automated market maker (AMM) baked directly into the token contract itself.

No external DEXs. No liquidity fragmentation. No complicated pool deployments.

**Just create a token, and it's instantly tradeable.**

## The Problem with Normal Tokens

You've probably been through this before:

1. Create an ERC-20 token
2. Deploy it to mainnet
3. Now what? It's worthless without liquidity
4. Set up a Uniswap pool (more gas, more complexity)
5. Provide initial liquidity (lock up capital)
6. Hope traders find your pool
7. Deal with liquidity fragmentation across multiple DEXs

**With Solids, steps 3-7 disappear.**

## How Solids Work

### Creating a Solid (Making)

Making a new Solid costs just **0.001 ETH** (the creation fee, ~$3) plus gas. Thanks to EIP-1167 minimal proxy cloning, the gas cost is incredibly low - only **~198,000 gas**. At typical gas prices, that's:

- **10 gwei** (quiet times): ~$0.60 in gas → **~$3.60 total**
- **25 gwei** (moderate): ~$1.50 in gas → **~$4.50 total**
- **50 gwei** (busy): ~$3.00 in gas → **~$6.00 total**

**Total cost: $3.60-6** depending on network conditions. Here's what happens:

```solidity
// Create a new Solid token called "MyToken" with symbol "MTK"
solid.make{value: 0.001 ether}("MyToken", "MTK");
```

**You instantly receive:**
- **1% of total supply** (~60.2 million tokens) as the creator
- **99% automatically goes to the pool** paired with ETH
- A **deterministic address** (same name+symbol always produces same address)
- An **instantly tradeable token** with built-in liquidity

Total supply: **6.02214076 billion** tokens (10,000 moles × Avogadro's number, with 18 decimals)

The clever bit: the decimal point lands right after the 6, mirroring how Avogadro's number is written: **6.02214076** × 10²³

### Trading Solids

**Deposit ETH, get tokens:**
```solidity
// Send ETH to the contract
solid.deposit{value: 1 ether}();
// Returns tokens based on constant-product formula
```

Or just send ETH directly to the contract - it auto-converts to tokens!

**Withdraw tokens for ETH:**
```solidity
// Burn tokens, receive ETH
solid.withdraw(1000000000);
```

The AMM uses the **constant-product formula** (x × y = k) just like Uniswap, but it's built into the token itself.

## Why Solids Are Better

### 1. Zero Setup Friction

**Traditional approach:**
- Deploy token contract: ~2,000,000 gas (~$50+ at 25 gwei)
- Approve router: ~50,000 gas (~$1)
- Create Uniswap pool: ~4,000,000 gas (~$100+)
- Add liquidity: ~150,000 gas (~$4)
- **Total: $155+ and 4 transactions** (at 25 gwei)

**Solids approach (using EIP-1167 cloning):**
- Make token: ~198,000 gas (~$1.50 at 25 gwei) + 0.001 ETH fee (~$3)
- **Total: ~$4.50 and 1 transaction**

You save **97%** on total costs plus all the complexity. The gas portion is negligible - most of your cost is the 0.001 ETH creation fee.

### 2. Liquidity Can't Leave

With traditional DEX pools, liquidity providers can withdraw at any time, killing your token's tradability.

**With Solids, the initial 99% liquidity is permanently locked in the contract.** It can never be removed. Your token is always tradeable.

### 3. Fair Launch by Default

- **1% to creator** (you)
- **99% to pool** (everyone else)
- No presales, no VC allocation, no team vesting
- The economics are transparent and hardcoded

This is what fair launches should look like.

### 4. Deterministic Addresses

The same name and symbol always produce the same contract address. This means:
- **No frontrunning** - if someone tries to steal your token name, they create the same address you would have
- **Predictable deployments** - you can calculate addresses off-chain
- **No name squatting** - first person to make("Bitcoin", "BTC") owns it forever

### 5. Chemistry-Inspired Token Economics

The total supply is **6.02214076 billion** tokens (10,000 moles × Avogadro's number, scaled by 18 decimals).

Why? Because if you're going to create internet money, you might as well make it represent actual physical quantities. The decimal point lands exactly where it appears in Avogadro's number: **6.02214076**. This isn't accidental - it's 10,000 moles worth of tokens.

It's nerdy. It's fun. It's memorable. And it makes the token supply actually mean something.

## Real Use Cases for Hobbyists

### Community Tokens

Launch a token for your Discord, DAO, or group chat in one transaction. Instant tradability means your community can start trading immediately.

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

When you deposit ETH:
```
tokens_out = pool_tokens - (pool_tokens × pool_eth) / (pool_eth + eth_in)
```

When you withdraw tokens:
```
eth_out = pool_eth - (pool_eth × pool_tokens) / (pool_tokens + tokens_in)
```

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

### 1. Connect to the NOTHING contract

The "NOTHING" contract is the factory for all Solids. It's deployed at a deterministic address.

### 2. Make your Solid

```solidity
ISolid mySolid = NOTHING.make{value: 0.001 ether}("MyToken", "MTK");
```

### 3. Trade immediately

Your token is now live with 99% of supply in the pool and 1% in your wallet.

### 4. Share the contract address

Anyone can trade by sending ETH to the contract or calling `deposit()`.

## FAQ

**Q: Can I remove liquidity?**
A: No. The 99% pool liquidity is permanent. This is a feature, not a bug.

**Q: What if someone else makes my token name?**
A: They can't "steal" it - the same name+symbol always produces the same address. Whoever makes it first owns the creator share.

**Q: Can I make multiple Solids?**
A: Yes! Pay 0.001 ETH per token. Make as many as you want.

**Q: What blockchain is this on?**
A: Ethereum mainnet and major L2s (Base, Arbitrum, Optimism, Polygon).

**Q: Is this audited?**
A: The code uses battle-tested OpenZeppelin primitives and standard AMM math. Review the code yourself - it's only 86 lines.

**Q: What's the catch?**
A: No catch. It's an experiment in minimal viable liquidity. The 0.001 ETH fee prevents spam.

**Q: Can I use this for serious projects?**
A: The contracts are simple and secure, but do your own research. Start small, test thoroughly.

## Philosophy

Solids are built on three principles:

1. **Simplicity** - One transaction to launch a tradeable token
2. **Permanence** - Liquidity that can't be rugged
3. **Fairness** - No presales, no special allocations, just transparent code

We believe token launches should be accessible to everyone, not just projects with $100k+ budgets for liquidity bootstrapping.

## Try It Today

The future of token launches is simple, fair, and permanent.

**Make your first Solid. See how it feels to launch a token with instant liquidity.**

Then make another one for fun.

---

**Ready to start?** Check out the [deployment guide](README.md) or dive into the [technical docs](CLAUDE.md).

**Still skeptical?** Read the [smart contract code](src/Solid.sol) - it's only 86 lines. No hidden surprises.

**Built by crypto hobbyists, for crypto hobbyists.**

*Make something. Make it Solid.*
