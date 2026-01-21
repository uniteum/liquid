// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {User, TestToken, IERC20, console} from "./User.sol";
import {ILiquid} from "iliquid/ILiquid.sol";
import {SafeERC20} from "erc20/SafeERC20.sol";
import {Strings} from "strings/Strings.sol";

contract LiquidUser is User {
    using SafeERC20 for IERC20;
    using Strings for uint256;

    ILiquid public immutable WATER;
    TestToken ignore;

    constructor(string memory name, ILiquid water) User(name) {
        WATER = water;
    }

    modifier logging(string memory method, ILiquid U, uint256 amount) {
        _logging(method, U, amount);
        _;
        logBalances();
    }

    function _logging(string memory method, ILiquid U, uint256 amount) private view {
        console.log(string.concat(name, " ", method, " ", amount.toString(), " ", U.name()));
    }

    modifier waterlog(string memory method, ILiquid U, uint256 amount, uint256 water) {
        _waterlog(method, U, amount, water);
        _;
        logBalances();
    }

    function _waterlog(string memory method, ILiquid U, uint256 amount, uint256 water) private view {
        console.log(string.concat(name, " ", method, " ", amount.toString(), " ", U.name(), " ", water.toString()));
    }

    function heat(ILiquid U, uint256 s) public logging("heat", U, s) returns (uint256 su, uint256 sp) {
        U.solid().approve(address(U), s);
        (su, sp) = U.heat(s);
    }

    function heat(ILiquid U, uint256 s, uint256 e) public logging("heat", U, s) returns (uint256 su, uint256 sp) {
        U.solid().approve(address(U), s);
        (su, sp) = U.heats(s, e);
        console.log("su:", su);
        console.log("sp:", sp);
        (su, sp) = U.heat(s, e);
    }

    function cool(ILiquid U, uint256 su) public logging("cool", U, su) returns (uint256 ss, uint256 sp) {
        (ss, sp) = U.cools(su);
        console.log("ss:", ss);
        console.log("sp:", sp);
        (ss, sp) = U.cool(su);
    }

    function liquidate(ILiquid U)
        public
        logging("liquidate", U, U.balanceOf(address(this)))
        returns (uint256 liquid, uint256 solid)
    {
        liquid = U.balanceOf(address(this));
        (solid,) = cool(U, liquid);
        assertHasNo(U);
    }

    function sell(ILiquid U, uint256 liquid) public logging("sell", U, liquid) returns (uint256 water) {
        water = U.sell(liquid);
        console.log("water:", water);
    }

    function sellFor(ILiquid U, ILiquid V, uint256 liquid)
        public
        waterlog("sell", U, liquid, 0)
        returns (uint256 water, uint256 fluid)
    {
        (water, fluid) = U.sellFor(V, liquid);
        console.log("water:", water);
        console.log("fluid:", fluid);
    }

    function buy(ILiquid U, uint256 water) public waterlog("buy", U, 0, water) returns (uint256 liquid) {
        liquid = U.buy(water);
        console.log("liquid:", liquid);
    }
}
