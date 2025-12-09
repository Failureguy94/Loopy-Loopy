// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/LooperVault.sol";

/// @title LooperVaultTest
/// @notice Unit tests for the Leveraged Looping Strategy
contract LooperVaultTest is Test {
    LooperVault public vault;

    address public owner = address(this);
    address public user = address(0x1234);
    address public callbackProxy = address(0x5678);

    function setUp() public {
        vault = new LooperVault(callbackProxy);
        vm.deal(user, 10 ether);
    }

    // ============ Deployment Tests ============

    function test_Deployment() public view {
        assertEq(vault.callbackProxy(), callbackProxy);
        assertEq(vault.owner(), owner);
        assertEq(vault.targetLTV(), 7500);
        assertEq(vault.maxSlippage(), 100);
        assertEq(vault.absoluteMaxLoops(), 20);
    }

    // ============ Configuration Tests ============

    function test_SetTargetLTV() public {
        vault.setTargetLTV(8000);
        assertEq(vault.targetLTV(), 8000);
    }

    function test_SetTargetLTV_RevertTooHigh() public {
        vm.expectRevert("Max 85% LTV");
        vault.setTargetLTV(9000);
    }

    function test_SetMaxSlippage() public {
        vault.setMaxSlippage(200);
        assertEq(vault.maxSlippage(), 200);
    }

    function test_SetMaxSlippage_RevertTooHigh() public {
        vm.expectRevert("Max 5% slippage");
        vault.setMaxSlippage(600);
    }

    function test_SetMinLTVDelta() public {
        vault.setMinLTVDelta(100);
        assertEq(vault.minLTVDelta(), 100);
    }

    function test_SetCallbackProxy() public {
        address newProxy = address(0x9999);
        vault.setCallbackProxy(newProxy);
        assertEq(vault.callbackProxy(), newProxy);
    }

    // ============ Deposit Tests ============

    function test_Deposit_RevertInsufficientDeposit() public {
        vm.prank(user);
        vm.expectRevert(LooperVault.InsufficientDeposit.selector);
        vault.deposit{value: 0.001 ether}();
    }

    function test_OnlyCallbackProxy_Revert() public {
        vm.prank(user);
        vm.expectRevert(LooperVault.OnlyCallbackProxy.selector);
        vault.executeLoopStep(user);
    }

    function test_ExecuteLoopStep_NoActivePosition() public {
        vm.prank(callbackProxy);
        vm.expectRevert(LooperVault.NoActivePosition.selector);
        vault.executeLoopStep(user);
    }

    // ============ Position Tests ============

    function test_GetPosition_Empty() public view {
        LooperVault.Position memory pos = vault.getPosition(user);
        assertEq(pos.isActive, false);
        assertEq(pos.totalCollateral, 0);
    }

    // ============ View Function Tests ============

    function test_GetCurrentLTV() public view {
        uint256 ltv = vault.getCurrentLTV();
        assertEq(ltv, 0); // No position
    }

    function test_NeedsMoreLoops_NoPosition() public view {
        bool needs = vault.needsMoreLoops(user);
        assertEq(needs, false);
    }

    // ============ Fork Tests (require Sepolia RPC) ============
    // Run with: forge test --fork-url $SEPOLIA_RPC -vvv

    /*
    function test_Deposit_Fork() public {
        vm.prank(user);
        vault.deposit{value: 0.1 ether}();
        
        LooperVault.Position memory pos = vault.getPosition(user);
        assertTrue(pos.isActive);
        assertTrue(pos.isLooping);
        assertEq(pos.totalCollateral, 0.1 ether);
    }
    
    function test_ExecuteLoopStep_Fork() public {
        // Setup: deposit first
        vm.prank(user);
        vault.deposit{value: 0.1 ether}();
        
        // Execute loop as callback proxy
        vm.prank(callbackProxy);
        vault.executeLoopStep(user);
        
        LooperVault.Position memory pos = vault.getPosition(user);
        assertEq(pos.loopsCompleted, 1);
        assertGt(pos.totalDebt, 0);
    }
    */
}
