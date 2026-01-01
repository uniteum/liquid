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
        owen.heat(W, 1e9);
        U = W.heat(owen.newToken("U", 1e9));
        V = W.heat(owen.newToken("V", 1e9));
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

    function test_HeatCool() public returns (uint256 hot, uint256 cold) {
        giveaway();
        owen.heat(U, 500);
        alex.heat(U, 500);
        beck.heat(U, 500);
        hot = 100;
        cold = alex.cool(U, hot);
        assertEq(hot, cold, "1. alex hot != cold");
        (hot, cold) = alex.liquidate(U);
        assertEq(hot, cold, "2. alex hot != cold");
        (hot, cold) = beck.liquidate(U);
        assertEq(hot, cold, "beck hot != cold");
    }

    function test_HeatSellCoolBuy() public returns (uint256 water, uint256 cold) {
        giveaway();
        owen.give(address(U), 1000, W);
        owen.heat(U, 1000);
        alex.heat(U, 100);
        water = alex.sell(U, 50);
        cold = alex.cool(U, U.balanceOf(address(alex)));
    }
}
