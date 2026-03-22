// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Liquid} from "../src/Liquid.sol";
import {IERC20Metadata} from "ierc20/IERC20Metadata.sol";

/**
 * @notice Deploy the Liquid protofactory
 * @dev Reads:  io/HubSolid.json  (address of the hub solid token)
 *      Writes: io/$env/$chain/Liquid.json     (deployed Liquid address)
 *      Usage:  env=test chain=11155111 forge script script/Liquid.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
 */
contract LiquidDeploy is Script {
    function run() external {
        string memory dir = string.concat("io/", vm.envString("env"), "/", vm.envString("chain"));

        // forge-lint: disable-next-line(unsafe-cheatcode)
        address hub = vm.parseJsonAddress(vm.readFile("io/HubSolid.json"), "");
        console2.log("hub at:", hub);

        vm.startBroadcast();

        // Deploy Liquid base contract using CREATE2 with salt 0x0
        Liquid liquid = new Liquid{salt: 0x0}(IERC20Metadata(hub));
        console2.log("Liquid hub deployed at:", address(liquid));

        vm.stopBroadcast();

        vm.createDir(dir, true);
        vm.writeJson(vm.toString(address(liquid)), string.concat(dir, "/Liquid.json"));
    }
}
