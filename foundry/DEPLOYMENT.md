# Complete Deployment Guide

## Prerequisites

### Environment Variables

Create a `.env` file in the `foundry` directory:

```bash
# Sepolia Network
SEPOLIA_RPC=https://rpc2.sepolia.org
SEPOLIA_PRIVATE_KEY=your_private_key_here

# Reactive Kopli Network
REACTIVE_RPC=https://kopli-rpc.rkt.ink
REACTIVE_PRIVATE_KEY=your_private_key_here

# Contract Addresses (from Reactive docs)
CALLBACK_SENDER_ADDR=0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8
SYSTEM_CONTRACT_ADDR=0x0000000000000000000000000000000000FFFFFF
```

### Install Dependencies

```bash
cd foundry
forge install
```

## Deployment Steps

### Step 1: Compile Contracts

```bash
forge build
```

### Step 2: Deploy to Sepolia

Deploy all Sepolia contracts (LooperVault, LiquidationShieldVault, ProtectionExecutor, OriginLooper):

```bash
forge script script/DeployAll.s.sol:DeploySepoliaAll \
  --rpc-url $SEPOLIA_RPC \
  --broadcast \
  -vvv
```

**Save the deployed addresses from the output!**

### Step 3: Set Environment Variables

Export the deployed addresses:

```bash
export LOOPER_VAULT_ADDR=<LooperVault_address>
export SHIELD_VAULT_ADDR=<LiquidationShieldVault_address>
export PROTECTION_EXECUTOR_ADDR=<ProtectionExecutor_address>
export ORIGIN_LOOPER_ADDR=<OriginLooper_address>
```

Or add them to your `.env` file:

```bash
echo "LOOPER_VAULT_ADDR=<address>" >> .env
echo "SHIELD_VAULT_ADDR=<address>" >> .env
echo "PROTECTION_EXECUTOR_ADDR=<address>" >> .env
echo "ORIGIN_LOOPER_ADDR=<address>" >> .env
```

### Step 4: Deploy to Reactive Kopli

Deploy Reactive contracts (ReactiveLooper, ReactiveShieldMonitor):

```bash
forge script script/DeployAll.s.sol:DeployReactiveAll \
  --rpc-url $REACTIVE_RPC \
  --broadcast \
  -vvv
```

### Step 5: Update Addresses Configuration

Edit `frontend/src/constants/addresses.json` with your deployed addresses:

```json
{
  "sepolia": {
    "chainId": 11155111,
    "looperVault": "<LooperVault_address>",
    "liquidationShieldVault": "<LiquidationShieldVault_address>",
    "protectionExecutor": "<ProtectionExecutor_address>",
    "originLooper": "<OriginLooper_address>",
    "callbackSender": "0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8",
    "deploymentBlock": <block_number>
  },
  "reactiveKopli": {
    "chainId": 5318008,
    "reactiveLooper": "<ReactiveLooper_address>",
    "reactiveShieldMonitor": "<ReactiveShieldMonitor_address>",
    "systemContract": "0x0000000000000000000000000000000000FFFFFF"
  }
}
```

### Step 6: Generate Artifacts

Generate ABIs and backend configuration:

```bash
cd foundry
node script/generateArtifacts.js
```

This will:
- Extract ABIs from compiled contracts
- Save them to `frontend/src/constants/abi/`
- Generate `backend/contracts.json` with all contract details

## Individual Contract Deployment

If you need to deploy contracts individually:

### Sepolia Contracts

```bash
# LooperVault only
forge script script/DeployAll.s.sol:DeployLooperVault --rpc-url $SEPOLIA_RPC --broadcast -vvv

# LiquidationShieldVault only
forge script script/DeployAll.s.sol:DeployLiquidationShieldVault --rpc-url $SEPOLIA_RPC --broadcast -vvv

# ProtectionExecutor only (requires SHIELD_VAULT_ADDR)
forge script script/DeployAll.s.sol:DeployProtectionExecutor --rpc-url $SEPOLIA_RPC --broadcast -vvv

# OriginLooper only
forge script script/DeployAll.s.sol:DeployOriginLooper --rpc-url $SEPOLIA_RPC --broadcast -vvv
```

### Reactive Contracts

```bash
# ReactiveLooper only (requires LOOPER_VAULT_ADDR)
forge script script/DeployAll.s.sol:DeployReactiveLooper --rpc-url $REACTIVE_RPC --broadcast -vvv

# ReactiveShieldMonitor only (requires SHIELD_VAULT_ADDR and PROTECTION_EXECUTOR_ADDR)
forge script script/DeployAll.s.sol:DeployReactiveShieldMonitor --rpc-url $REACTIVE_RPC --broadcast -vvv
```

## Verification

### Test Deployment

Test the LooperVault deployment:

```bash
forge script script/Deploy.s.sol:TestDeposit \
  --rpc-url $SEPOLIA_RPC \
  --broadcast \
  -vvv
```

### Verify Artifacts

Check that all files were generated:

```bash
# Frontend ABIs
ls -la ../frontend/src/constants/abi/

# Frontend addresses
cat ../frontend/src/constants/addresses.json

# Backend configuration
cat ../backend/contracts.json
```

## Troubleshooting

### Missing Environment Variables

If you get "environment variable not found" errors:

```bash
# Load .env file
source .env

# Or use forge's --env-file flag
forge script script/DeployAll.s.sol:DeploySepoliaAll \
  --rpc-url $SEPOLIA_RPC \
  --broadcast \
  --env-file .env \
  -vvv
```

### Compilation Errors

If contracts fail to compile:

```bash
# Clean and rebuild
forge clean
forge build
```

### Deployment Failures

Check:
1. You have enough testnet ETH
2. RPC URLs are correct
3. Private keys are valid
4. All required environment variables are set

## Contract Addresses Reference

After deployment, you should have:

### Sepolia (Origin Chain)
- LooperVault
- LiquidationShieldVault
- ProtectionExecutor
- OriginLooper

### Reactive Kopli
- ReactiveLooper (subscribes to LooperVault events)
- ReactiveShieldMonitor (subscribes to LiquidationShieldVault events)

## Next Steps

1. **Start Backend**: Use the generated `backend/contracts.json` to configure your backend
2. **Start Frontend**: The frontend will use `addresses.json` and ABIs from `constants/abi/`
3. **Test Features**:
   - Looper bot iterations
   - Unwind position
   - Liquidation protection
   - All main contract functions

## Quick Reference

```bash
# Full deployment workflow
cd foundry
forge build
forge script script/DeployAll.s.sol:DeploySepoliaAll --rpc-url $SEPOLIA_RPC --broadcast -vvv
# Save addresses, then:
forge script script/DeployAll.s.sol:DeployReactiveAll --rpc-url $REACTIVE_RPC --broadcast -vvv
# Update addresses.json, then:
node script/generateArtifacts.js
```
