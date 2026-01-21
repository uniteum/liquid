// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid, ILiquid} from "../src/Liquid.sol";
import {BaseTest, console} from "./Base.t.sol";
import {LiquidUser, IERC20} from "./LiquidUser.sol";

contract LiquidTest is BaseTest {
    uint256 constant SUPPLY = 1e9;
    uint256 constant GIFT = 1e4;
    uint256 constant DOLLIP = 100;
    uint256 constant U_WATER = 1e4;
    ILiquid public W;
    ILiquid public U;
    ILiquid public V;
    IERC20 public S;
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

    function give(LiquidUser user, uint256 amount, IERC20 token) internal {
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

    function test_HeatCool() public returns (uint256 s, uint256 u, uint256 p) {
        giveAlex();
        owen.heat(U, GIFT, GIFT);
        (uint256 P, uint256 E) = U.pool();
        assertEq(P, GIFT, "Pool had unexpected U");
        assertEq(E, GIFT, "Pool had unexpected E");
        s = DOLLIP;
        (u, p) = alex.heat(U, s);
        assertEq(u, s, "1. alex liquid != solid");
        (u, s) = alex.liquidate(U);
        assertEq(u, s, "2. alex liquid != solid");
    }
}
