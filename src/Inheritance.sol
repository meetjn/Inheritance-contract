//SPDX-LICENSE-IDENTIFIER: MIT
pragma solidity ^0.8.20;

/// @title Inheritance Smart Contract 
/// @author Meet Jain
/// @notice This contract allows owner to withdraw ETH if owner does not withdraw ETH within 1 month then an heir can take control of the contract and designate a new heir
/// @dev All function works as expected and all the edge cases have been handled

import {Ownable} from "lib/openzepplin-contracts/contracts/access/Ownable.sol";
import {ReentrancyGuard} from "lib/openzepplin-contracts/contracts/security/ReentrancyGuard.sol";

contract Inheritance is Ownable, ReentrancyGuard {
    // Constants
    uint256 private constant TIMEPERIOD = 30 days;
    
    // Storage variables - packed to save gas
    uint96 public lastWithdrawTime;
    bool public heirActivated;
    address public heir;
    address public newHeir;

    // errors
    error OnlyOwnerCanWithdraw();
    error HeirNotSet();
    error OnlyHeirCanWithdraw();
    error ZeroAddressNotAllowed();
    error HeirNotActivated();
    error TransferFailed();

    event HeirSet(address indexed previousHeir, address indexed newHeir);
    event HeirtimeReset(uint96 newResetTime);
    event HeirtimeHeirChanged(address indexed oldHeir, address indexed newHeir);
    event OwnerWithdraw(uint256 amount);
    event HeirtimeActivated(address indexed heir);
    event NewHeirDesignated(address indexed newHeir);

    constructor() {
        lastWithdrawTime = uint96(block.timestamp);
    }

    // Functions

    /// @notice Owner withdraws ETH and resets the time counter
    /// @dev Uses call instead of transfer for compatibility with all types of addresses
    function withdrawByOwner() external onlyOwner nonReentrant {
        lastWithdrawTime = uint96(block.timestamp);
        uint256 amount = address(this).balance;
        emit OwnerWithdraw(amount);
        
        (bool success, ) = payable(owner()).call{value: amount}("");
        if (!success) revert TransferFailed();
    }

    /// @notice Reset the time counter without withdrawing
    function resetTimePeriod() external onlyOwner {
        lastWithdrawTime = uint96(block.timestamp);
        emit HeirtimeReset(lastWithdrawTime);
    }

    /// @notice Set the heir who can take control if owner is inactive
    /// @param _heir Address of the heir
    function setHeir(address _heir) external onlyOwner {
        if (_heir == address(0)) revert ZeroAddressNotAllowed();
        emit HeirSet(heir, _heir);
        heir = _heir;
    }

    /// @notice The current heir can designate a new heir
    /// @param _newHeir Address of the new heir
    function designateNewHeir(address _newHeir) external {
        if (msg.sender != heir) revert OnlyHeirCanWithdraw();
        if (_newHeir == address(0)) revert ZeroAddressNotAllowed();
        
        newHeir = _newHeir;
        emit NewHeirDesignated(_newHeir);
    }

    /// @notice Heir takes control of the contract after owner inactivity period
    function activateHeirControl() external {
        // Cache the heir address to save gas on multiple reads
        address currentHeir = heir;
        
        if (msg.sender != currentHeir) revert OnlyHeirCanWithdraw();
        
        // Cast only once to uint256
        uint256 timeThreshold = uint256(lastWithdrawTime) + TIMEPERIOD;
        if (block.timestamp < timeThreshold) revert HeirNotActivated();
        
        // Transfer ownership to heir
        _transferOwnership(currentHeir);
        
        // If a new heir was designated, update heir
        address designatedNewHeir = newHeir;
        if (designatedNewHeir != address(0)) {
            // Update state
            heir = designatedNewHeir;
            newHeir = address(0);
            emit HeirtimeHeirChanged(currentHeir, designatedNewHeir);
        }
        
        heirActivated = true;
        emit HeirtimeActivated(currentHeir);
    }
    
    // Allow contract to receive ETH
    receive() external payable {}
}    