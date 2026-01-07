// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {SolidFactory} from "../src/SolidFactory.sol";

/**
 * @notice Invoke SolidFactory to create Solids from a JSON file
 * @dev Usage: FACTORY_ADDRESS=0x... SOLIDS_PATH=path/to/solids.json forge script script/MakeSolids.sol -f $chain --private-key $tx_key --broadcast
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

        // Check which solids already exist and calculate exact fee BEFORE broadcast
        (
            SolidFactory.SolidSpec[] memory existing,
            SolidFactory.SolidSpec[] memory toCreate,
            uint256 feePer,
            uint256 fee
        ) = factory.made(solids);

        console2.log("\nPre-flight check:");
        console2.log("  MAKER_FEE per token:", feePer);
        console2.log("  Already exist:", existing.length);
        console2.log("  To create:", toCreate.length);
        console2.log("  Required ETH:", fee);

        // Show existing tokens
        if (existing.length > 0) {
            console2.log("\nAlready exist:");
            for (uint256 i = 0; i < existing.length; i++) {
                console2.log("  -", existing[i].symbol, existing[i].name);
            }
        }

        // Show tokens to be created
        if (toCreate.length > 0) {
            console2.log("\nWill create:");
            for (uint256 i = 0; i < toCreate.length; i++) {
                console2.log("  -", toCreate[i].symbol, toCreate[i].name);
            }
        }

        // Only broadcast if there are tokens to create
        if (toCreate.length == 0) {
            console2.log("\nNo tokens to create. Exiting.");
            return;
        }

        console2.log("\nStarting broadcast...");
        vm.startBroadcast();
        (SolidFactory.SolidSpec[] memory existingFinal, SolidFactory.SolidSpec[] memory created,,) =
            factory.make{value: fee}(solids);

        console2.log("\nSummary:");
        console2.log("  Created:", created.length);
        console2.log("  Skipped:", existingFinal.length);

        vm.stopBroadcast();
    }
}
