// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {SolidFactory} from "../src/SolidFactory.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 * @notice Invoke SolidFactory to create all elements from elements.json
 * @dev Usage: FACTORY_ADDRESS=0x... forge script script/MakeElements.s.sol -f $chain --private-key $tx_key --broadcast
 */
contract MakeElements is Script {
    function run() external {
        // Get SolidFactory address from environment
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        console2.log("Using SolidFactory at:", factoryAddress);

        // Read and parse elements directly into factory format
        string memory path = string.concat(vm.projectRoot(), "/script/elements.json");
        string memory json = vm.readFile(path);

        SolidFactory.Element[] memory elements =
            abi.decode(vm.parseJson(json, "$"), (SolidFactory.Element[]));

        console2.log("Found", elements.length, "elements");

        // Calculate exact ETH needed (0.001 ETH per element)
        uint256 totalEth = elements.length * 0.001 ether;
        console2.log("Creating all Solids with total ETH:", totalEth);

        vm.startBroadcast();

        // Create all elements in single transaction
        SolidFactory factory = SolidFactory(factoryAddress);
        (uint256 created, uint256 skipped) = factory.batchMake{value: totalEth}(elements);

        console2.log("\nSummary:");
        console2.log("  Created:", created);
        console2.log("  Skipped:", skipped);

        vm.stopBroadcast();
    }
}
