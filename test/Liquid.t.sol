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

        // Setup: Give U pool some water for trading
        owen.give(address(U), 1000, W);

        // Owen heats to establish pool
        owen.heat(U, 1000);
        uint256 poolAfterOwenHeat = U.balanceOf(address(U));

        // Alex heats 100 cold into hot
        uint256 alexInitialHot = 100;
        alex.heat(U, alexInitialHot);
        assertEq(U.balanceOf(address(alex)), alexInitialHot, "alex should have 100 hot after heat");

        // Alex sells 50 hot for water
        uint256 hotToSell = 50;
        uint256 alexHotBeforeSell = U.balanceOf(address(alex));
        water = alex.sell(U, hotToSell);
        assertGt(water, 0, "alex should receive water from sell");
        assertEq(U.balanceOf(address(alex)), alexHotBeforeSell - hotToSell, "alex hot should decrease after sell");
        uint256 poolAfterSell = U.balanceOf(address(U));
        assertEq(poolAfterSell, poolAfterOwenHeat + alexInitialHot + hotToSell, "pool should grow from sell");

        // Alex cools some hot back to cold
        uint256 alexHotBeforeCool = U.balanceOf(address(alex));
        uint256 hotToCool = 25;
        cold = alex.cool(U, hotToCool);
        assertGt(cold, 0, "alex should receive cold from cool");
        assertLt(U.balanceOf(address(alex)), alexHotBeforeCool, "alex hot should decrease after cool");

        // Beck buys hot with water
        uint256 hotToBuy = 25;
        uint256 beckWaterBefore = W.balanceOf(address(beck));
        uint256 waterSpent = beck.buy(U, hotToBuy);
        assertGt(waterSpent, 0, "beck should spend water to buy");
        assertEq(U.balanceOf(address(beck)), hotToBuy, "beck should have bought hot");
        assertEq(W.balanceOf(address(beck)), beckWaterBefore - waterSpent, "beck water should decrease by amount spent");
    }
}
