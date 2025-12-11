#!/usr/bin/env node

/**
 * Generate Artifacts Script
 * Extracts ABIs from compiled contracts and creates configuration files
 * for frontend and backend integration
 */

const fs = require('fs');
const path = require('path');

// Paths
const FOUNDRY_OUT = path.join(__dirname, '..', 'out');
const FRONTEND_ABI_DIR = path.join(__dirname, '..', '..', 'frontend', 'src', 'constants', 'abi');
const FRONTEND_ADDRESSES = path.join(__dirname, '..', '..', 'frontend', 'src', 'constants', 'addresses.json');
const BACKEND_DIR = path.join(__dirname, '..', '..', 'backend');
const BACKEND_CONTRACTS = path.join(BACKEND_DIR, 'contracts.json');

// Contract names
const CONTRACTS = [
    'LooperVault',
    'LiquidationShieldVault',
    'ProtectionExecutor',
    'OriginLooper',
    'ReactiveLooper',
    'ReactiveShieldMonitor'
];

console.log('🚀 Generating artifacts...\n');

// Create directories if they don't exist
if (!fs.existsSync(FRONTEND_ABI_DIR)) {
    fs.mkdirSync(FRONTEND_ABI_DIR, { recursive: true });
    console.log('✅ Created frontend ABI directory');
}

if (!fs.existsSync(BACKEND_DIR)) {
    fs.mkdirSync(BACKEND_DIR, { recursive: true });
    console.log('✅ Created backend directory');
}

// Extract ABIs
console.log('\n📦 Extracting ABIs...');
const abis = {};

CONTRACTS.forEach(contractName => {
    const compiledPath = path.join(FOUNDRY_OUT, `${contractName}.sol`, `${contractName}.json`);

    if (!fs.existsSync(compiledPath)) {
        console.warn(`⚠️  Warning: ${contractName} not found at ${compiledPath}`);
        return;
    }

    const compiled = JSON.parse(fs.readFileSync(compiledPath, 'utf8'));
    const abi = compiled.abi;

    // Save to frontend
    const frontendAbiPath = path.join(FRONTEND_ABI_DIR, `${contractName}.json`);
    fs.writeFileSync(frontendAbiPath, JSON.stringify(abi, null, 2));
    console.log(`  ✅ ${contractName}.json`);

    // Store for backend
    abis[contractName] = abi;
});

// Read existing addresses.json or create template
console.log('\n📍 Processing addresses...');
let addresses;

if (fs.existsSync(FRONTEND_ADDRESSES)) {
    addresses = JSON.parse(fs.readFileSync(FRONTEND_ADDRESSES, 'utf8'));
    console.log('  ✅ Loaded existing addresses.json');
} else {
    addresses = {
        sepolia: {
            chainId: 11155111,
            looperVault: "NOT_DEPLOYED_YET",
            liquidationShieldVault: "NOT_DEPLOYED_YET",
            protectionExecutor: "NOT_DEPLOYED_YET",
            originLooper: "NOT_DEPLOYED_YET",
            callbackSender: "0x33Bbb7D0a2F1029550B0e91f653c4055DC9F4Dd8",
            deploymentBlock: 0
        },
        reactiveKopli: {
            chainId: 5318008,
            reactiveLooper: "NOT_DEPLOYED_YET",
            reactiveShieldMonitor: "NOT_DEPLOYED_YET",
            systemContract: "0x0000000000000000000000000000000000FFFFFF"
        }
    };
    console.log('  ✅ Created template addresses.json');
}

// Save addresses.json
fs.writeFileSync(FRONTEND_ADDRESSES, JSON.stringify(addresses, null, 2));
console.log('  ✅ Saved addresses.json');

// Generate backend contracts.json
console.log('\n🔧 Generating backend configuration...');

const backendConfig = {
    networks: {
        sepolia: {
            chainId: 11155111,
            rpcUrl: process.env.SEPOLIA_RPC || "https://rpc2.sepolia.org",
            contracts: {
                LooperVault: {
                    address: addresses.sepolia.looperVault,
                    abi: abis.LooperVault || [],
                    deploymentBlock: addresses.sepolia.deploymentBlock || 0
                },
                LiquidationShieldVault: {
                    address: addresses.sepolia.liquidationShieldVault,
                    abi: abis.LiquidationShieldVault || [],
                    deploymentBlock: addresses.sepolia.deploymentBlock || 0
                },
                ProtectionExecutor: {
                    address: addresses.sepolia.protectionExecutor,
                    abi: abis.ProtectionExecutor || [],
                    deploymentBlock: addresses.sepolia.deploymentBlock || 0
                },
                OriginLooper: {
                    address: addresses.sepolia.originLooper,
                    abi: abis.OriginLooper || [],
                    deploymentBlock: addresses.sepolia.deploymentBlock || 0
                }
            }
        },
        reactiveKopli: {
            chainId: 5318008,
            rpcUrl: process.env.REACTIVE_RPC || "https://kopli-rpc.rkt.ink",
            contracts: {
                ReactiveLooper: {
                    address: addresses.reactiveKopli.reactiveLooper,
                    abi: abis.ReactiveLooper || [],
                    systemContract: addresses.reactiveKopli.systemContract
                },
                ReactiveShieldMonitor: {
                    address: addresses.reactiveKopli.reactiveShieldMonitor,
                    abi: abis.ReactiveShieldMonitor || [],
                    systemContract: addresses.reactiveKopli.systemContract
                }
            }
        }
    },
    constants: {
        callbackSender: addresses.sepolia.callbackSender,
        systemContract: addresses.reactiveKopli.systemContract
    }
};

fs.writeFileSync(BACKEND_CONTRACTS, JSON.stringify(backendConfig, null, 2));
console.log('  ✅ Saved contracts.json');

// Summary
console.log('\n✨ Artifact generation complete!\n');
console.log('📁 Generated files:');
console.log(`  - Frontend ABIs: ${FRONTEND_ABI_DIR}`);
console.log(`  - Frontend addresses: ${FRONTEND_ADDRESSES}`);
console.log(`  - Backend config: ${BACKEND_CONTRACTS}`);

console.log('\n📝 Next steps:');
console.log('  1. Deploy contracts using: forge script script/DeployAll.s.sol:DeploySepoliaAll --rpc-url $SEPOLIA_RPC --broadcast -vvv');
console.log('  2. Update addresses.json with deployed addresses');
console.log('  3. Re-run this script to update backend configuration');
console.log('  4. Start your backend with the updated contracts.json\n');
