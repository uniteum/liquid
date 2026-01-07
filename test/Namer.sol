// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {INamed} from "./INamed.sol";
import {Strings} from "strings/Strings.sol";

contract Namer {
    using Strings for address;

    function rawName(address account) external view returns (string memory) {
        return INamed(account).name();
    }

    function name(address account) external view returns (string memory) {
        if (account == address(0)) {
            return "NULL";
        }
        try this.rawName(account) returns (string memory name) {
            return name;
        } catch {
            return account.toHexString();
        }
    }
}
