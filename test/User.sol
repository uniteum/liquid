// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Random} from "./Random.sol";
import {TestToken, IERC20, IERC20Metadata} from "./TestToken.sol";
import {Test, console} from "forge-std/Test.sol";
import {SafeERC20} from "erc20/SafeERC20.sol";
import {Namer} from "./Namer.sol";

contract User is Random, Test {
    using SafeERC20 for IERC20;

    string public name;
    IERC20Metadata[] public tokens;
    Namer namer = new Namer();

    constructor(string memory name_) {
        name = name_;
        console.log("%s born %s", name, address(this));
    }

    receive() external payable {
        console.log("%s receive %s", name, msg.value);
    }

    function addToken(IERC20Metadata token) public {
        tokens.push(token);
    }

    function logBalance(IERC20Metadata token) public view {
        uint256 bal = token.balanceOf(address(this));
        string memory symbol = token.symbol();
        console.log("%s has %s %s", name, bal, symbol);
    }

    function logBalances() public view {
        for (uint256 i = 0; i < tokens.length; i++) {
            IERC20Metadata token = tokens[i];
            uint256 bal = token.balanceOf(address(this));
            string memory symbol = token.symbol();
            console.log("%s has %s %s", name, bal, symbol);
        }
    }

    function balance(IERC20 token) public view returns (uint256 value) {
        value = token.balanceOf(address(this));
    }

    function give(address to, uint256 value, IERC20 token) public {
        console.log("%s give %s %s", namer.name(address(this)), namer.name(to), value);
        token.safeTransfer(to, value);
    }

    function approve(address recipient, uint256 value, IERC20 token) public {
        token.approve(recipient, value);
    }

    function newToken(string memory symbol, uint256 supply) public returns (TestToken token) {
        token = new TestToken(symbol, supply);
    }

    function assertHasNo(IERC20Metadata token) public view {
        assertEq(token.balanceOf(address(this)), 0, string.concat(name, " should have no ", token.symbol()));
    }
}
