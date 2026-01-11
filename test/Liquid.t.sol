// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid} from "../src/Liquid.sol";
import {BaseTest} from "./Base.t.sol";
import {LiquidUser, IERC20} from "./LiquidUser.sol";

contract LiquidTest is BaseTest {
    uint256 constant INITIAL_BALANCE = 1e9;
    uint256 constant U_WATER = 1e6;
    Liquid public W;
    Liquid public U;
    Liquid public V;
    IERC20 public S;
    LiquidUser public owen;
    LiquidUser public alex;
    LiquidUser public beck;

    function setUp() public virtual override {
        super.setUp();

        owen = newUser("owen");
        alex = newUser("alex");
        beck = newUser("beck");
        W = new Liquid(owen.newToken("W", INITIAL_BALANCE));
        owen.heat(W, INITIAL_BALANCE);
        U = W.make(owen.newToken("U", INITIAL_BALANCE));
        owen.give(address(U), U_WATER, W);
        V = W.make(owen.newToken("V", INITIAL_BALANCE));
        S = U.solid();
        alex.addToken(U.solid());
        alex.addToken(U);
        alex.addToken(V);
        alex.addToken(W);
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

    function test_HeatCool() public returns (uint256 liquid, uint256 solid) {
        giveaway();
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
        giveaway();
        // Setup: Give U pool some water for trading
        owen.give(address(U), 1000, W);

        // Owen heats to establish pool
        owen.heat(U, 1000);
        uint256 poolAfterOwenHeat = U.balanceOf(address(U));

        // Alex heats 100 solid into liquid
        uint256 u0 = 100;
        alex.heat(U, u0);
        assertEq(U.balanceOf(address(alex)), u0, "alex should have 100 liquid after heat");

        // Alex sells 50 liquid for water
        uint256 hotToSell = 50;
        uint256 alexHotBeforeSell = U.balanceOf(address(alex));
        water = alex.sell(U, hotToSell);
        assertGt(water, 0, "alex should receive water from away");
        assertEq(U.balanceOf(address(alex)), alexHotBeforeSell - hotToSell, "alex liquid should decrease after away");
        uint256 poolAfterSell = U.balanceOf(address(U));
        assertEq(poolAfterSell, poolAfterOwenHeat + u0 + hotToSell, "pool should grow from away");

        // Alex cools some liquid back to solid
        uint256 alexHotBeforeCool = U.balanceOf(address(alex));
        uint256 hotToCool = 25;
        solid = alex.cool(U, hotToCool);
        assertGt(solid, 0, "alex should receive solid from cool");
        assertLt(U.balanceOf(address(alex)), alexHotBeforeCool, "alex liquid should decrease after cool");
    }

    /**
     * Parameterized test: Verify trader cannot profit from heat → away → cool → back cycle
     */
    function test_NoArbitrage() public {
        giveaway();
        owen.give(address(U), 10000, W);
        owen.heat(U, 10000);

        _testNoArbitrage(100);
        _testNoArbitrage(500);
        _testNoArbitrage(1000);
    }

    function _testNoArbitrage(uint256 liquid) internal {
        // Record alex's initial balances
        uint256 s0 = alex.balance(S);
        uint256 w0 = alex.balance(W);
        uint256 u0 = alex.balance(U);

        // Alex attempts arbitrage cycle: heat → away → cool
        // Step 1: Heat solid → liquid
        alex.heat(U, liquid);

        // Step 2: Sell all liquid for water
        uint256 du = alex.balance(U) - u0;
        alex.sell(U, du);

        // Step 3: Buy back liquid with the water gained (if any)
        uint256 waterGained = W.balanceOf(address(alex)) - w0;
        alex.buy(U, waterGained);

        // Step 4: Cool all liquid back to solid
        uint256 finalHot = alex.balance(U) - u0;
        alex.cool(U, finalHot);

        // Final balances
        uint256 s1 = alex.balance(S);
        uint256 w1 = alex.balance(W);
        uint256 u1 = alex.balance(U);

        // Verify no profit: final balances should be ≤ initial balances
        assertLe(s1, s0, "alex should not gain solid from arbitrage");
        assertEq(w1, w0, "alex water should return to initial");
        assertEq(u1, u0, "alex liquid should return to initial");

        // Total value should not increase
        uint256 initialValue = s0 + w0 + u0;
        uint256 finalValue = s1 + w1 + u1;
        assertLe(finalValue, initialValue, "alex total value should not increase from arbitrage");
    }
}
