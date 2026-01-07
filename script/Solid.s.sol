// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Solid} from "../src/Solid.sol";

/**
 * @notice Deploy the Solid protofactory
 * @dev Usage: forge script script/Solid.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
 */
contract SolidDeploy is Script {
    function run() external {
        vm.startBroadcast();

        // Deploy Solid base contract using CREATE2 with salt 0x0
        Solid solid = new Solid{salt: 0x0}();
        console2.log("Solid protofactory deployed at:", address(solid));

        vm.stopBroadcast();
    }
}
