// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {User, TestToken, console} from "./User.sol";
import {Liquid, IERC20} from "../src/Liquid.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract LiquidUser is User {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    Liquid public immutable ONE;
    TestToken ignore;

    constructor(string memory name, Liquid one) User(name) {
        ONE = one;
    }

    modifier logging(string memory method, Liquid U, uint256 amount) {
        _logging(method, U, amount);
        _;
        logBalances();
    }

    function _logging(string memory method, Liquid U, uint256 amount) private view {
        console.log(string.concat(name, " ", method, " ", amount.toString(), " ", U.name()));
    }

    function melt(Liquid U, uint256 solids) public logging("melt", U, solids) {
        U.solid().approve(address(U), solids);
        U.melt(solids);
    }

    function freeze(Liquid U, uint256 liquids) public logging("freeze", U, liquids) returns (uint256 solids) {
        solids = U.freeze(liquids);
        console.log("solids:", solids);
    }

    function sell(Liquid U, uint256 liquids) public logging("sell", U, liquids) returns (uint256 water) {
        water = U.sell(liquids);
        console.log("water:", water);
    }

    function liquidate(Liquid U) public returns (uint256 liquids, uint256 solids) {
        liquids = U.balanceOf(address(this));
        solids = freeze(U, liquids);
        assertHasNo(U);
    }

    function rndUnits(Liquid U) public returns (int256 liquids) {
        int256 min = -int256(U.balanceOf(address(this)));
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 max = int256(ONE.balanceOf(address(this)));
        liquids = rnd(min, max);
    }

    function rndForge(Liquid U) public returns (int256 liquids) {
        liquids = rndUnits(U);
        if (liquids < -int256(ONE.balanceOf(address(this)))) {
            console.log("forge not called because insufficient balance");
        } else if (liquids < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            freeze(U, uint256(-liquids));
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            melt(U, uint256(liquids));
        }
    }
}
