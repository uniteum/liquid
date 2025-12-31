// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid} from "../src/Liquid.sol";
import {BaseTest} from "./Base.t.sol";
import {LiquidUser, IERC20} from "./LiquidUser.sol";

contract LiquidTest is BaseTest {
    Liquid public W;
    Liquid public U;
    Liquid public V;
    LiquidUser public owen;
    LiquidUser public alex;
    LiquidUser public beck;

    function setUp() public virtual override {
        super.setUp();

        owen = newUser("owen");
        alex = newUser("alex");
        beck = newUser("beck");
        W = new Liquid(owen.newToken("W", 1e9));
        owen.liquify(W, 1e9);
        U = W.make(owen.newToken("U", 1e9));
        V = W.make(owen.newToken("V", 1e9));
    }

    function newUser(string memory name) internal returns (LiquidUser user) {
        user = new LiquidUser(name, W);
    }

    function give(LiquidUser user, uint256 amount, IERC20 token) internal {
        owen.give(address(user), amount, token);
    }

    function giveaway() internal {
        give(alex, 1e3, W);
        give(alex, 1e3, U.solid());
        give(alex, 1e3, V.solid());
        give(beck, 1e7, W);
        give(beck, 1e3, U.solid());
        give(beck, 1e3, V.solid());
    }

    function test_MeltFreeze() public returns (uint256 liquids, uint256 solids) {
        giveaway();
        owen.liquify(U, 500);
        alex.liquify(U, 500);
        beck.liquify(U, 500);
        liquids = 100;
        solids = alex.solidify(U, liquids);
        assertEq(liquids, solids, "1. alex liquids != solids");
        (liquids, solids) = alex.liquidate(U);
        assertEq(liquids, solids, "2. alex liquids != solids");
        (liquids, solids) = beck.liquidate(U);
        assertEq(liquids, solids, "beck liquids != solids");
    }

    function test_MeltSellFreezeBuy() public returns (uint256 water, uint256 solids) {
        giveaway();
        owen.give(address(U), 1000, W);
        owen.liquify(U, 1000);
        alex.liquify(U, 100);
        water = alex.sell(U, 50);
        solids = alex.solidify(U, U.balanceOf(address(alex)));
    }
}
