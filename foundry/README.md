# Reactive Leveraged Looper 🔄

**Automated Leveraged Looping Strategy using Reactive Smart Contracts**

A hackathon submission for the Reactive Network bounty program.

## Overview

When a user deposits ETH, the Reactive contract automatically performs multiple supply/borrow/swap steps to reach a target leverage (75% LTV). It also supports safe unwinding of positions.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         SEPOLIA TESTNET                         │
├─────────────────────────────────────────────────────────────────┤
│  LooperVault                                                    │
│  ├── deposit() → Emits LoopRequested                            │
│  ├── executeLoopStep() → Borrow→Swap→Supply loop                │
│  ├── requestUnwind() → Emits UnwindRequested                    │
│  └── executeUnwind() → Safe unwind loop                         │
└─────────────────────────────────────────────────────────────────┘
                              ▲
                              │ Reactive Callbacks
                              │
┌─────────────────────────────────────────────────────────────────┐
│                      REACTIVE TESTNET                           │
├─────────────────────────────────────────────────────────────────┤
│  ReactiveLooper                                                 │
│  ├── Subscribes to LoopRequested, LoopStepCompleted, Unwind     │
│  ├── Emits callbacks to trigger next loop step                  │
│  └── Orchestrates multi-step execution                          │
└─────────────────────────────────────────────────────────────────┘
```

## Edge Cases Handled ✅

| Edge Case | Implementation |
|-----------|----------------|
| **Slippage** | `maxSlippage` parameter (default 1%), reverts if exceeded |
| **Liquidity** | Checks `availableBorrowsBase`, stops if insufficient |
| **Borrow Cap** | Queries `getReserveCaps()`, reverts if cap exceeded |
| **Health Factor** | Maintains min 1.5 HF, stops looping if too low |
| **Min Borrow** | Minimum 1 USDC borrow to avoid dust amounts |
| **Diminishing Returns** | Stops when LTV delta < 0.5% (no fixed iteration limit!) |

## Dynamic Termination (No Fixed Loops!) 🎯

Instead of a fixed iteration count, looping terminates when:
1. **Target LTV reached** - Mission accomplished
2. **Diminishing returns** - LTV improvement < 0.5% per loop
3. **Borrow too small** - Below minimum threshold
4. **Health factor risk** - Drops below 1.5

## Contracts

| Contract | Network | Description |
|----------|---------|-------------|
| `LooperVault.sol` | Sepolia | Main vault - handles deposits, loops, unwind |
| `ReactiveLooper.sol` | Reactive | Orchestrates multi-step loop execution |

## Setup

### Prerequisites
- Foundry installed
- Sepolia ETH (from faucet)
- Reactive testnet tokens

### Environment Variables
```bash
# Sepolia
export SEPOLIA_RPC="https://rpc2.sepolia.org"
export SEPOLIA_PRIVATE_KEY="your_private_key"

# Reactive Testnet
export REACTIVE_RPC="https://kopli-rpc.rkt.ink"
export REACTIVE_PRIVATE_KEY="your_private_key"

# Contract addresses (from Reactive docs)
export SYSTEM_CONTRACT_ADDR="0x0000000000000000000000000000000000FFFFFF"
export CALLBACK_SENDER_ADDR="0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8"
```

### Install & Build
```bash
cd foundry
forge install
forge build
```

### Test
```bash
forge test -vvv
```

## Deployment

### 1. Deploy to Sepolia
```bash
forge script script/Deploy.s.sol:DeploySepolia \
  --rpc-url $SEPOLIA_RPC \
  --broadcast \
  -vvv
```

### 2. Set vault address and deploy to Reactive
```bash
export VAULT_CONTRACT_ADDR="<vault_address_from_step_1>"

forge script script/Deploy.s.sol:DeployReactive \
  --rpc-url $REACTIVE_RPC \
  --broadcast \
  -vvv
```

### 3. Test deposit
```bash
forge script script/Deploy.s.sol:TestDeposit \
  --rpc-url $SEPOLIA_RPC \
  --broadcast \
  -vvv
```

## Workflow

1. **User deposits ETH** → `vault.deposit{value: 0.1 ether}()`
2. **Vault supplies to Aave** → Emits `LoopRequested`
3. **Reactive subscribes** → Detects event, emits callback
4. **Vault executes loop** → Borrow USDC → Swap to WETH → Supply
5. **Repeat** → Until target LTV (75%) or max loops (5)
6. **Unwind (optional)** → `vault.requestUnwind()` triggers safe exit

## Configuration

| Parameter | Default | Description |
|-----------|---------|-------------|
| `targetLTV` | 75% | Target leverage ratio |
| `maxSlippage` | 1% | Maximum swap slippage |
| `maxLoops` | 5 | Maximum loop iterations |
| `safeHealthFactor` | 1.5 | Minimum health factor to maintain |

## Transaction Hashes

*(Fill after deployment)*

| Step | Network | Tx Hash |
|------|---------|---------|
| Deploy Vault | Sepolia | |
| Deploy ReactiveLooper | Reactive | |
| User Deposit | Sepolia | |
| Loop Step 1 | Sepolia | |
| Loop Step N | Sepolia | |

## License

MIT
