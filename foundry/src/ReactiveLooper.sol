// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "reactive-lib/abstract-base/AbstractReactive.sol";
import "reactive-lib/abstract-base/AbstractPayer.sol";
import "reactive-lib/interfaces/IReactive.sol";
import "reactive-lib/interfaces/IPayer.sol";

contract ReactiveLooper is AbstractReactive {
    // Sepolia chain ID
    uint256 public constant ORIGIN_CHAIN_ID = 11155111;
    uint256 public constant DESTINATION_CHAIN_ID = 11155111;

    // Event signatures (keccak256 of event signature)
    bytes32 public constant LOOP_REQUESTED_SIG =
        keccak256("LoopRequested(address,uint256,uint256,uint256)");
    bytes32 public constant LOOP_STEP_COMPLETED_SIG =
        keccak256("LoopStepCompleted(address,uint256,uint256,uint256,uint256,uint256)");
    bytes32 public constant UNWIND_REQUESTED_SIG =
        keccak256("UnwindRequested(address,uint256)");
    
    // LoopingCompleted event signature - indicates no more loops needed
    bytes32 public constant LOOPING_COMPLETED_SIG =
        keccak256("LoopingCompleted(address,uint256,uint256,uint256,uint256)");

    // Vault contract address on origin chain
    address public vaultContract;

    // Configuration - should match vault settings
    uint256 public targetLTV = 7500;    // 75% - matches vault default
    uint256 public maxLoops = 20;       // Safety limit - matches vault absoluteMaxLoops

    // Track active loops to prevent duplicates
    mapping(address => bool) public activeLoops;
    mapping(address => uint256) public lastLoopBlock;
    mapping(address => uint256) public userTargetLTV; // Store user's target LTV from LoopRequested

    // Gas limit for callbacks
    uint64 public constant CALLBACK_GAS_LIMIT = 1000000;

    event LoopCallbackEmitted(address indexed user, uint256 loopNumber);
    event UnwindCallbackEmitted(address indexed user);
    event SubscriptionCreated(address indexed vault, bytes32 eventSig);

    constructor(address _vaultContract) payable {
        vaultContract = _vaultContract;

        // Only subscribe when deployed on Reactive Network (not in ReactVM)
        if (!vm) {
            // Subscribe to LoopRequested events
            service.subscribe(
                ORIGIN_CHAIN_ID,
                _vaultContract,
                uint256(LOOP_REQUESTED_SIG),
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            emit SubscriptionCreated(_vaultContract, LOOP_REQUESTED_SIG);

            // Subscribe to LoopStepCompleted events (to trigger next step)
            service.subscribe(
                ORIGIN_CHAIN_ID,
                _vaultContract,
                uint256(LOOP_STEP_COMPLETED_SIG),
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            emit SubscriptionCreated(_vaultContract, LOOP_STEP_COMPLETED_SIG);

            // Subscribe to UnwindRequested events
            service.subscribe(
                ORIGIN_CHAIN_ID,
                _vaultContract,
                uint256(UNWIND_REQUESTED_SIG),
                REACTIVE_IGNORE,
                REACTIVE_IGNORE,
                REACTIVE_IGNORE
            );
            emit SubscriptionCreated(_vaultContract, UNWIND_REQUESTED_SIG);
        }
    }

    /// @notice React to vault events and orchestrate loop execution
    /// @param log The log record containing event data
    function react(LogRecord calldata log) external vmOnly {
        // Verify source
        if (log.chain_id != ORIGIN_CHAIN_ID) return;
        if (log._contract != vaultContract) return;

        bytes32 eventSig = bytes32(log.topic_0);
        address user = address(uint160(log.topic_1));

        // Handle LoopRequested - Start first loop step
        if (eventSig == LOOP_REQUESTED_SIG) {
            _handleLoopRequested(user, log.data, log.block_number);
            return;
        }

        // Handle LoopStepCompleted - Trigger next step if needed
        if (eventSig == LOOP_STEP_COMPLETED_SIG) {
            _handleLoopStepCompleted(user, log.data, log.block_number);
            return;
        }

        // Handle UnwindRequested - Start unwind
        if (eventSig == UNWIND_REQUESTED_SIG) {
            _handleUnwindRequested(user, log.block_number);
            return;
        }
    }

    /// @notice Handle LoopRequested - emit callback to start first loop
    function _handleLoopRequested(
        address user,
        bytes calldata data,
        uint256 block_number
    ) internal {
        // Prevent duplicate triggers in same block
        if (lastLoopBlock[user] == block_number) return;
        lastLoopBlock[user] = block_number;

        activeLoops[user] = true;
        
        // Decode event data to get targetLTV: (initialAmount, targetLTV, timestamp)
        if (data.length >= 96) {
            (, uint256 userTarget, ) = abi.decode(data, (uint256, uint256, uint256));
            userTargetLTV[user] = userTarget;
        }

        // Emit callback to execute first loop step
        bytes memory payload = abi.encodeWithSignature(
            "executeLoopStep(address)",
            user
        );

        emit Callback(
            DESTINATION_CHAIN_ID,
            vaultContract,
            CALLBACK_GAS_LIMIT,
            payload
        );

        emit LoopCallbackEmitted(user, 1);
    }

    /// @notice Handle LoopStepCompleted - check if more steps needed
    function _handleLoopStepCompleted(
        address user,
        bytes calldata data,
        uint256 block_number
    ) internal {
        // Only continue if we initiated this loop
        if (!activeLoops[user]) return;
        
        // Prevent duplicate triggers in same block
        if (lastLoopBlock[user] == block_number) return;
        lastLoopBlock[user] = block_number;

        // Decode event data: (loopNumber, collateral, debt, currentLTV, targetLTV)
        if (data.length >= 160) {
            (uint256 loopNumber, , , uint256 currentLTV, uint256 eventTargetLTV) = 
                abi.decode(data, (uint256, uint256, uint256, uint256, uint256));

            // Check if we've reached target LTV or max loops
            if (currentLTV >= eventTargetLTV || loopNumber >= maxLoops) {
                activeLoops[user] = false;
                return;
            }

            // Emit callback for next loop step
            bytes memory payload = abi.encodeWithSignature(
                "executeLoopStep(address)",
                user
            );

            emit Callback(
                DESTINATION_CHAIN_ID,
                vaultContract,
                CALLBACK_GAS_LIMIT,
                payload
            );

            emit LoopCallbackEmitted(user, loopNumber + 1);
        }
    }

    /// @notice Handle UnwindRequested - start unwind process
    function _handleUnwindRequested(
        address user,
        uint256 block_number
    ) internal {
        // Prevent duplicate triggers in same block
        if (lastLoopBlock[user] == block_number) return;
        lastLoopBlock[user] = block_number;

        activeLoops[user] = false;

        // Emit callback to execute unwind
        bytes memory payload = abi.encodeWithSignature(
            "executeUnwind(address)",
            user
        );

        emit Callback(
            DESTINATION_CHAIN_ID,
            vaultContract,
            CALLBACK_GAS_LIMIT,
            payload
        );

        emit UnwindCallbackEmitted(user);
    }

    // ========== Admin functions ==========

    function setTargetLTV(uint256 _targetLTV) external {
        require(_targetLTV <= 9000, "LTV too high");
        targetLTV = _targetLTV;
    }

    function setMaxLoops(uint256 _maxLoops) external {
        require(_maxLoops <= 50, "Too many loops");
        maxLoops = _maxLoops;
    }

    function resetUserLoop(address user) external {
        activeLoops[user] = false;
        lastLoopBlock[user] = 0;
    }

    // Allow receiving ETH for subscription fees
    receive() external payable override(AbstractPayer, IPayer) {}
}
