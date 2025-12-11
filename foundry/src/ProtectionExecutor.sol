// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/access/Ownable.sol";

interface ILiquidationShieldVault {
    function triggerProtection(address user) external;
    function needsProtection(address user) external view returns (bool);
}

contract ProtectionExecutor is Ownable {
    // Vault contract address
    address public vault;

    // Reactive Network callback sender address (from Reactive testnet)
    address public callbackSender;

    // Events
    event ProtectionExecuted(address indexed user, uint256 timestamp);
    event VaultUpdated(address indexed newVault);
    event CallbackSenderUpdated(address indexed newSender);

    constructor(address _vault, address _callbackSender) Ownable(msg.sender) {
        vault = _vault;
        callbackSender = _callbackSender;
    }

    /// @notice Modifier to restrict calls to Reactive callback sender
    modifier onlyCallbackSender() {
        require(msg.sender == callbackSender, "Only callback sender");
        _;
    }

    /// @notice Update vault address
    function setVault(address _vault) external onlyOwner {
        vault = _vault;
        emit VaultUpdated(_vault);
    }

    /// @notice Update callback sender address
    function setCallbackSender(address _callbackSender) external onlyOwner {
        callbackSender = _callbackSender;
        emit CallbackSenderUpdated(_callbackSender);
    }

    /// @notice Execute protection for a user - called by Reactive Network
    /// @param user The user whose position needs protection
    function executeProtection(address user) external onlyCallbackSender {
        require(vault != address(0), "Vault not set");

        // Call vault to trigger protection
        ILiquidationShieldVault(vault).triggerProtection(user);

        emit ProtectionExecuted(user, block.timestamp);
    }

    /// @notice Check if a user needs protection
    function checkNeedsProtection(address user) external view returns (bool) {
        if (vault == address(0)) return false;
        return ILiquidationShieldVault(vault).needsProtection(user);
    }
}
