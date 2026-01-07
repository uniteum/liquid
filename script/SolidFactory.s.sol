// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Solid} from "../src/Solid.sol";
import {SolidFactory} from "../src/SolidFactory.sol";

/**
 * @notice Deploy the SolidFactory with reference to Solid protofactory
 * @dev Usage: SOLID_ADDRESS=0x... forge script script/SolidFactory.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
 */
contract SolidFactoryDeploy is Script {
    function run() external {
        // Get Solid protofactory address from environment
        address solidAddress = vm.envAddress("SOLID_ADDRESS");
        console2.log("Using Solid protofactory at:", solidAddress);

        vm.startBroadcast();

        // Deploy SolidFactory with Solid reference
        SolidFactory factory = new SolidFactory(Solid(payable(solidAddress)));
        console2.log("SolidFactory deployed at:", address(factory));

        vm.stopBroadcast();
    }
}
