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

    function heat(ILiquid U, uint256 solid) public logging("heat", U, solid) {
        U.solid().approve(address(U), solid);
        U.heat(solid);
    }

    function cool(ILiquid U, uint256 liquid) public logging("cool", U, liquid) {
        U.cool(liquid);
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

    function liquidate(ILiquid U) public returns (uint256 liquid) {
        liquid = U.balanceOf(address(this));
        cool(U, liquid);
        assertHasNo(U);
    }

    function rndUnits(ILiquid U) public returns (int256 liquid) {
        int256 min = -int256(U.balanceOf(address(this)));
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 max = int256(WATER.balanceOf(address(this)));
        liquid = rnd(min, max);
    }

    function rndForge(ILiquid U) public returns (int256 liquid) {
        liquid = rndUnits(U);
        if (liquid < -int256(WATER.balanceOf(address(this)))) {
            console.log("forge not called because insufficient balance");
        } else if (liquid < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            cool(U, uint256(-liquid));
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            heat(U, uint256(liquid));
        }
    }
}
