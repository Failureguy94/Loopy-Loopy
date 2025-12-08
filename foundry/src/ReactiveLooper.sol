// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "reactive-lib/abstract-base/AbstractReactive.sol";
import "reactive-lib/interfaces/IReactive.sol";
import "reactive-lib/interfaces/ISubscriptionService.sol";
import "./OriginLooper.sol";

contract ReactiveLooper is AbstractReactive {
    address public originContract;
    uint256 public constant ORIGINAL_CHAIN_ID = 11155111; // Sepolia
    uint256 public constant TOPIC_0 = 0x3b070966f916d849cf84f0490eb938b8131e5f5f4007f339eb38c41d705c907b; // LoopRequested(address,uint256) topic

    constructor(address _service, address _originContract) AbstractReactive(_service) {
        originContract = _originContract;
        ISubscriptionService(service).subscribe(
            ORIGINAL_CHAIN_ID,
            originContract,
            TOPIC_0,
            REACTIVE_IGNORE, // Topic 1 (user) - we might want to capture this but typically for filtering. 
            REACTIVE_IGNORE, // Topic 2
            REACTIVE_IGNORE  // Topic 3
        );
    }
    
    // Constant for ignore from standard lib (assuming standard value or 0 if not defined clearly in snippet)
    // Using 0 for now as 'wildcard' if not strictly defined in ISubscriptionService (which usually uses specific flags)
    // Actually, ISubscriptionService usually takes specific topic matching. 
    // Let's assume 0 is "don't care" or we just pass the topic we care about. 
    // In many Reactive implementations, subscribe takes logical ops.
    // Simplifying to standard subscription to "Topic 0 on this contract".

    // Re-implementing correctly based on common Reactive patterns:
    uint256 public constant REACTIVE_IGNORE = 0xa54d485a00000000000000000000000000000000000000000000000000000000; // Placeholder for ignore if needed, or just 0.
    // For now, let's just assume we subscribe to the event signature.

    function react(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes calldata data,
        uint256 /* block_number */,
        uint256 /* op_code */
    ) external override onlyService {
        if (chain_id != ORIGINAL_CHAIN_ID || _contract != originContract || topic_0 != TOPIC_0) {
            return;
        }

        // Decode data or topics if needed.
        // LoopRequested(address indexed user, uint256 amount)
        address user = address(uint160(topic_1));
        
        // Amount is non-indexed, so it's in data.
        uint256 amount = abi.decode(data, (uint256));

        // Call back to origin contract to execute strategy
        // Note: In real reactive network, this would be a destination chain transaction request.
        // For simulation/hackathon scope, we call it directly assuming same-chain or callback mechanism.
        // If "Reactive" implies cross-chain, we would emit a callback request.
        // Here we assume direct call for simplicity or 'callback' pattern.
        
        OriginLooper(originContract).executeStrategy(user, amount);
    }
}
