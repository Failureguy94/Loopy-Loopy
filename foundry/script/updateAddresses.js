#!/usr/bin/env node

/**
 * Update Addresses Script
 * Interactive script to update addresses.json with deployed contract addresses
 */

const fs = require('fs');
const path = require('path');
const readline = require('readline');

const ADDRESSES_FILE = path.join(__dirname, '..', '..', 'frontend', 'src', 'constants', 'addresses.json');

const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout
});

function question(query) {
    return new Promise(resolve => rl.question(query, resolve));
}

async function main() {
    console.log('📍 Update Contract Addresses\n');

    // Load existing addresses
    let addresses;
    if (fs.existsSync(ADDRESSES_FILE)) {
        addresses = JSON.parse(fs.readFileSync(ADDRESSES_FILE, 'utf8'));
        console.log('✅ Loaded existing addresses.json\n');
    } else {
        console.error('❌ addresses.json not found!');
        process.exit(1);
    }

    console.log('Current addresses:');
    console.log(JSON.stringify(addresses, null, 2));
    console.log('\n');

    // Ask which network to update
    const network = await question('Which network to update? (sepolia/reactive): ');

    if (network.toLowerCase() === 'sepolia') {
        console.log('\n=== Sepolia Contracts ===\n');

        const looperVault = await question('LooperVault address (or press Enter to skip): ');
        if (looperVault.trim()) addresses.sepolia.looperVault = looperVault.trim();

        const shieldVault = await question('LiquidationShieldVault address (or press Enter to skip): ');
        if (shieldVault.trim()) addresses.sepolia.liquidationShieldVault = shieldVault.trim();

        const protectionExecutor = await question('ProtectionExecutor address (or press Enter to skip): ');
        if (protectionExecutor.trim()) addresses.sepolia.protectionExecutor = protectionExecutor.trim();

        const originLooper = await question('OriginLooper address (or press Enter to skip): ');
        if (originLooper.trim()) addresses.sepolia.originLooper = originLooper.trim();

        const deploymentBlock = await question('Deployment block number (or press Enter to skip): ');
        if (deploymentBlock.trim()) addresses.sepolia.deploymentBlock = parseInt(deploymentBlock.trim());

    } else if (network.toLowerCase() === 'reactive') {
        console.log('\n=== Reactive Kopli Contracts ===\n');

        const reactiveLooper = await question('ReactiveLooper address (or press Enter to skip): ');
        if (reactiveLooper.trim()) addresses.reactiveKopli.reactiveLooper = reactiveLooper.trim();

        const shieldMonitor = await question('ReactiveShieldMonitor address (or press Enter to skip): ');
        if (shieldMonitor.trim()) addresses.reactiveKopli.reactiveShieldMonitor = shieldMonitor.trim();

    } else {
        console.error('❌ Invalid network. Please choose "sepolia" or "reactive"');
        rl.close();
        process.exit(1);
    }

    // Save updated addresses
    fs.writeFileSync(ADDRESSES_FILE, JSON.stringify(addresses, null, 2));
    console.log('\n✅ Updated addresses.json\n');

    console.log('New addresses:');
    console.log(JSON.stringify(addresses, null, 2));

    console.log('\n📝 Next steps:');
    console.log('  1. Run: node script/generateArtifacts.js');
    console.log('  2. Start your backend with updated contracts.json\n');

    rl.close();
}

main().catch(error => {
    console.error('Error:', error);
    rl.close();
    process.exit(1);
});
