// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LiquidationShieldVault.sol";
import "../src/ProtectionExecutor.sol";

/// @title LiquidationShieldTest
/// @notice Unit tests for the Liquidation Shield contracts
contract LiquidationShieldTest is Test {
    LiquidationShieldVault public vault;
    ProtectionExecutor public executor;
    
    address public owner = address(this);
    address public user = address(0x1234);
    address public callbackProxy = address(0x5678);
    
    // Sepolia addresses (for fork testing)
    address constant WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address constant USDC = 0x94a9D9AC8a22534E3FaCa9F4e7F2E2cf85d5E4C8;
    
    function setUp() public {
        // Deploy contracts
        vault = new LiquidationShieldVault(callbackProxy);
        executor = new ProtectionExecutor(address(vault), callbackProxy);
        
        // Fund user
        vm.deal(user, 10 ether);
    }
    
    function test_VaultDeployment() public view {
        assertEq(vault.callbackProxy(), callbackProxy);
        assertEq(vault.owner(), owner);
    }
    
    function test_ExecutorDeployment() public view {
        assertEq(executor.vault(), address(vault));
        assertEq(executor.callbackSender(), callbackProxy);
    }
    
    function test_SetCallbackProxy() public {
        address newProxy = address(0x9999);
        vault.setCallbackProxy(newProxy);
        assertEq(vault.callbackProxy(), newProxy);
    }
    
    function test_SetVault() public {
        address newVault = address(0x8888);
        executor.setVault(newVault);
        assertEq(executor.vault(), newVault);
    }
    
    function test_CreatePositionMinimumDeposit() public {
        vm.prank(user);
        vm.expectRevert("Minimum 0.01 ETH");
        vault.createPosition{value: 0.001 ether}();
    }
    
    function test_OnlyCallbackProxyCanTriggerProtection() public {
        vm.prank(user);
        vm.expectRevert("Only callback proxy");
        vault.triggerProtection(user);
    }
    
    function test_OnlyCallbackSenderCanExecuteProtection() public {
        vm.prank(user);
        vm.expectRevert("Only callback sender");
        executor.executeProtection(user);
    }
    
    function test_PositionNotActive() public {
        vm.prank(callbackProxy);
        vm.expectRevert("No active position");
        vault.triggerProtection(user);
    }
    
    function test_GetPositionEmpty() public view {
        LiquidationShieldVault.Position memory pos = vault.getPosition(user);
        assertEq(pos.isActive, false);
        assertEq(pos.collateralAmount, 0);
    }

    // Fork tests (require Sepolia RPC)
    // Uncomment and run with: forge test --fork-url $SEPOLIA_RPC
    
    /*
    function test_CreatePositionFork() public {
        vm.prank(user);
        vault.createPosition{value: 0.1 ether}();
        
        LiquidationShieldVault.Position memory pos = vault.getPosition(user);
        assertTrue(pos.isActive);
        assertGt(pos.collateralAmount, 0);
    }
    */
}
