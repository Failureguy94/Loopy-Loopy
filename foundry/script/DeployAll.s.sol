// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Script.sol";
import "../src/LooperVault.sol";
import "../src/OriginLooper.sol";
import "../src/ProtectionExecutor.sol";
import "../src/ReactiveLooper.sol";
import "../src/ReactiveShieldMonitor.sol";
import "../src/LiquidationShieldVault.sol";

contract DeploySepoliaAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address callbackSender = vm.envAddress("CALLBACK_SENDER_ADDR");

        vm.startBroadcast(deployerPrivateKey);

        LooperVault looperVault = new LooperVault(callbackSender);
        console.log("LooperVault deployed at:", address(looperVault));

        LiquidationShieldVault shieldVault = new LiquidationShieldVault(
            callbackSender
        );
        console.log(
            "LiquidationShieldVault deployed at:",
            address(shieldVault)
        );

        ProtectionExecutor protectionExecutor = new ProtectionExecutor(
            address(shieldVault),
            callbackSender
        );
        console.log(
            "ProtectionExecutor deployed at:",
            address(protectionExecutor)
        );

        OriginLooper originLooper = new OriginLooper(callbackSender);
        console.log("OriginLooper deployed at:", address(originLooper));

        vm.stopBroadcast();

        console.log("\n=== Sepolia Deployment Complete ===");
        console.log("LooperVault:", address(looperVault));
        console.log("LiquidationShieldVault:", address(shieldVault));
        console.log("ProtectionExecutor:", address(protectionExecutor));
        console.log("OriginLooper:", address(originLooper));
        console.log("Callback Sender:", callbackSender);
        console.log("\n=== Next Steps ===");
        console.log("1. Set environment variables:");
        console.log("   export LOOPER_VAULT_ADDR=", address(looperVault));
        console.log("   export SHIELD_VAULT_ADDR=", address(shieldVault));
        console.log(
            "   export PROTECTION_EXECUTOR_ADDR=",
            address(protectionExecutor)
        );
        console.log("   export ORIGIN_LOOPER_ADDR=", address(originLooper));
        console.log("2. Deploy Reactive contracts:");
        console.log(
            "   forge script script/DeployAll.s.sol:DeployReactiveAll --rpc-url $REACTIVE_RPC --broadcast -vvv"
        );
    }
}

contract DeployReactiveAll is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");
        address systemContract = vm.envAddress("SYSTEM_CONTRACT_ADDR");
        address looperVaultAddr = vm.envAddress("LOOPER_VAULT_ADDR");
        address shieldVaultAddr = vm.envAddress("SHIELD_VAULT_ADDR");
        address protectionExecutorAddr = vm.envAddress(
            "PROTECTION_EXECUTOR_ADDR"
        );

        vm.startBroadcast(deployerPrivateKey);

        ReactiveLooper reactiveLooper = new ReactiveLooper(
            systemContract,
            looperVaultAddr
        );
        console.log("ReactiveLooper deployed at:", address(reactiveLooper));

        ReactiveShieldMonitor shieldMonitor = new ReactiveShieldMonitor(
            systemContract,
            shieldVaultAddr,
            protectionExecutorAddr
        );
        console.log(
            "ReactiveShieldMonitor deployed at:",
            address(shieldMonitor)
        );

        vm.stopBroadcast();

        console.log("\n=== Reactive Deployment Complete ===");
        console.log("ReactiveLooper:", address(reactiveLooper));
        console.log("ReactiveShieldMonitor:", address(shieldMonitor));
        console.log("System Contract:", systemContract);
        console.log("\n=== Next Steps ===");
        console.log("1. Generate artifacts:");
        console.log("   node script/generateArtifacts.js");
        console.log(
            "2. Update frontend addresses.json with deployed addresses"
        );
    }
}

contract DeployLooperVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address callbackSender = vm.envAddress("CALLBACK_SENDER_ADDR");

        vm.startBroadcast(deployerPrivateKey);
        LooperVault vault = new LooperVault(callbackSender);
        vm.stopBroadcast();

        console.log("LooperVault deployed at:", address(vault));
    }
}

contract DeployLiquidationShieldVault is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address callbackSender = vm.envAddress("CALLBACK_SENDER_ADDR");

        vm.startBroadcast(deployerPrivateKey);
        LiquidationShieldVault vault = new LiquidationShieldVault(
            callbackSender
        );
        vm.stopBroadcast();

        console.log("LiquidationShieldVault deployed at:", address(vault));
    }
}

contract DeployProtectionExecutor is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address callbackSender = vm.envAddress("CALLBACK_SENDER_ADDR");
        address shieldVaultAddr = vm.envAddress("SHIELD_VAULT_ADDR");

        vm.startBroadcast(deployerPrivateKey);
        ProtectionExecutor executor = new ProtectionExecutor(
            shieldVaultAddr,
            callbackSender
        );
        vm.stopBroadcast();

        console.log("ProtectionExecutor deployed at:", address(executor));
    }
}

contract DeployOriginLooper is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("SEPOLIA_PRIVATE_KEY");
        address callbackSender = vm.envAddress("CALLBACK_SENDER_ADDR");

        vm.startBroadcast(deployerPrivateKey);
        OriginLooper looper = new OriginLooper(callbackSender);
        vm.stopBroadcast();

        console.log("OriginLooper deployed at:", address(looper));
    }
}

contract DeployReactiveLooper is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");
        address systemContract = vm.envAddress("SYSTEM_CONTRACT_ADDR");
        address vaultContract = vm.envAddress("LOOPER_VAULT_ADDR");

        vm.startBroadcast(deployerPrivateKey);
        ReactiveLooper looper = new ReactiveLooper(
            systemContract,
            vaultContract
        );
        vm.stopBroadcast();

        console.log("ReactiveLooper deployed at:", address(looper));
    }
}

contract DeployReactiveShieldMonitor is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("REACTIVE_PRIVATE_KEY");
        address systemContract = vm.envAddress("SYSTEM_CONTRACT_ADDR");
        address shieldVaultAddr = vm.envAddress("SHIELD_VAULT_ADDR");
        address protectionExecutorAddr = vm.envAddress(
            "PROTECTION_EXECUTOR_ADDR"
        );

        vm.startBroadcast(deployerPrivateKey);
        ReactiveShieldMonitor monitor = new ReactiveShieldMonitor(
            systemContract,
            shieldVaultAddr,
            protectionExecutorAddr
        );
        vm.stopBroadcast();

        console.log("ReactiveShieldMonitor deployed at:", address(monitor));
    }
}
