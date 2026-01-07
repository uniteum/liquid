// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Solid} from "../src/Solid.sol";
import {SolidFactory} from "../src/SolidFactory.sol";
import {stdJson} from "forge-std/StdJson.sol";

/**
 * @notice Deploy Solid and create all elements from elements.json in a single transaction
 * @dev Usage: forge script script/Solid.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
 */
contract SolidCreate is Script {
    using stdJson for string;

    struct Element {
        uint256 atomicNumber;
        string name;
        string symbol;
    }

    function run() external {
        // Read and parse elements from JSON
        string memory root = vm.projectRoot();
        string memory path = string.concat(root, "/script/elements.json");
        string memory json = vm.readFile(path);

        bytes memory parsed = json.parseRaw("$");
        Element[] memory elements = abi.decode(parsed, (Element[]));

        console2.log("Found", elements.length, "elements");

        // Convert to factory format (no atomicNumber needed)
        SolidFactory.Element[] memory factoryElements = new SolidFactory.Element[](elements.length);
        for (uint256 i = 0; i < elements.length; i++) {
            factoryElements[i] = SolidFactory.Element({name: elements[i].name, symbol: elements[i].symbol});
        }

        vm.startBroadcast();

        // Deploy Solid base contract using CREATE2 with salt 0x0
        Solid solid = new Solid{salt: 0x0}();
        console2.log("Solid deployed at:", address(solid));

        // Deploy factory
        SolidFactory factory = new SolidFactory();
        console2.log("Factory deployed at:", address(factory));

        // Calculate exact ETH needed (0.001 ETH per element)
        uint256 totalEth = elements.length * 0.001 ether;
        console2.log("Creating all Solids with total ETH:", totalEth);

        // Create all elements in single transaction
        (uint256 created, uint256 skipped) = factory.batchMake{value: totalEth}(solid, factoryElements);

        console2.log("\nSummary:");
        console2.log("  Created:", created);
        console2.log("  Skipped:", skipped);
        console2.log("  Total:  ", elements.length);

        vm.stopBroadcast();
    }
}
