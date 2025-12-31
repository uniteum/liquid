// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid} from "../src/Liquid.sol";
import {BaseTest, console} from "./Base.t.sol";
import {TestToken} from "./TestToken.sol";
import {LiquidUser} from "./LiquidUser.sol";

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

    function test_Pool() public returns (uint256 liquids, uint256 solids) {
        owen.give(address(alex), 1e3, WATER);
        owen.give(address(alex), 1e3, U.solid());
        owen.give(address(alex), 1e3, V.solid());
        owen.give(address(beck), 1e7, WATER);
        owen.give(address(beck), 1e3, U.solid());
        owen.give(address(beck), 1e3, V.solid());
        owen.melt(U, 500);
        alex.melt(U, 500);
        beck.melt(U, 500);
        liquids = 100;
        solids = alex.freeze(U, liquids);
        assertEq(liquids, solids, "liquids != solids");
        (liquids, solids) = alex.liquidate(U);
        assertEq(1e3, alex.balance(WATER), "alex should have the same 1");
        (liquids, solids) = beck.liquidate(U);
        assertEq(beck.balance(WATER), 1e7, "beck should have the same 1");
    }
}
