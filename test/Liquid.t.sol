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
        U = W.liquify(owen.newToken("U", 1e9));
        V = W.liquify(owen.newToken("V", 1e9));
        giveaway();
    }

    function newUser(string memory name) internal returns (LiquidUser user) {
        user = new LiquidUser(name, W);
    }

    function give(LiquidUser user, uint256 amount, IERC20 token) internal {
        owen.give(address(user), amount, token);
    }

    function giveaway() internal {
        give(alex, 1e3, W);
        give(alex, 1e3, U.substance());
        give(alex, 1e3, V.substance());
        give(beck, 1e7, W);
        give(beck, 1e3, U.substance());
        give(beck, 1e3, V.substance());
    }

    function test_HeatCool() public returns (uint256 liquid, uint256 solid) {
        owen.heat(U, 500);
        alex.heat(U, 500);
        beck.heat(U, 500);
        liquid = 100;
        solid = alex.cool(U, liquid);
        assertEq(liquid, solid, "1. alex liquid != solid");
        (liquid, solid) = alex.liquidate(U);
        assertEq(liquid, solid, "2. alex liquid != solid");
        (liquid, solid) = beck.liquidate(U);
        assertEq(liquid, solid, "beck liquid != solid");
    }

    function test_HeatSellCoolBuy() public returns (uint256 water, uint256 solid) {
        // Setup: Give U pool some water for trading
        owen.give(address(U), 1000, W);

        // Owen heats to establish pool
        owen.heat(U, 1000);
        uint256 poolAfterOwenHeat = U.balanceOf(address(U));

        // Alex heats 100 solid into liquid
        uint256 alexInitialHot = 100;
        alex.heat(U, alexInitialHot);
        assertEq(U.balanceOf(address(alex)), alexInitialHot, "alex should have 100 liquid after heat");

        // Alex sells 50 liquid for water
        uint256 hotToSell = 50;
        uint256 alexHotBeforeSell = U.balanceOf(address(alex));
        water = alex.sell(U, hotToSell);
        assertGt(water, 0, "alex should receive water from sell");
        assertEq(U.balanceOf(address(alex)), alexHotBeforeSell - hotToSell, "alex liquid should decrease after sell");
        uint256 poolAfterSell = U.balanceOf(address(U));
        assertEq(poolAfterSell, poolAfterOwenHeat + alexInitialHot + hotToSell, "pool should grow from sell");

        // Alex cools some liquid back to solid
        uint256 alexHotBeforeCool = U.balanceOf(address(alex));
        uint256 hotToCool = 25;
        solid = alex.cool(U, hotToCool);
        assertGt(solid, 0, "alex should receive solid from cool");
        assertLt(U.balanceOf(address(alex)), alexHotBeforeCool, "alex liquid should decrease after cool");
    }

    /**
     * Parameterized test: Verify trader cannot profit from heat → sell → cool → buy cycle
     */
    function test_NoArbitrage() public {
        owen.give(address(U), 10000, W);
        owen.heat(U, 10000);

        _testNoArbitrage(100);
        _testNoArbitrage(500);
        _testNoArbitrage(1000);
    }

    function _testNoArbitrage(uint256 liquid) internal {
        // Record alex's initial balances
        uint256 alexInitialCold = alex.balance(U.substance());
        uint256 alexInitialWater = alex.balance(W);
        uint256 alexInitialHot = alex.balance(U);

        // Alex attempts arbitrage cycle: heat → sell → cool
        // Step 1: Heat solid → liquid
        alex.heat(U, liquid);

        // Step 2: Sell all liquid for water
        uint256 hotBalance = U.balanceOf(address(alex)) - alexInitialHot;
        alex.sell(U, hotBalance);

        // Step 3: Buy back liquid with the water gained (if any)
        uint256 waterGained = W.balanceOf(address(alex)) - alexInitialWater;
        if (waterGained > 0) {
            alex.buy(U, waterGained);
        }

        // Step 4: Cool all liquid back to solid
        uint256 finalHot = U.balanceOf(address(alex)) - alexInitialHot;
        if (finalHot > 0) {
            alex.cool(U, finalHot);
        }

        // Final balances
        uint256 alexFinalCold = U.substance().balanceOf(address(alex));
        uint256 alexFinalWater = W.balanceOf(address(alex));
        uint256 alexFinalHot = U.balanceOf(address(alex));

        // Verify no profit: final balances should be ≤ initial balances
        assertLe(alexFinalCold, alexInitialCold, "alex should not gain solid from arbitrage");
        assertEq(alexFinalWater, alexInitialWater, "alex water should return to initial");
        assertEq(alexFinalHot, alexInitialHot, "alex liquid should return to initial");

        // Total value should not increase
        uint256 initialValue = alexInitialCold + alexInitialWater + alexInitialHot;
        uint256 finalValue = alexFinalCold + alexFinalWater + alexFinalHot;
        assertLe(finalValue, initialValue, "alex total value should not increase from arbitrage");
    }
}
