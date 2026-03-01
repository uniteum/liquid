// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {ERC20, IERC20, IERC20Metadata} from "erc20/ERC20.sol";
import {console} from "forge-std/Test.sol";
import {Namer} from "./Namer.sol";

/**
 * @title HookToken
 * @notice ERC20 that calls hooks during transfers.
 * @dev Designed for testing reentrancy vulnerabilities.
 */
contract TestToken is ERC20 {
    IERC20 unused;

    Namer namer = new Namer();

    function(IERC20Metadata, address, address, uint256) external afterUpdate;

    constructor(string memory name, uint256 value) ERC20(name, name) {
        console.log("%s created %s", name, address(this));
        _mint(msg.sender, value);
    }

    function clearAfterUpdate() public {
        delete afterUpdate;
    }

    function doAfterUpdate(function(IERC20Metadata, address, address, uint256) external hook) public {
        afterUpdate = hook;
    }

    bool private inHook;

    function _update(address from, address to, uint256 value) internal virtual override {
        super._update(from, to, value);

        console.log("%s update %s %s", symbol(), string.concat(namer.name(from), " ", namer.name(to)), value);

        if (!inHook && (afterUpdate.address != address(0))) {
            inHook = true;
            console.log("calling HookToken.afterUpdate(%s, %s, %s)", from, to, value);
            afterUpdate(this, from, to, value);
            inHook = false;
        }
    }
}
