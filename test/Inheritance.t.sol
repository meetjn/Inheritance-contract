//SPDX-LICENSE-IDENTIFIER: MIT
pragma solidity ^0.8.20;

import {Test} from "forge-std/Test.sol";
import {Inheritance} from "../src/Inheritance.sol";

contract InheritanceTest is Test {
    Inheritance public inheritance;
    address public owner;
    address public heir;
    address public newHeir;
    uint256 constant TIMEPERIOD = 30 days;

    event HeirSet(address indexed previousHeir, address indexed newHeir);
    event HeirtimeReset(uint96 newResetTime);
    event HeirtimeHeirChanged(address indexed oldHeir, address indexed newHeir);
    event OwnerWithdraw(uint256 amount);
    event HeirtimeActivated(address indexed heir);
    event NewHeirDesignated(address indexed newHeir);

    function setUp() public {
        owner = address(this);
        heir = makeAddr("heir");
        newHeir = makeAddr("newHeir");
        
        // Deploy contract with this contract as owner
        inheritance = new Inheritance();
        
        // Fund the contract
        vm.deal(address(inheritance), 10 ether);
    }
    
    function test_OwnerWithdraw() public {
        uint256 initialBalance = address(this).balance;
        uint256 contractBalance = address(inheritance).balance;
        
        vm.expectEmit(true, false, false, true);
        emit OwnerWithdraw(contractBalance);
        
        inheritance.withdrawByOwner();
        
        uint256 finalBalance = address(this).balance;
        assertEq(finalBalance, initialBalance + contractBalance);
        assertEq(address(inheritance).balance, 0);
    }
    
    function test_ResetTimePeriod() public {
        uint96 oldLastWithdrawTime = inheritance.lastWithdrawTime();
        
        // Fast forward 15 days
        skip(15 days);
        
        vm.expectEmit(true, false, false, true);
        emit HeirtimeReset(uint96(block.timestamp));
        
        inheritance.resetTimePeriod();
        
        uint96 newLastWithdrawTime = inheritance.lastWithdrawTime();
        assertGt(newLastWithdrawTime, oldLastWithdrawTime);
        assertEq(newLastWithdrawTime, uint96(block.timestamp));
    }
    
    function test_SetHeir() public {
        vm.expectEmit(true, true, false, false);
        emit HeirSet(address(0), heir);
        
        inheritance.setHeir(heir);
        
        assertEq(inheritance.heir(), heir);
    }
    
    function test_RevertSetHeirZeroAddress() public {
        vm.expectRevert(Inheritance.ZeroAddressNotAllowed.selector);
        inheritance.setHeir(address(0));
    }
    
    function test_DesignateNewHeir() public {
        // First set an heir
        inheritance.setHeir(heir);
        
        // Switch to heir
        vm.startPrank(heir);
        
        vm.expectEmit(true, false, false, false);
        emit NewHeirDesignated(newHeir);
        
        inheritance.designateNewHeir(newHeir);
        vm.stopPrank();
        
        assertEq(inheritance.newHeir(), newHeir);
    }
    
    function test_RevertDesignateNewHeirNotHeir() public {
        // First set an heir
        inheritance.setHeir(heir);
        
        // Try to designate new heir from non-heir account
        address nonHeir = makeAddr("nonHeir");
        vm.startPrank(nonHeir);
        
        vm.expectRevert(Inheritance.OnlyHeirCanWithdraw.selector);
        inheritance.designateNewHeir(newHeir);
        
        vm.stopPrank();
    }
    
    function test_RevertDesignateNewHeirZeroAddress() public {
        // First set an heir
        inheritance.setHeir(heir);
        
        // Switch to heir
        vm.startPrank(heir);
        
        vm.expectRevert(Inheritance.ZeroAddressNotAllowed.selector);
        inheritance.designateNewHeir(address(0));
        
        vm.stopPrank();
    }
    
    function test_ActivateHeirControl() public {
        // First set an heir
        inheritance.setHeir(heir);
        
        // Set a new heir from the heir account
        vm.prank(heir);
        inheritance.designateNewHeir(newHeir);
        
        // Skip past the time period
        skip(TIMEPERIOD + 1);
        
        // Activate heir control
        vm.startPrank(heir);
        
        // Store events we should see
        vm.expectEmit(true, true, false, false);
        emit HeirtimeHeirChanged(heir, newHeir);
        
        vm.expectEmit(true, false, false, false);
        emit HeirtimeActivated(heir);
        
        inheritance.activateHeirControl();
        
        vm.stopPrank();
        
        // Verify the heir is now the owner and new heir is cleared
        assertEq(inheritance.owner(), heir);
        assertEq(inheritance.heir(), newHeir);
        assertEq(inheritance.newHeir(), address(0));
        assertTrue(inheritance.heirActivated());
    }
    
    function test_RevertActivateHeirControlNotHeir() public {
        // First set an heir
        inheritance.setHeir(heir);
        
        // Skip past the time period
        skip(TIMEPERIOD + 1);
        
        // Try to activate from non-heir account
        address nonHeir = makeAddr("nonHeir");
        vm.startPrank(nonHeir);
        
        vm.expectRevert(Inheritance.OnlyHeirCanWithdraw.selector);
        inheritance.activateHeirControl();
        
        vm.stopPrank();
    }
    
    function test_RevertActivateHeirControlTooEarly() public {
        // First set an heir
        inheritance.setHeir(heir);
        
        // Skip only 15 days (less than required 30 days)
        skip(15 days);
        
        // Try to activate too early
        vm.startPrank(heir);
        
        vm.expectRevert(Inheritance.HeirNotActivated.selector);
        inheritance.activateHeirControl();
        
        vm.stopPrank();
    }
    
    function test_ActivateHeirControlNoNewHeir() public {
        // First set an heir
        inheritance.setHeir(heir);
        
        // Skip past the time period
        skip(TIMEPERIOD + 1);
        
        // Activate heir control
        vm.startPrank(heir);
        inheritance.activateHeirControl();
        vm.stopPrank();
        
        // Verify the heir is now the owner and no new heir was set
        assertEq(inheritance.owner(), heir);
        assertEq(inheritance.heir(), heir);
        assertEq(inheritance.newHeir(), address(0));
        assertTrue(inheritance.heirActivated());
    }
    
    function test_WithdrawResetsTimePeriod() public {
        uint96 oldLastWithdrawTime = inheritance.lastWithdrawTime();
        
        // Fast forward 15 days
        skip(15 days);
        
        inheritance.withdrawByOwner();
        
        uint96 newLastWithdrawTime = inheritance.lastWithdrawTime();
        assertGt(newLastWithdrawTime, oldLastWithdrawTime);
        assertEq(newLastWithdrawTime, uint96(block.timestamp));
    }
    
    function test_ReceiveEther() public {
        uint256 initialBalance = address(inheritance).balance;
        
        // Send ether to the contract
        (bool success, ) = address(inheritance).call{value: 5 ether}("");
        
        assertTrue(success);
        assertEq(address(inheritance).balance, initialBalance + 5 ether);
    }
    
    function test_E2EScenario() public {
        // Initial setup
        inheritance.setHeir(heir);
        
        // Owner resets time period
        inheritance.resetTimePeriod();
        
        // Heir designates a new heir
        vm.prank(heir);
        inheritance.designateNewHeir(newHeir);
        
        // Time passes but owner is active
        skip(15 days);
        inheritance.resetTimePeriod();
        
        // More time passes, owner is inactive
        skip(TIMEPERIOD + 1);
        
        // Heir takes control
        vm.prank(heir);
        inheritance.activateHeirControl();
        
        // Verify new ownership structure
        assertEq(inheritance.owner(), heir);
        assertEq(inheritance.heir(), newHeir);
    }
    
    // Receive function to allow contract to send ETH to the test contract
    receive() external payable {}
}   