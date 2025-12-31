// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Water} from "../src/Water.sol";

/// @notice Deploy the Water contract.
/// @dev Usage: forge script script/Water.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract WaterCreate is Script {
    function run() external {
        vm.startBroadcast();
        Water actual = new Water{salt: 0x0}();
        vm.stopBroadcast();
        console2.log("actual   :", address(actual));
    }
}
