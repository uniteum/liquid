// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {User, TestToken, IERC20, console} from "./User.sol";
import {Liquid} from "../src/Liquid.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Strings} from "@openzeppelin/contracts/utils/Strings.sol";

contract LiquidUser is User {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    Liquid public immutable WATER;
    TestToken ignore;

    constructor(string memory name, Liquid water) User(name) {
        WATER = water;
    }

    modifier logging(string memory method, Liquid U, uint256 amount) {
        _logging(method, U, amount);
        _;
        logBalances();
    }

    function _logging(string memory method, Liquid U, uint256 amount) private view {
        console.log(string.concat(name, " ", method, " ", amount.toString(), " ", U.name()));
    }

    modifier waterlogging(string memory method, Liquid U, uint256 amount, uint256 water) {
        _waterlogging(method, U, amount, water);
        _;
        logBalances();
    }

    function _waterlogging(string memory method, Liquid U, uint256 amount, uint256 water) private view {
        console.log(string.concat(name, " ", method, " ", amount.toString(), " ", U.name(), " ", water.toString()));
    }

    function heat(Liquid U, uint256 cold) public logging("heat", U, cold) {
        U.solid().approve(address(U), cold);
        U.heat(cold);
    }

    function cool(Liquid U, uint256 hot) public logging("cool", U, hot) returns (uint256 cold) {
        cold = U.cool(hot);
        console.log("cold:", cold);
    }

    function liquidate(Liquid U) public returns (uint256 hot, uint256 cold) {
        hot = U.balanceOf(address(this));
        cold = cool(U, hot);
        assertHasNo(U);
    }

    function sell(Liquid U, uint256 hot) public logging("sell", U, hot) returns (uint256 water) {
        water = U.sell(hot);
        console.log("water:", water);
    }

    function rndUnits(Liquid U) public returns (int256 hot) {
        int256 min = -int256(U.balanceOf(address(this)));
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 max = int256(WATER.balanceOf(address(this)));
        hot = rnd(min, max);
    }

    function rndForge(Liquid U) public returns (int256 hot) {
        hot = rndUnits(U);
        if (hot < -int256(WATER.balanceOf(address(this)))) {
            console.log("forge not called because insufficient balance");
        } else if (hot < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            cool(U, uint256(-hot));
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            heat(U, uint256(hot));
        }
    }
}
