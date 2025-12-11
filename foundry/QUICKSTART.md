# Quick Deployment Reference

## TL;DR - Deploy Everything Now

### Windows (Easiest)
```bash
cd foundry
DEPLOY.bat
```

### Linux/Mac
```bash
cd foundry

# 1. Build
forge build

# 2. Deploy Sepolia
forge script script/DeployAll.s.sol:DeploySepoliaAll --rpc-url $SEPOLIA_RPC --broadcast -vvv

# 3. Update addresses
node script/updateAddresses.js

# 4. Deploy Reactive
forge script script/DeployAll.s.sol:DeployReactiveAll --rpc-url $REACTIVE_RPC --broadcast -vvv

# 5. Update addresses again
node script/updateAddresses.js

# 6. Generate artifacts
node script/generateArtifacts.js
```

## Environment Variables (.env file)

```bash
SEPOLIA_RPC=https://rpc2.sepolia.org
SEPOLIA_PRIVATE_KEY=0x...
REACTIVE_RPC=https://kopli-rpc.rkt.ink
REACTIVE_PRIVATE_KEY=0x...
CALLBACK_SENDER_ADDR=0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8
SYSTEM_CONTRACT_ADDR=0x0000000000000000000000000000000000FFFFFF
```

After Sepolia deployment, add:
```bash
LOOPER_VAULT_ADDR=0x...
SHIELD_VAULT_ADDR=0x...
PROTECTION_EXECUTOR_ADDR=0x...
ORIGIN_LOOPER_ADDR=0x...
```

## What Gets Deployed

### Sepolia (4 contracts)
1. LooperVault
2. LiquidationShieldVault
3. ProtectionExecutor
4. OriginLooper

### Reactive Kopli (2 contracts)
5. ReactiveLooper
6. ReactiveShieldMonitor

## What Gets Generated

```
frontend/src/constants/
├── abi/
│   ├── LooperVault.json
│   ├── LiquidationShieldVault.json
│   ├── ProtectionExecutor.json
│   ├── OriginLooper.json
│   ├── ReactiveLooper.json
│   └── ReactiveShieldMonitor.json
└── addresses.json (updated with deployed addresses)

backend/
└── contracts.json (complete config with ABIs + addresses)
```

## Individual Contract Deployment

```bash
# Sepolia
forge script script/DeployAll.s.sol:DeployLooperVault --rpc-url $SEPOLIA_RPC --broadcast -vvv
forge script script/DeployAll.s.sol:DeployLiquidationShieldVault --rpc-url $SEPOLIA_RPC --broadcast -vvv
forge script script/DeployAll.s.sol:DeployProtectionExecutor --rpc-url $SEPOLIA_RPC --broadcast -vvv
forge script script/DeployAll.s.sol:DeployOriginLooper --rpc-url $SEPOLIA_RPC --broadcast -vvv

# Reactive
forge script script/DeployAll.s.sol:DeployReactiveLooper --rpc-url $REACTIVE_RPC --broadcast -vvv
forge script script/DeployAll.s.sol:DeployReactiveShieldMonitor --rpc-url $REACTIVE_RPC --broadcast -vvv
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| `forge: command not found` | Install Foundry: `curl -L https://foundry.paradigm.xyz \| bash && foundryup` |
| `environment variable not found` | Create `.env` file in `foundry/` directory |
| Compilation errors | `forge clean && forge build` |
| Node.js errors | Ensure Node.js v14+ is installed |

## Files Created

- `script/DeployAll.s.sol` - All deployment scripts
- `script/generateArtifacts.js` - ABI extraction
- `script/updateAddresses.js` - Address updater
- `script/DEPLOY.bat` - Windows automation
- `DEPLOYMENT.md` - Full guide
- `script/README.md` - Script docs

## Next Steps After Deployment

1. ✅ Verify all addresses in `frontend/src/constants/addresses.json`
2. ✅ Check ABIs generated in `frontend/src/constants/abi/`
3. ✅ Use `backend/contracts.json` in your backend
4. ✅ Test all features:
   - Looper bot iterations
   - Unwind position
   - Liquidation protection
   - Health factor monitoring
