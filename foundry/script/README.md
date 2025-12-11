# Deployment Scripts

This directory contains scripts for deploying all Loopy-Loopy contracts and generating artifacts.

## Files

### Deployment Scripts

- **`DeployAll.s.sol`** - Comprehensive Foundry deployment scripts
  - `DeploySepoliaAll` - Deploy all 4 Sepolia contracts
  - `DeployReactiveAll` - Deploy both Reactive contracts
  - Individual deployment scripts for each contract

- **`Deploy.s.sol`** - Original deployment scripts (legacy)

- **`DEPLOY.bat`** - Windows batch script for automated deployment

### Artifact Generation

- **`generateArtifacts.js`** - Extract ABIs and create configuration files
  - Generates frontend ABIs in `frontend/src/constants/abi/`
  - Creates `backend/contracts.json` with all contract details

- **`updateAddresses.js`** - Interactive script to update deployed addresses

## Quick Start

### Option 1: Automated (Windows)

```bash
cd foundry
DEPLOY.bat
```

This will guide you through the entire deployment process.

### Option 2: Manual

```bash
# 1. Compile
forge build

# 2. Deploy to Sepolia
forge script script/DeployAll.s.sol:DeploySepoliaAll \
  --rpc-url $SEPOLIA_RPC \
  --broadcast \
  -vvv

# 3. Update addresses
node script/updateAddresses.js

# 4. Deploy to Reactive
forge script script/DeployAll.s.sol:DeployReactiveAll \
  --rpc-url $REACTIVE_RPC \
  --broadcast \
  -vvv

# 5. Update addresses again
node script/updateAddresses.js

# 6. Generate artifacts
node script/generateArtifacts.js
```

## Environment Variables Required

Create a `.env` file:

```bash
# Sepolia
SEPOLIA_RPC=https://rpc2.sepolia.org
SEPOLIA_PRIVATE_KEY=your_key

# Reactive Kopli
REACTIVE_RPC=https://kopli-rpc.rkt.ink
REACTIVE_PRIVATE_KEY=your_key

# Constants
CALLBACK_SENDER_ADDR=0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8
SYSTEM_CONTRACT_ADDR=0x0000000000000000000000000000000000FFFFFF
```

After Sepolia deployment, add:

```bash
LOOPER_VAULT_ADDR=<deployed_address>
SHIELD_VAULT_ADDR=<deployed_address>
PROTECTION_EXECUTOR_ADDR=<deployed_address>
ORIGIN_LOOPER_ADDR=<deployed_address>
```

## Contracts

### Sepolia (Origin Chain)
1. **LooperVault** - Main leveraged looping vault
2. **LiquidationShieldVault** - Liquidation protection vault
3. **ProtectionExecutor** - Receives reactive callbacks
4. **OriginLooper** - Alternative looper implementation

### Reactive Kopli
5. **ReactiveLooper** - Orchestrates looping callbacks
6. **ReactiveShieldMonitor** - Monitors health factors

## Generated Artifacts

After running `generateArtifacts.js`:

```
frontend/src/constants/
├── abi/
│   ├── LooperVault.json
│   ├── LiquidationShieldVault.json
│   ├── ProtectionExecutor.json
│   ├── OriginLooper.json
│   ├── ReactiveLooper.json
│   └── ReactiveShieldMonitor.json
└── addresses.json

backend/
└── contracts.json
```

## Troubleshooting

### "forge: command not found"

Install Foundry:
```bash
# Windows
curl -L https://foundry.paradigm.xyz | bash
foundryup
```

### "environment variable not found"

Make sure your `.env` file is in the `foundry` directory and contains all required variables.

### Compilation errors

```bash
forge clean
forge install
forge build
```

## See Also

- `DEPLOYMENT.md` - Detailed deployment guide
- `../README.md` - Project overview
