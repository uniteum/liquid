// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid, ILiquid} from "../src/Liquid.sol";
import {BaseTest, console} from "./Base.t.sol";
import {LiquidUser, IERC20Metadata} from "./LiquidUser.sol";

contract LiquidTest is BaseTest {
    uint256 constant SUPPLY = 1e9;
    uint256 constant GIFT = 1e4;
    uint256 constant DOLLIP = 100;
    uint256 constant U_WATER = 1e4;
    ILiquid public W;
    ILiquid public U;
    ILiquid public V;
    IERC20Metadata public S;
    LiquidUser public owen;
    LiquidUser public alex;
    LiquidUser public beck;

    function setUp() public virtual override {
        super.setUp();

        owen = newUser("owen");
        alex = newUser("alex");
        beck = newUser("beck");
        W = new Liquid(owen.newToken("W", SUPPLY));
        owen.heat(W, SUPPLY);
        U = W.make(owen.newToken("U", SUPPLY));
        V = W.make(owen.newToken("V", SUPPLY));
        S = U.solid();
        alex.addToken(U.solid());
        alex.addToken(U);
        // alex.addToken(V);
        // alex.addToken(W);
    }

    function newUser(string memory name) internal returns (LiquidUser user) {
        user = new LiquidUser(name, W);
    }

    function give(LiquidUser user, uint256 amount, IERC20Metadata token) internal {
        owen.give(address(user), amount, token);
    }

    function giveAlex() internal {
        give(alex, GIFT, W);
        give(alex, GIFT, U.solid());
        give(alex, GIFT, V.solid());
    }

    function giveBeck() internal {
        give(beck, GIFT, W);
        give(beck, GIFT, U.solid());
        give(beck, GIFT, V.solid());
    }

    function giveaway() internal {
        giveAlex();
        giveBeck();
    }

    function test_SetUp() public returns (uint256 s, uint256 u) {}

    function test_FixedHeatCool(uint256 s) public returns (uint256 u, uint256 p) {
        s = s % (GIFT - 1) + 1;
        giveAlex();
        owen.heat(U, GIFT, GIFT);
        (uint256 P, uint256 E) = U.pool();
        assertEq(P, 2 * GIFT, "Pool had unexpected U");
        assertEq(E, GIFT, "Pool had unexpected E");
        s = DOLLIP;
        (u, p) = alex.heat(U, s);
        assertEq(u, s, "1. alex liquid != solid");
        assertEq(p, s, "1. pool liquid != solid");
        (u, s) = alex.liquidate(U);
        assertEq(u, s, "2. alex liquid != solid");
        assertEq(p, s, "2. pool liquid != solid");
        (uint256 P2, uint256 E2) = U.pool();
        assertEq(P2, P, "Pool should have starting U");
        assertEq(E2, E, "Pool should have starting E");
    }

    function test_SimpleHeatCool(uint256 P, uint256 s, uint256 E) public returns (uint256 u, uint256 p) {
        giveAlex();
        uint256 owenSStart = owen.balance(S);
        uint256 owenWStart = owen.balance(W);
        P = P % (owenSStart - 1) + 1;
        E = E % (owenWStart - 1) + 1;
        s = s % alex.balance(S);
        (u, p) = U.heats(P, E);
        (u, p) = owen.heat(U, P, E);
        (uint256 P2, uint256 E2) = U.pool();
        assertEq(P2, 2 * P, "Pool had unexpected U");
        assertEq(E2, E, "Pool had unexpected E");
        console.log("2.test_SimpleHeatCool.alex.heat.s:", s);
        (u, p) = alex.heat(U, s);
        assertEq(u, s, "1. alex liquid != solid");
        assertEq(p, s, "1. pool liquid != solid");
        (u, s) = alex.liquidate(U);
        assertEq(u, s, "2. alex liquid != solid");
        assertEq(p, s, "2. pool liquid != solid");
        (P2, E2) = U.pool();
        assertEq(P2, 2 * P, "Pool should have starting U");
        assertEq(E2, E, "Pool should have starting E");
    }
}
