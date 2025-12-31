// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {User, TestToken, console} from "./User.sol";
import {Liquid, IERC20} from "../src/Liquid.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract LiquidUser is User {
    using SafeERC20 for IERC20;

    Liquid public immutable ONE;
    TestToken ignore;

    constructor(string memory name, Liquid one) User(name) {
        ONE = one;
    }

    function melt(Liquid U, uint256 solids) public {
        console.log("%s.melt", name, U.symbol());
        console.log("solids:", solids);
        U.solid().approve(address(U), solids);
        U.melt(solids);
        logBalances();
    }

    function freeze(Liquid U, uint256 liquids) public returns (uint256 solids) {
        console.log("%s.freeze", name, U.symbol());
        console.log("liquids:", liquids);
        solids = U.freeze(liquids);
        console.log("solids:", solids);
        logBalances();
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
