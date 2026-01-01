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
    }

    /**
     * Parameterized test: Verify trader cannot profit from heat → sell → cool → buy cycle
     */
    function test_NoArbitrage() public {
        giveaway();
        owen.give(address(U), 10000, W);
        owen.heat(U, 10000);

        _testNoArbitrage(100);
        _testNoArbitrage(500);
        _testNoArbitrage(1000);
    }

    function _testNoArbitrage(uint256 heatAmount) internal {
        // Record alex's initial balances
        uint256 alexInitialCold = U.substance().balanceOf(address(alex));
        uint256 alexInitialWater = W.balanceOf(address(alex));
        uint256 alexInitialHot = U.balanceOf(address(alex));

        // Alex attempts arbitrage cycle: heat → sell → cool
        // Step 1: Heat cold → hot
        alex.heat(U, heatAmount);

        // Step 2: Sell all hot for water
        uint256 hotBalance = U.balanceOf(address(alex)) - alexInitialHot;
        alex.sell(U, hotBalance);

        // Step 3: Buy back hot with the water gained (if any)
        uint256 waterGained = W.balanceOf(address(alex)) - alexInitialWater;
        if (waterGained > 0) {
            alex.buy(U, waterGained);
        }

        // Step 4: Cool all hot back to cold
        uint256 finalHot = U.balanceOf(address(alex)) - alexInitialHot;
        if (finalHot > 0) {
            alex.cool(U, finalHot);
        }

        // Final balances
        uint256 alexFinalCold = U.substance().balanceOf(address(alex));
        uint256 alexFinalWater = W.balanceOf(address(alex));
        uint256 alexFinalHot = U.balanceOf(address(alex));

        // Verify no profit: final balances should be ≤ initial balances
        assertLe(alexFinalCold, alexInitialCold, "alex should not gain cold from arbitrage");
        assertEq(alexFinalWater, alexInitialWater, "alex water should return to initial");
        assertEq(alexFinalHot, alexInitialHot, "alex hot should return to initial");

        // Total value should not increase
        uint256 initialValue = alexInitialCold + alexInitialWater + alexInitialHot;
        uint256 finalValue = alexFinalCold + alexFinalWater + alexFinalHot;
        assertLe(finalValue, initialValue, "alex total value should not increase from arbitrage");
    }
}
