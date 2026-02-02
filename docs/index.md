---
layout: home
title: Home
nav_order: 1
---

# Solid Protocol

Solids are Ethereum tokens that have uniquely powerful properties:
- **Instantly Tradeable** - Each Solid has its own ETH liquidity pool with buy and sell functions
- **Fair Launch** - 100% of supply goes to the liquidity pool upon creation
- **Price Floor** - Virtual 1 ETH ensures tokens always have minimum value
- **Permissionless** - Anyone can make a new Solid: no exchange, operator, or custom UI is required
- **Easy to Make** - Anyone can make their own token in a few simple steps using major block explorers
- **Inexpensive** - Each token is deployed as a minimal proxy contract (clone), needing little gas
- **Deterministic** - Token addresses are predictable via CREATE2 based on name and symbol

## Why Use Solids?

Solids are useful when you need transparent, trustless value transfer without intermediaries. Examples so far include:

- **Personal gift certificates** - Back tokens with ETH to create gifts that gently encourage spending through curve dynamics
- **Game currencies** - Model energy, life, time, and reputation as explicit economic resources rather than hard-coded rules

These are just the beginning. See [Use Cases]({{ site.baseurl }}/use-cases) for details and emerging applications.

## How It Works

Each Solid token is an ERC-20 with a built-in constant-product AMM. All functions can be called directly through block explorers like [Etherscan](https://etherscan.io){:target="_blank"} or [Blockscout](https://eth.blockscout.com){:target="_blank"}—no custom interface required.

### Write Operations

1. **make** - Call [make(name, symbol)](https://etherscan.io/token/{{site.data.tokens.NOTHING.address}}#writeContract#F3){:target="_blank"} on any Solid to create a new one
2. **buy** - Send ETH when calling [buy()](https://etherscan.io/token/{{site.data.tokens.1.address}}#writeContract#F2){:target="_blank"} to receive Solid tokens from the pool
3. **sell** - Call [sell(amount)](https://etherscan.io/token/{{site.data.tokens.1.address}}#writeContract#F4){:target="_blank"} to exchange Solid tokens back for ETH
4. **sellFor** - Call [sellFor(solid, amount)](https://etherscan.io/token/{{site.data.tokens.1.address}}#writeContract#F5){:target="_blank"} to swap one Solid for another in a single transaction (no approval needed)

### Read Operations

1. **pool** - Call [pool()](https://etherscan.io/token/{{site.data.tokens.1.address}}#readContract#F9){:target="_blank"} to get the current pool state (Solid balance, virtual ETH balance)
2. **buys** - Call [buys(ethAmount)](https://etherscan.io/token/{{site.data.tokens.1.address}}#readContract#F5){:target="_blank"} to preview how many tokens you'd receive for a given ETH amount
3. **sells** - Call [sells(solidAmount)](https://etherscan.io/token/{{site.data.tokens.1.address}}#readContract#F10){:target="_blank"} to preview how much ETH you'd receive for selling tokens
4. **sellsFor** - Call [sellsFor(solid, amount)](https://etherscan.io/token/{{site.data.tokens.1.address}}#readContract#F11){:target="_blank"} to preview a Solid-to-Solid swap
5. **made** - Call [made(name, symbol)](https://etherscan.io/token/{{site.data.tokens.NOTHING.address}}#readContract#F7){:target="_blank"} to check if a Solid exists and get its address

The protocol uses the constant product formula (`x * y = k`) for pricing, ensuring liquidity is always available.

The example links above point to [Uniteum 1 (1)](https://etherscan.io/token/{{site.data.tokens.1.address}}){:target="_blank"}—to interact with a different Solid, navigate to that token's page on the block explorer. If you'd like to support continued development of this protocol, buying some 1 is a simple way to do so.

## Key Properties

| Property | Value |
|:---------|:------|
| Total Supply | 6.02214076 × 10²³ (Avogadro's number) |
| Starting Price | ~602,214 tokens per ETH |
| Price Floor | Guaranteed by virtual 1 ETH |
| Decimals | 18 |

## Resources

- [GitHub Repository](https://github.com/uniteum/liquid)
- [Foundry Book](https://book.getfoundry.sh/)
- [EIP-1167 Clones](https://eips.ethereum.org/EIPS/eip-1167)
