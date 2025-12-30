// SPDX-License-Identifier: LicenseRef-Uniteum

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

    function melt(Liquid U, uint256 units) public {
        console.log("%s.melt", name, U.symbol());
        console.log("units:", units);
        U.solid().approve(address(U), units);
        U.melt(units);
        logBalances();
    }

    function freeze(Liquid U, uint256 units) public returns (uint256 solids) {
        console.log("%s.freeze", name, U.symbol());
        console.log("units:", units);
        solids = U.freeze(units);
        logBalances();
    }

    function liquidate(Liquid U) public returns (uint256 units, uint256 solids) {
        units = U.balanceOf(address(this));
        solids = freeze(U, units);
        assertHasNo(U);
    }

    function rndUnits(Liquid U) public returns (int256 units) {
        int256 min = -int256(U.balanceOf(address(this)));
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 max = int256(ONE.balanceOf(address(this)));
        units = rnd(min, max);
    }

    function rndForge(Liquid U) public returns (int256 units) {
        units = rndUnits(U);
        if (units < -int256(ONE.balanceOf(address(this)))) {
            console.log("forge not called because insufficient balance");
        } else if (units < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            freeze(U, uint256(-units));
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            melt(U, uint256(units));
        }
    }
}
