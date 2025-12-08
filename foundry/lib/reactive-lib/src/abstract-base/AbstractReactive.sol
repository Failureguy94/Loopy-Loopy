// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../interfaces/IReactive.sol";
import "../interfaces/ISubscriptionService.sol";

abstract contract AbstractReactive is IReactive {
    address public immutable service;

    constructor(address _service) {
        service = _service;
    }

    modifier onlyService() {
        require(msg.sender == service, "AbstractReactive: caller is not the service");
        _;
    }

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
    ) external virtual override onlyService {}
}
