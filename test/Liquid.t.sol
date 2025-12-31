// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid} from "../src/Liquid.sol";
import {BaseTest, console} from "./Base.t.sol";
import {TestToken} from "./TestToken.sol";
import {LiquidUser, IERC20} from "./LiquidUser.sol";

contract LiquidTest is BaseTest {
    Liquid public immutable WATER = new Liquid();
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
        U = WATER.make(owen.newToken("U", 1e9));
        V = WATER.make(owen.newToken("V", 1e9));

        address utility = WATER.WATER_UTILITY();
        console.log("utility:", utility);
        uint256 all = WATER.balanceOf(utility);

        vm.prank(utility);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        WATER.transfer(address(owen), all);
    }

    function newUser(string memory name) internal returns (LiquidUser user) {
        user = new LiquidUser(name, WATER);
    }

    function give(LiquidUser user, uint256 amount, IERC20 token) internal {
        owen.give(address(user), amount, token);
    }

    function giveaway() internal {
        give(alex, 1e3, WATER);
        give(alex, 1e3, U.solid());
        give(alex, 1e3, V.solid());
        give(beck, 1e7, WATER);
        give(beck, 1e3, U.solid());
        give(beck, 1e3, V.solid());
    }

    function test_MeltFreeze() public returns (uint256 liquids, uint256 solids) {
        giveaway();
        owen.melt(U, 500);
        alex.melt(U, 500);
        beck.melt(U, 500);
        liquids = 100;
        solids = alex.freeze(U, liquids);
        assertEq(liquids, solids, "1. alex liquids != solids");
        (liquids, solids) = alex.liquidate(U);
        assertEq(liquids, solids, "2. alex liquids != solids");
        (liquids, solids) = beck.liquidate(U);
        assertEq(liquids, solids, "beck liquids != solids");
    }

    function test_MeltSellFreezeBuy() public returns (uint256 water) {
        giveaway();
        owen.melt(U, 1000);
        alex.melt(U, 100);
        water = alex.sell(U, 100);
    }
}
