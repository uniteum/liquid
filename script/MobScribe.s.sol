// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {MobScribe} from "../src/MobScribe.sol";

/// @notice Deploy the MobScribe contract.
/// @dev Usage: forge script script/MobScribe.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract MobScribeCreate is Script {
    function run() external {
        vm.startBroadcast();
        MobScribe actual = new MobScribe{salt: 0x0}();
        vm.stopBroadcast();
        console2.log("actual   :", address(actual));
    }
}
