// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {User, TestToken, console} from "./User.sol";
import {Pool, IERC20} from "../src/Pool.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

contract PoolUser is User {
    using SafeERC20 for IERC20;

    Pool public immutable ONE;
    TestToken ignore;

    constructor(string memory name_, Pool one) User(name_) {
        ONE = one;
    }

    function mint(Pool U, uint256 du) public {
        console.log("%s.mint", name, U.symbol());
        console.log("du:", du);
        U.underlying().approve(address(U), du);
        U.mint(du);
        logBalances();
    }

    function burn(Pool U, uint256 du) public returns (uint256 out) {
        console.log("%s.burn", name, U.symbol());
        console.log("du:", du);
        out = U.burn(du);
        logBalances();
    }

    function liquidate(Pool U) public returns (uint256 du, uint256 out) {
        du = U.balanceOf(address(this));
        out = burn(U, du);
        assertHasNo(U);
    }

    function rndUnits(Pool U) public returns (int256 x) {
        int256 xmin = -int256(U.balanceOf(address(this)));
        // forge-lint: disable-next-line(unsafe-typecast)
        int256 xmax = int256(ONE.balanceOf(address(this)));
        x = rnd(xmin, xmax);
    }

    function rndForge(Pool U) public returns (int256 du) {
        du = rndUnits(U);
        if (du < -int256(ONE.balanceOf(address(this)))) {
            console.log("forge not called because insufficient balance");
        } else if (du < 0) {
            // forge-lint: disable-next-line(unsafe-typecast)
            burn(U, uint256(-du));
        } else {
            // forge-lint: disable-next-line(unsafe-typecast)
            mint(U, uint256(du));
        }
    }
}
