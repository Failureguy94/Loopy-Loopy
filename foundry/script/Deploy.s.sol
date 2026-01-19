// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LooperVault.sol";
import "../src/ReactiveLooper.sol";

/// @title DeploySepolia
/// @notice Deploy LooperVault to Sepolia testnet
contract DeploySepolia is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address callbackSender = vm.envAddress("CALLBACK_SENDER_ADDR");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy LooperVault
        LooperVault vault = new LooperVault(callbackSender);
        console.log("LooperVault deployed at:", address(vault));

        vm.stopBroadcast();

        console.log("\n=== Sepolia Deployment Complete ===");
        console.log("Vault:", address(vault));
        console.log("Callback Sender:", callbackSender);
        console.log("\nNext steps:");
        console.log("1. Set VAULT_CONTRACT_ADDR env var to:", address(vault));
        console.log("2. Deploy ReactiveLooper to Reactive testnet");
        console.log("3. Run: forge script script/GenerateArtifacts.s.sol");
    }
}

/// @title DeployReactive
/// @notice Deploy ReactiveLooper to Reactive testnet
contract DeployReactive is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");
        address systemContract = vm.envAddress("SYSTEM_CONTRACT_ADDR");
        address vaultContract = vm.envAddress("VAULT_CONTRACT_ADDR");

        vm.startBroadcast(deployerPrivateKey);

        // Deploy ReactiveLooper with some ETH for subscription fees
        ReactiveLooper looper = new ReactiveLooper{value: 0.1 ether}(
            systemContract,
            vaultContract
        );
        console.log("ReactiveLooper deployed at:", address(looper));

        vm.stopBroadcast();

        console.log("\n=== Reactive Deployment Complete ===");
        console.log("ReactiveLooper:", address(looper));
        console.log("Subscribed to vault:", vaultContract);
        console.log("\nThe system is now ready!");
        console.log(
            "Users can call vault.deposit() to start leveraged looping."
        );
        console.log("\nNext step:");
        console.log("Run: forge script script/GenerateArtifacts.s.sol");
    }
}

/// @title GenerateArtifacts
/// @notice Generate frontend artifacts (ABIs and addresses)
contract GenerateArtifacts is Script {
    function run() external view {
        console.log("\n=== Generating Frontend Artifacts ===");
        console.log("\nRun these commands to generate artifacts:");
        console.log("\n1. Extract ABIs:");
        console.log(
            "node -e \"const fs=require('fs');const d=JSON.parse(fs.readFileSync('out/LooperVault.sol/LooperVault.json'));fs.writeFileSync('../frontend/src/constants/abi/LooperVault.json',JSON.stringify(d.abi,null,2));\""
        );
        console.log(
            "\nnode -e \"const fs=require('fs');const d=JSON.parse(fs.readFileSync('out/ReactiveLooper.sol/ReactiveLooper.json'));fs.writeFileSync('../frontend/src/constants/abi/ReactiveLooper.json',JSON.stringify(d.abi,null,2));\""
        );
        console.log("\n2. Update addresses.json with deployed addresses");
        console.log("\n3. Restart frontend: cd ../frontend && npm run dev");
    }
}

/// @title TestDeposit
/// @notice Helper script to test deposit functionality
contract TestDeposit is Script {
    function run() external {
        uint256 userPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address vaultAddress = vm.envAddress("VAULT_CONTRACT_ADDR");

        vm.startBroadcast(userPrivateKey);

        LooperVault vault = LooperVault(payable(vaultAddress));
        vault.deposit{value: 0.05 ether}();

        console.log("Deposit successful!");
        console.log("Vault:", vaultAddress);
        console.log("Amount: 0.05 ETH");

        vm.stopBroadcast();
    }
}
