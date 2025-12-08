// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface ISubscriptionService {
    enum SubscriptionMode {
        Unsubscribe,
        Topic0Only,
        Topic0AndTopic1,
        Topic0AndTopic2,
        Topic0AndTopic3,
        Topic0AndTopic1AndTopic2,
        Topic0AndTopic1AndTopic3,
        Topic0AndTopic2AndTopic3,
        Topic0AndTopic1AndTopic2AndTopic3
    }

    function subscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) external;

    function unsubscribe(
        uint256 chain_id,
        address _contract,
        uint256 topic_0,
        uint256 topic_1,
        uint256 topic_2,
        uint256 topic_3
    ) external;
}
