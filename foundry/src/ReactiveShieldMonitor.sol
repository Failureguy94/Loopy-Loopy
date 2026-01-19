// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "reactive-lib/abstract-base/AbstractReactive.sol";
import "reactive-lib/abstract-base/AbstractPayer.sol";
import "reactive-lib/interfaces/IReactive.sol";
import "reactive-lib/interfaces/IPayer.sol";

contract ReactiveShieldMonitor is AbstractReactive {
    // Origin chain ID (Sepolia)
    uint256 public constant ORIGIN_CHAIN_ID = 11155111;

    // Destination chain ID (Sepolia - same for this demo)
    uint256 public constant DESTINATION_CHAIN_ID = 11155111;

    // Protection threshold (1.2 * 1e18)
    uint256 public constant PROTECTION_THRESHOLD = 12e17;

    // Gas limit for callbacks
    uint64 public constant CALLBACK_GAS_LIMIT = 1000000;

    // Vault contract address on origin chain
    address public vaultContract;

    // Protection executor contract address on destination chain
    address public executorContract;

    // Track protected users to avoid duplicate callbacks
    mapping(address => uint256) public lastProtectionBlock;

    // Events
    event ProtectionCallbackEmitted(address indexed user, uint256 healthFactor);
    event SubscriptionCreated(address indexed vault);

    constructor(
        address _vaultContract,
        address _executorContract
    ) payable {
        vaultContract = _vaultContract;
        executorContract = _executorContract;

        // Only subscribe when deployed on Reactive Network (not in ReactVM)
        if (!vm) {
            // Subscribe to HealthFactorUpdated events from the vault
            bytes32 eventSig = keccak256(
                "HealthFactorUpdated(address,uint256,uint256)"
            );

            service.subscribe(
                ORIGIN_CHAIN_ID,
                _vaultContract,
                uint256(eventSig),
                REACTIVE_IGNORE, // topic1 (user) - wildcard
                REACTIVE_IGNORE, // topic2
                REACTIVE_IGNORE  // topic3
            );

            emit SubscriptionCreated(_vaultContract);
        }
    }

    /// @notice React to HealthFactorUpdated events
    /// @dev Called by Reactive Network when subscribed events occur
    function react(LogRecord calldata log) external vmOnly {
        // Verify event source
        if (log.chain_id != ORIGIN_CHAIN_ID) return;
        if (log._contract != vaultContract) return;

        // Verify event signature (HealthFactorUpdated)
        bytes32 expectedSig = keccak256(
            "HealthFactorUpdated(address,uint256,uint256)"
        );
        if (log.topic_0 != uint256(expectedSig)) return;

        // Decode user from indexed topic1
        address user = address(uint160(log.topic_1));

        // Decode health factor from data (first 32 bytes)
        uint256 healthFactor = abi.decode(log.data, (uint256));

        // Check if protection is needed
        if (healthFactor >= PROTECTION_THRESHOLD) return;

        // Avoid duplicate callbacks in same block
        if (lastProtectionBlock[user] == log.block_number) return;
        lastProtectionBlock[user] = log.block_number;

        // Emit callback to trigger protection on destination chain
        bytes memory payload = abi.encodeWithSignature(
            "executeProtection(address)",
            user
        );

        emit Callback(
            DESTINATION_CHAIN_ID,
            executorContract,
            CALLBACK_GAS_LIMIT,
            payload
        );

        emit ProtectionCallbackEmitted(user, healthFactor);
    }

    /// @notice Update vault contract address
    function setVaultContract(address _vault) external {
        // In production, add access control
        vaultContract = _vault;
    }

    /// @notice Update executor contract address
    function setExecutorContract(address _executor) external {
        // In production, add access control
        executorContract = _executor;
    }

    // Allow receiving ETH for subscription fees
    receive() external payable override(AbstractPayer, IPayer) {}
}
