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

    function mint(Liquid U, uint256 units) public {
        console.log("%s.mint", name, U.symbol());
        console.log("units:", units);
        U.asset().approve(address(U), units);
        U.mint(units);
        logBalances();
    }

    function burn(Liquid U, uint256 units) public returns (uint256 ash) {
        console.log("%s.burn", name, U.symbol());
        console.log("units:", units);
        ash = U.burn(units);
        logBalances();
    }

    function liquidate(Liquid U) public returns (uint256 units, uint256 ash) {
        units = U.balanceOf(address(this));
        ash = burn(U, units);
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
            burn(U, uint256(-units));
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            mint(U, uint256(units));
        }
    }
}
