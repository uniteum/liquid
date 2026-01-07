// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {SolidFactory} from "../src/SolidFactory.sol";

/**
 * @notice Invoke SolidFactory to create Solids from a JSON file
 * @dev Usage: FACTORY_ADDRESS=0x... SOLIDS_PATH=path/to/solids.json forge script script/MakeSolids.qqq.sol -f $chain --private-key $tx_key --broadcast
 * @dev The script automatically calculates required ETH based on MAKER_FEE from the Solid contract
 */
contract MakeSolids is Script {
    function run() external {
        // Get SolidFactory address from environment
        address factoryAddress = vm.envAddress("FACTORY_ADDRESS");
        console2.log("Using SolidFactory at:", factoryAddress);

        // Read and parse solids directly into factory format
        string memory path = vm.envString("SOLIDS_PATH");
        string memory fullPath = string.concat(vm.projectRoot(), "/", path);
        string memory json = vm.readFile(fullPath);

        SolidFactory.SolidSpec[] memory solids = abi.decode(vm.parseJson(json, "$"), (SolidFactory.SolidSpec[]));

        console2.log("Found", solids.length, "solids to create");

        // Create factory instance
        SolidFactory factory = SolidFactory(factoryAddress);

        // Calculate exact ETH needed based on MAKER_FEE
        uint256 makerPayment = factory.SOLID().MAKER_FEE();
        uint256 totalEth = solids.length * makerPayment;
        console2.log("MAKER_FEE:", makerPayment);
        console2.log("Creating all Solids with total ETH:", totalEth);

        vm.startBroadcast();
        (SolidFactory.SolidSpec[] memory existing, SolidFactory.SolidSpec[] memory created,,) =
            factory.make{value: totalEth}(solids);

        console2.log("\nSummary:");
        console2.log("  Created:", created.length);
        console2.log("  Skipped:", existing.length);

        vm.stopBroadcast();
    }
}
