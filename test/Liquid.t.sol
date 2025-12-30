// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid} from "../src/Liquid.sol";
import {BaseTest, console} from "./Base.t.sol";
import {TestToken} from "./TestToken.sol";
import {LiquidUser} from "./LiquidUser.sol";

contract LiquidTest is BaseTest {
    Liquid one = new Liquid();
    Liquid public U;
    Liquid public V;
    TestToken public u_;
    TestToken public v_;
    LiquidUser public owen;
    LiquidUser public alex;
    LiquidUser public beck;

    function setUp() public virtual override {
        super.setUp();

        owen = newUser("owen");
        alex = newUser("alex");
        beck = newUser("beck");
        u_ = owen.newToken("U", 1e9);
        v_ = owen.newToken("V", 1e9);
        U = Liquid(one.clone(u_));
        V = Liquid(one.clone(v_));

        address issuer = one.ISSUER();
        console.log("issuer:", issuer);
        uint256 totalOne = one.balanceOf(issuer);

        vm.prank(issuer);
        // forge-lint: disable-next-line(erc20-unchecked-transfer)
        one.transfer(address(owen), totalOne);
    }

    function newUser(string memory name) internal returns (LiquidUser u) {
        u = new LiquidUser(name, one);
    }

    function test_Pool() public returns (uint256 du, uint256 out) {
        owen.give(address(alex), 1e3, one);
        owen.give(address(alex), 1e3, u_);
        owen.give(address(alex), 1e3, v_);
        owen.give(address(beck), 1e7, one);
        owen.give(address(beck), 1e3, u_);
        owen.give(address(beck), 1e3, v_);
        owen.mint(U, 500);
        alex.mint(U, 500);
        beck.mint(U, 500);
        du = 100;
        out = alex.burn(U, du);
        console.log("alex.burn:", U.symbol());
        console.log("alex.burn.du:", du);
        console.log("alex.burn.out:", out);
        (du, out) = alex.liquidate(U);
        console.log("alex.liquidate:", U.symbol());
        console.log("alex.liquidate.du:", du);
        console.log("alex.liquidate.out:", out);
        assertEq(1e3, alex.balance(one), "alex should have the same 1");
        (du, out) = beck.liquidate(U);
        console.log("beck.liquidate:", U.symbol());
        console.log("beck.liquidate.du:", du);
        console.log("beck.liquidate.out:", out);
        assertEq(beck.balance(one), 1e7, "beck should have the same 1");
    }
}
