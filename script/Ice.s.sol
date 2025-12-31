// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Script, console2} from "forge-std/Script.sol";
import {Ice} from "../src/Ice.sol";

/// @notice Deploy the Ice contract.
/// @dev Usage: forge script script/Ice.s.sol -f $chain --private-key $tx_key --broadcast --verify --delay 10 --retries 10
contract IceCreate is Script {
    function run() external {
        vm.startBroadcast();
        Ice actual = new Ice{salt: 0x0}();
        vm.stopBroadcast();
        console2.log("actual   :", address(actual));
    }
}
