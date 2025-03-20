//SPDX-LICENSE-IDENTIFIER: MIT
pragma solidity ^0.8.20;

import {Script, console} from "forge-std/Script.sol";
import {Inheritance} from "../src/Inheritance.sol";

contract DeployInheritance is Script {
    function run() external returns (Inheritance inheritance) {
        // Start broadcasting transactions
        vm.startBroadcast();

        // Deploy the contract
        inheritance = new Inheritance();

        // Optional: Set initial heir if desired
        // address initialHeir = YOUR_HEIR_ADDRESS;
        // inheritance.setHeir(initialHeir);

        // Stop broadcasting
        vm.stopBroadcast();

        // Output the contract address
        console.log("Inheritance contract deployed at:", address(inheritance));
    }
} 