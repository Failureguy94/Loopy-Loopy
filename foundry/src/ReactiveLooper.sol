// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "reactive-lib/abstract-base/AbstractReactive.sol";
import "reactive-lib/interfaces/IReactive.sol";
import "reactive-lib/interfaces/ISubscriptionService.sol";

/// @title ReactiveLooper
/// @notice Orchestrates multi-step leveraged looping via Reactive Network
/// @dev Subscribes to LoopRequested events and triggers loop execution steps
contract ReactiveLooper is AbstractReactive {
    
    // ============ Constants ============
    
    // Sepolia chain ID
    uint256 public constant ORIGIN_CHAIN_ID = 11155111;
    uint256 public constant DESTINATION_CHAIN_ID = 11155111;
    
    // Reactive wildcard for subscription
    uint256 public constant REACTIVE_IGNORE =0xa54d485a00000000000000000000000000000000000000000000000000000000;
    
    // Event signatures (keccak256 of event signature)
    bytes32 public constant LOOP_REQUESTED_SIG = keccak256("LoopRequested(address,uint256,uint256,uint256)");
    bytes32 public constant LOOP_STEP_COMPLETED_SIG = keccak256("LoopStepCompleted(address,uint256,uint256,uint256,uint256,uint256)");
    bytes32 public constant UNWIND_REQUESTED_SIG = keccak256("UnwindRequested(address,uint256)");
    
    // ============ State ============
    
    // Vault contract address on origin chain
    address public vaultContract;
    
    // Track active loops to prevent duplicates
    mapping(address => bool) public activeLoops;
    mapping(address => uint256) public lastLoopBlock;
    
    // ============ Events ============
    
    event LoopCallbackEmitted(address indexed user, uint256 loopNumber);
    event UnwindCallbackEmitted(address indexed user);
    event SubscriptionCreated(address indexed vault, bytes32 eventSig);

    // ============ Constructor ============
    
    constructor(
        address _service,
        address _vaultContract
    ) AbstractReactive(_service) {
        vaultContract = _vaultContract;
        
        // Subscribe to LoopRequested events
        ISubscriptionService(service).subscribe(
            ORIGIN_CHAIN_ID,
            _vaultContract,
            uint256(LOOP_REQUESTED_SIG),
            REACTIVE_IGNORE, // topic1 (user)
            REACTIVE_IGNORE, // topic2
            REACTIVE_IGNORE  // topic3
        );
        emit SubscriptionCreated(_vaultContract, LOOP_REQUESTED_SIG);
        
        // Subscribe to LoopStepCompleted events (to trigger next step)
        ISubscriptionService(service).subscribe(
            ORIGIN_CHAIN_ID,
            _vaultContract,
            uint256(LOOP_STEP_COMPLETED_SIG),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        emit SubscriptionCreated(_vaultContract, LOOP_STEP_COMPLETED_SIG);
        
        // Subscribe to UnwindRequested events
        ISubscriptionService(service).subscribe(
            ORIGIN_CHAIN_ID,
            _vaultContract,
            uint256(UNWIND_REQUESTED_SIG),
            REACTIVE_IGNORE,
            REACTIVE_IGNORE,
            REACTIVE_IGNORE
        );
        emit SubscriptionCreated(_vaultContract, UNWIND_REQUESTED_SIG);
    }

    // ============ Reactive Callback ============
    
    /// @notice React to vault events and orchestrate loop execution
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
        // Verify source
        if (chain_id != ORIGIN_CHAIN_ID) return;
        if (_contract != vaultContract) return;
        
        bytes32 eventSig = bytes32(topic_0);
        address user = address(uint160(topic_1));
        
        // Handle LoopRequested - Start first loop step
        if (eventSig == LOOP_REQUESTED_SIG) {
            _handleLoopRequested(user, data, block_number, op_code);
            return;
        }
        
        // Handle LoopStepCompleted - Trigger next step if needed
        if (eventSig == LOOP_STEP_COMPLETED_SIG) {
            _handleLoopStepCompleted(user, data, block_number, op_code);
            return;
        }
        
        // Handle UnwindRequested - Start unwind
        if (eventSig == UNWIND_REQUESTED_SIG) {
            _handleUnwindRequested(user, block_number, op_code);
            return;
        }
    }

    // ============ Internal Handlers ============
    
    /// @notice Handle LoopRequested - emit callback to start first loop
    function _handleLoopRequested(
        address user,
        bytes calldata, // data not needed for initial trigger
        uint256 block_number,
        uint256 op_code
    ) internal {
        // Prevent duplicate triggers in same block
        if (lastLoopBlock[user] == block_number) return;
        lastLoopBlock[user] = block_number;
        
        activeLoops[user] = true;
        
        // Emit callback to execute first loop step
        bytes memory payload = abi.encodeWithSignature("executeLoopStep(address)", user);
        
        emit Callback(
            DESTINATION_CHAIN_ID,
            vaultContract,
            0, // gas limit (0 for default)
            0,
            0,
            0,
            payload,
            block_number,
            op_code
        );
        
        emit LoopCallbackEmitted(user, 1);
    }
    
    /// @notice Handle LoopStepCompleted - check if more loops needed
    function _handleLoopStepCompleted(
        address user,
        bytes calldata data,
        uint256 block_number,
        uint256 op_code
    ) internal {
        if (!activeLoops[user]) return;
        
        // Decode loop data: (loopNumber, borrowed, swapped, supplied, currentLTV)
        (uint256 loopNumber, , , , uint256 currentLTV) = abi.decode(data, (uint256, uint256, uint256, uint256, uint256));
        
        // Check if target LTV reached (7500 = 75%)
        // Or if max loops reached (assume 5)
        if (currentLTV >= 7500 || loopNumber >= 5) {
            activeLoops[user] = false;
            return;
        }
        
        // Prevent rapid-fire callbacks
        if (lastLoopBlock[user] == block_number) return;
        lastLoopBlock[user] = block_number;
        
        // Emit callback for next loop step
        bytes memory payload = abi.encodeWithSignature("executeLoopStep(address)", user);
        
        emit Callback(
            DESTINATION_CHAIN_ID,
            vaultContract,
            0,
            0,
            0,
            0,
            payload,
            block_number,
            op_code
        );
        
        emit LoopCallbackEmitted(user, loopNumber + 1);
    }
    
    /// @notice Handle UnwindRequested - emit callback to unwind position
    function _handleUnwindRequested(
        address user,
        uint256 block_number,
        uint256 op_code
    ) internal {
        activeLoops[user] = false;
        
        // Emit callback to execute unwind
        bytes memory payload = abi.encodeWithSignature("executeUnwind(address)", user);
        
        emit Callback(
            DESTINATION_CHAIN_ID,
            vaultContract,
            0,
            0,
            0,
            0,
            payload,
            block_number,
            op_code
        );
        
        emit UnwindCallbackEmitted(user);
    }

    // ============ Admin Functions ============
    
    function setVaultContract(address _vault) external {
        // In production, add access control
        vaultContract = _vault;
    }
}
