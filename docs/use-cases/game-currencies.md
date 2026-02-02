---
layout: default
title: Game Currencies
parent: "Use Cases"
permalink: /use-cases/game-currencies
nav_order: 2
---

Games already run on currencies. Not just gold or gems, but *life*, *energy*, *time*, *risk*, *reputation*, and *control*. These resources are scarce, spent, replenished, exchanged, and priced against one another. **Solids** provide a clean way to model these mechanics as explicit, composable currencies rather than hard‑coded rules.

This page describes how common game resources map naturally onto Solids, and why that matters.

## The Core Idea

A Solid is a token with a deterministic, monotonic pricing curve. Early units are cheap; later units cost more. There is no free minting, no arbitrary issuance, and no need for an external market maker. Price *is* the mechanism.

Games already use this structure implicitly. Solids make it explicit.

## Energy as a Currency

**Energy** (stamina, action points, mana) limits *throughput*.

Typical properties:

* Regenerates over time
* Caps actions per interval
* Can sometimes be stored or boosted

As a Solid:

* The base mint represents natural regeneration
* Buying additional energy increases marginal cost
* Hoarding energy becomes expensive

Result:

* Casual play is cheap
* Grinding is self‑throttling
* Bots face rising costs automatically

Energy becomes a **liquidity currency**: it prices how much a player can do *now*.

## Life as a Currency

**Life** (hit points, lives, health) prices *risk*.

Typical properties:

* Finite buffer against failure
* Can be sacrificed for power
* Loss imposes penalties or resets

As a Solid:

* Life can be explicitly staked
* Risky actions consume or lock life
* Recovery has increasing marginal cost

Result:

* High‑risk strategies are costly but possible
* Conservative play is cheap but slower
* Balance emerges from price, not tuning

Life becomes **collateral**: you stake it to attempt high‑variance outcomes.

## Time as a Currency

All games already price against **time**.

Examples:

* Cooldowns
* Build timers
* Daily caps
* Waiting to regenerate energy

As a Solid:

* Time-delayed minting replaces timers
* Players may accelerate at a rising cost
* Skipping time is never free, only priced

Result:

* No arbitrary waits
* No pay‑to‑win shortcuts
* Clear exchange rate between patience and progress

## Risk and Failure

Failure is often treated as a binary event: success or death.

With Solids:

* Risk can be fractional
* Partial losses are priced continuously
* Players choose how much risk to expose

Examples:

* Spend a small amount of life to scout
* Stake energy to increase success odds
* Lock currency as collateral for rare rewards

Risk becomes *tradeable*.

## Reputation and Access

Reputation systems gate content but are usually opaque.

As Solids:

* Reputation is earned by paying opportunity cost
* Losing reputation has real, increasing cost
* Grinding reputation faces diminishing returns

Result:

* Reputation inflation is naturally controlled
* Prestige retains meaning
* Access rights are economically enforced

## Territory and Control

Map control and territory generate ongoing value.

As Solids:

* Territory tokens accrue value over time
* Defending territory has opportunity cost
* Expansion increases marginal expense

Result:

* Empires naturally stabilize
* Overextension is punished economically
* No hard caps required

## Exchange Rates Between Currencies

The most interesting gameplay emerges when currencies convert:

* Life → Energy (berserk modes, sacrifices)
* Energy → Life (defense, evasion)
* Time → Energy (waiting)
* Reputation → Access → Rewards

Solids make these exchange rates *explicit and inspectable*.

Designers no longer guess balance constants; they choose curve shapes.

## Why This Matters

Traditional game economies rely on:

* Hard caps
* Hidden formulas
* Constant retuning
* Manual inflation control

Solids replace this with:

* Transparent pricing
* Automatic throttling
* Player‑driven optimization
* Minimal special cases

Games become **economic systems**, not rule forests.

## Summary

Life, energy, time, risk, reputation, and control already act like currencies. Solids let games model them honestly.

Instead of asking *"Is this balanced?"*, designers ask:

> *Is this priced correctly?*

That shift unlocks deeper, fairer, and more expressive game worlds.

## See also

* Bonding curves
* Game economy inflation control
* Risk‑reward design
* Deterministic pricing systems
