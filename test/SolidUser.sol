// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {User, TestToken, IERC20, console} from "./User.sol";
import {Solid} from "../src/Solid.sol";
import {SafeERC20} from "erc20/SafeERC20.sol";
import {Strings} from "strings/Strings.sol";

contract SolidUser is User {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    Solid public immutable NOTHING;
    TestToken ignore;
    IERC20 ignore2;

    constructor(string memory name, Solid nothing) User(name) {
        NOTHING = nothing;
    }

    modifier logging(string memory method, Solid U, uint256 amount) {
        _logging(method, U, amount);
        _;
        logBalances();
    }

    function _logging(string memory method, Solid U, uint256 amount) private view {
        console.log(string.concat(name, " ", method, " ", amount.toString(), " ", U.name()));
    }

    function deposit(Solid U, uint256 eth) public logging("deposit", U, eth) returns (uint256 solid) {
        solid = U.deposit{value: eth}();
        console.log("solid:", solid);
    }

    function withdraw(Solid U, uint256 solid) public logging("back", U, solid) returns (uint256 eth) {
        eth = U.withdraw(solid);
        console.log("eth:", eth);
    }

    function liquidate(Solid U) public returns (uint256 eth, uint256 solid) {
        solid = U.balanceOf(address(this));
        eth = withdraw(U, solid);
        assertHasNo(U);
    }
}
