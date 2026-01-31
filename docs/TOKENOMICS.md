# Liquid Protocol Tokenomics

This document describes the economic mechanics that ensure **1 liquid = 1 solid** at equilibrium.

## Core Concepts

### Terminology

| Term | Symbol | Description |
|------|--------|-------------|
| **Solid** | `s` | The backing ERC-20 token |
| **Liquid** | `u` | The wrapped token with AMM liquidity |
| **Pool** | `P` | Liquid tokens held by the contract |
| **Lake** | `E` | Hub tokens held by the contract (for trading) |
| **Total Supply** | `T` | Total liquid tokens in existence |
| **Mass** | `M` | Solid tokens backing the liquid |

### The Equilibrium Condition

The system is at equilibrium when:

```
P / T = 1/2
```

At equilibrium, the pool holds exactly half of all liquid tokens. When this condition holds:
- `heat(s)` returns `u = s` (1 solid → 1 liquid)
- `cool(u)` returns `s = u` (1 liquid → 1 solid)

**This means liquid and solid have equal value at equilibrium.**

## Operations

### Heat (Solid → Liquid)

Converts solid backing tokens into liquid tokens.

```solidity
function heats(uint256 s) returns (uint256 u, uint256 p)
```

**Formula:**
```
p = 2 * s * P / T    (minted to pool)
u = 2 * s - p        (minted to user)
```

**Key property:** Heat preserves the P/T ratio.

| Condition | Result |
|-----------|--------|
| P/T = 1/2 | u = s (fair exchange) |
| P/T < 1/2 | u > s (favorable to heat) |
| P/T > 1/2 | u < s (unfavorable to heat) |

### Cool (Liquid → Solid)

Converts liquid tokens back into solid backing tokens.

```solidity
function cools(uint256 u) returns (uint256 s, uint256 p)
```

**Formula:**
```
s = u * T / (T - P) / 2    (solid returned)
p = 2 * s - u              (burned from pool)
```

**Key property:** Cool preserves the P/T ratio.

| Condition | Result |
|-----------|--------|
| P/T = 1/2 | s = u (fair exchange) |
| P/T < 1/2 | s < u (unfavorable to cool) |
| P/T > 1/2 | s > u (favorable to cool) |

### Buy (Hub → Liquid)

Purchases liquid from the pool using hub tokens.

```solidity
function buy(uint256 hub) returns (uint256 liquid)
```

**Effect on pool:**
- P decreases (liquid leaves pool)
- E increases (hub enters pool)
- T unchanged

**Effect on equilibrium:** P/T < 1/2 (breaks equilibrium)

### Sell (Liquid → Hub)

Sells liquid to the pool for hub tokens.

```solidity
function sell(uint256 liquid) returns (uint256 hub)
```

**Effect on pool:**
- P increases (liquid enters pool)
- E decreases (hub leaves pool)
- T unchanged

**Effect on equilibrium:** P/T > 1/2 (breaks equilibrium)

## Arbitrage Mechanics

### How Equilibrium Breaks

Only **buy** and **sell** operations can break the P/T = 1/2 equilibrium:

| Operation | Effect on P | Effect on T | Result |
|-----------|-------------|-------------|--------|
| buy | decreases | unchanged | P/T < 1/2 |
| sell | increases | unchanged | P/T > 1/2 |
| heat | increases | increases | P/T preserved |
| cool | decreases | decreases | P/T preserved |

### How Equilibrium Restores

Arbitrageurs profit by making the **opposite trade** that restores equilibrium:

**Scenario 1: After a Buy**
```
1. Trader buys liquid with hub
   → P decreases, P/T < 1/2
   → Pool has less liquid, more hub

2. Arbitrageur sells liquid for hub
   → P increases back toward equilibrium
   → Arbitrageur profits from price difference
```

**Scenario 2: After a Sell**
```
1. Trader sells liquid for hub
   → P increases, P/T > 1/2
   → Pool has more liquid, less hub

2. Arbitrageur buys liquid with hub
   → P decreases back toward equilibrium
   → Arbitrageur profits from price difference
```

### Profit Source

The arbitrageur's profit equals the trader's slippage loss:

```
Trader pays: tradeSize hub for beckU liquid
Fair value:  beckU * (E₀/P₀) hub
Slippage:    tradeSize - fairValue

Arbitrageur receives: ~tradeSize hub for beckU liquid
Profit:              alexW - fairValue ≈ slippage
```

## Invariants

### 1. Constant Product (AMM)

```
P * E = k  (maintained by buy/sell)
```

### 2. Heat/Cool Symmetry

```
Total minted in heat = 2 * s
Total burned in cool = 2 * u
```

### 3. Ratio Preservation

Heat and cool preserve whatever P/T ratio exists:

```
After heat: P'/T' = P/T
After cool: P'/T' = P/T
```

### 4. Equilibrium Value

At P/T = 1/2:
```
heats(s) → u = s
cools(u) → s = u
```

## Economic Summary

```
┌─────────────────────────────────────────────────────────────┐
│                     EQUILIBRIUM                              │
│                      P/T = 1/2                               │
│                    1 liquid = 1 solid                        │
└─────────────────────────────────────────────────────────────┘
         │                                    │
         │ buy (P↓)                          │ sell (P↑)
         ▼                                    ▼
┌─────────────────────┐          ┌─────────────────────┐
│    P/T < 1/2        │          │    P/T > 1/2        │
│    u > s            │          │    s > u            │
│  (heat favorable)   │          │  (cool favorable)   │
└─────────────────────┘          └─────────────────────┘
         │                                    │
         │ arbitrage: sell                   │ arbitrage: buy
         │                                    │
         └────────────────┬───────────────────┘
                          │
                          ▼
                   EQUILIBRIUM RESTORED
                   Arbitrageur profits
```

## Key Takeaways

1. **Equilibrium means equal value**: When P/T = 1/2, liquid and solid exchange 1:1

2. **Heat/cool maintain equilibrium**: These operations preserve whatever ratio exists

3. **Buy/sell break equilibrium**: Trading creates arbitrage opportunities

4. **Arbitrage restores equilibrium**: Opposite trades return P/T to 1/2

5. **Profit incentivizes stability**: Arbitrageurs are economically motivated to maintain 1 liquid = 1 solid
