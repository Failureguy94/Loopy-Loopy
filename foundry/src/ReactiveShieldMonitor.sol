// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "reactive-lib/abstract-base/AbstractReactive.sol";
import "reactive-lib/interfaces/IReactive.sol";
import "reactive-lib/interfaces/ISubscriptionService.sol";

/// @title ReactiveShieldMonitor
/// @notice Monitors health factors and triggers protection via callbacks
/// @dev Reactive contract deployed on Reactive testnet - subscribes to vault events
contract ReactiveShieldMonitor is AbstractReactive {
    
    // Origin chain ID (Sepolia)
    uint256 public constant ORIGIN_CHAIN_ID = 11155111;
    
    // Destination chain ID (Sepolia - same for this demo)
    uint256 public constant DESTINATION_CHAIN_ID = 11155111;
    
    // Event signature: HealthFactorUpdated(address indexed user, uint256 healthFactor, uint256 timestamp)
    uint256 public constant HEALTH_FACTOR_UPDATED_TOPIC = 0x8f1f0f0e0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f0f;
    
    // Protection threshold (1.2 * 1e18)
    uint256 public constant PROTECTION_THRESHOLD = 12e17;
    
    // Reactive ignore constant for wildcard subscription
    uint256 public constant REACTIVE_IGNORE = 0xa54d485a00000000000000000000000000000000000000000000000000000000;
    
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
        address _service,
        address _vaultContract,
        address _executorContract
    ) AbstractReactive(_service) {
        vaultContract = _vaultContract;
        executorContract = _executorContract;
        
        // Subscribe to HealthFactorUpdated events from the vault
        // Using keccak256("HealthFactorUpdated(address,uint256,uint256)") for topic0
        bytes32 eventSig = keccak256("HealthFactorUpdated(address,uint256,uint256)");
        
        ISubscriptionService(service).subscribe(
            ORIGIN_CHAIN_ID,
            _vaultContract,
            uint256(eventSig),
            REACTIVE_IGNORE, // topic1 (user) - wildcard
            REACTIVE_IGNORE, // topic2
            REACTIVE_IGNORE  // topic3
        );
        
        emit SubscriptionCreated(_vaultContract);
    }

    /// @notice React to HealthFactorUpdated events
    /// @dev Called by Reactive Network when subscribed events occur
    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata data,
        uint256 block_number,
        uint256 op_code
    ) external override onlyService {
        // Verify event source
        if (chain_id != ORIGIN_CHAIN_ID) return;
        if (_contract != vaultContract) return;
        
        // Verify event signature (HealthFactorUpdated)
        bytes32 expectedSig = keccak256("HealthFactorUpdated(address,uint256,uint256)");
        if (topic_0 != uint256(expectedSig)) return;
        
        // Decode user from indexed topic1
        address user = address(uint160(topic_1));
        
        // Decode health factor from data (first 32 bytes)
        uint256 healthFactor = abi.decode(data, (uint256));
        
        // Check if protection is needed
        if (healthFactor >= PROTECTION_THRESHOLD) return;
        
        // Avoid duplicate callbacks in same block
        if (lastProtectionBlock[user] == block_number) return;
        lastProtectionBlock[user] = block_number;
        
        // Emit callback to trigger protection on destination chain
        // Encode the function call: executeProtection(address user)
        bytes memory payload = abi.encodeWithSignature("executeProtection(address)", user);
        
        emit Callback(
            DESTINATION_CHAIN_ID,
            executorContract,
            0, // gas limit (0 for default)
            0, // topic1
            0, // topic2
            0, // topic3
            payload,
            block_number,
            op_code
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
}
