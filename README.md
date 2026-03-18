# Loopy-Loopy

**Reactive leveraged looping strategy for Aave on Sepolia**, built as a hackathon submission for the Reactive Network bounty.

When a user deposits ETH into the vault on Sepolia, the system automatically performs multiple borrow → swap → supply loops to reach a target leverage (default 75% LTV). Execution is coordinated through Reactive Network callbacks so the strategy can progress without centralized keepers. The system also supports safe unwinding and liquidation protection.

## Architecture

**Sepolia (origin chain)**
- **LooperVault**: accepts deposits, executes loop steps, and supports unwind requests.
- **LiquidationShieldVault** + **ProtectionExecutor**: liquidation protection flow.
- **OriginLooper**: alternative looper implementation.

**Reactive Kopli (Reactive testnet)**
- **ReactiveLooper**: subscribes to vault events and emits callbacks to trigger the next loop step.
- **ReactiveShieldMonitor**: monitors liquidation shield events.

## Repository layout

- `foundry/` – smart contracts, deployment scripts, and tests (Foundry).
- `frontend/` – React + Vite UI that interacts with deployed contracts.

## Prerequisites

- [Foundry](https://book.getfoundry.sh/) (for contracts)
- Node.js 18+ (for the frontend)
- Sepolia & Reactive RPC endpoints and testnet funds

## Quickstart (local)

### Contracts
```bash
cd foundry
forge install
forge build
forge test -vvv
```

### Frontend
```bash
cd frontend
npm install
npm run dev
```

## Deployment

Deployment is fully scripted in `foundry/script`. See:
- `foundry/QUICKSTART.md` for a TL;DR deploy flow
- `foundry/DEPLOYMENT.md` for the full guide

After deploying, update addresses and generate ABIs for the frontend:
```bash
cd foundry
node script/updateAddresses.js
node script/generateArtifacts.js
```

## Frontend configuration

The UI reads contract addresses and ABIs from:
- `frontend/src/constants/addresses.json`
- `frontend/src/constants/abi/`

Once those are updated, the frontend can connect to the deployed contracts and display loop status and health metrics.
