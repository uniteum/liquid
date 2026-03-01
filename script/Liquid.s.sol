// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Liquid} from "../src/Liquid.sol";
import {IERC20Metadata} from "ierc20/IERC20Metadata.sol";

/**
 * @notice Deploy the Liquid protofactory
 * @dev Usage: forge script script/Liquid.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
 */
contract LiquidDeploy is Script {
    function run() external {
        address hub = vm.envAddress("HUB_SOLID");
        console2.log("HUB_SOLID at:", hub);

        vm.startBroadcast();

        // Deploy Liquid base contract using CREATE2 with salt 0x0
        Liquid liquid = new Liquid{salt: 0x0}(IERC20Metadata(hub));
        console2.log("Liquid protofactory deployed at:", address(liquid));

        vm.stopBroadcast();
    }
}
