# Deployment Scripts

Three-step deployment process for Solid protocol and periodic table elements.

## Step 1: Deploy Solid Protofactory

Deploy the base Solid contract that serves as the factory for all other Solids.

```bash
forge script script/Solid.sol \
  -f $chain \
  --private-key $tx_key \
  --broadcast \
  --verify \
  --delay 10 \
  --retries 10
```

**Output:** Save the deployed Solid address for Step 2.

## Step 2: Deploy SolidFactory

Deploy the batch factory that will create all elements in one transaction.

```bash
SOLID_ADDRESS=0x... forge script script/SolidFactory.sol \
  -f $chain \
  --private-key $tx_key \
  --broadcast \
  --verify \
  --delay 10 \
  --retries 10
```

**Output:** Save the deployed SolidFactory address for Step 3.

## Step 3: Create Solids

Invoke the factory to create Solids from a JSON file in a single transaction.

```bash
FACTORY_ADDRESS=0x... SOLIDS_PATH=script/elements.json forge script script/MakeSolids.sol \
  -f $chain \
  --private-key $tx_key \
  --broadcast
```

**Requirements:**
- Wallet must have at least 0.001 ETH per Solid to create
- Creates all solids in one transaction
- Skips solids that already exist (idempotent)
- `SOLIDS_PATH` must point to a JSON file with array of `{name, symbol}` objects

**Example:** To create all 118 elements:
```bash
FACTORY_ADDRESS=0x... SOLIDS_PATH=script/elements.json forge script script/MakeSolids.sol \
  -f $chain \
  --private-key $tx_key \
  --broadcast
```

## Files

- **[Solid.sol](Solid.sol)** - Deploys Solid protofactory
- **[SolidFactory.sol](SolidFactory.sol)** - Deploys SolidFactory with Solid reference
- **[MakeSolids.sol](MakeSolids.sol)** - Creates Solids from JSON file via factory
- **[elements.json](elements.json)** - Periodic table data (118 elements)
