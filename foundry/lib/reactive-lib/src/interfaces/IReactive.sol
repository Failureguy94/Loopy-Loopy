// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IReactive {
    struct ReactiveRecord {
        address reactor;
        uint256 topic_0;
        uint256 topic_1;
        uint256 topic_2;
        uint256 topic_3;
    }

    event Callback(
        uint256 indexed chain_id,
        address indexed _contract,
        uint256 indexed topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3,
        bytes data,
        uint256 block_number,
        uint256 op_code
    );

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
    ) external;
}
