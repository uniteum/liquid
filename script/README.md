# Deployment Scripts

Three-step deployment process for Solid protocol and periodic table elements.

## Step 1: Deploy Solid Protofactory

Deploy the base Solid contract that serves as the factory for all other Solids.

```bash
forge script script/Solid.s.sol \
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
SOLID_ADDRESS=0x... forge script script/SolidFactory.s.sol \
  -f $chain \
  --private-key $tx_key \
  --broadcast \
  --verify \
  --delay 10 \
  --retries 10
```

**Output:** Save the deployed SolidFactory address for Step 3.

## Step 3: Create All Elements

Invoke the factory to create all 118 elements from `elements.json` in a single transaction.

```bash
FACTORY_ADDRESS=0x... forge script script/MakeElements.s.sol \
  -f $chain \
  --private-key $tx_key \
  --broadcast
```

**Requirements:**
- Wallet must have at least 0.118 ETH (118 elements × 0.001 ETH)
- Creates all elements in one transaction
- Skips elements that already exist (idempotent)

## Files

- **[Solid.s.sol](Solid.s.sol)** - Deploys Solid protofactory
- **[SolidFactory.s.sol](SolidFactory.s.sol)** - Deploys SolidFactory with Solid reference
- **[MakeElements.s.sol](MakeElements.s.sol)** - Creates all elements via factory
- **[elements.json](elements.json)** - Periodic table data (118 elements)
