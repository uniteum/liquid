// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Mob} from "../src/Mob.sol";

/// @notice Deploy the Mob contract.
/// @dev Usage: forge script script/Mob.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract MobCreate is Script {
    function run() external {
        vm.startBroadcast();
        Mob actual = new Mob{salt: 0x0}();
        vm.stopBroadcast();
        console2.log("actual   :", address(actual));
    }
}
