// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Solid} from "../src/Solid.sol";
import {BaseTest} from "./Base.t.sol";
import {SolidUser} from "./SolidUser.sol";

contract SolidTest is BaseTest {
    uint256 public constant MOLE = 6.02214076e23;
    uint256 public constant SUPPLY = 1000 * MOLE;
    uint256 constant ETH = 1e9;
    Solid public N;
    SolidUser public owen;

    function setUp() public virtual override {
        super.setUp();
        owen = newUser("owen");
        N = new Solid();
    }

    function newUser(string memory name) internal returns (SolidUser user) {
        user = new SolidUser(name, N);
        vm.deal(address(user), ETH);
    }

    function test_Setup() public view {
        assertEq(N.totalSupply(), 0);
        assertEq(N.name(), "");
        assertEq(N.symbol(), "");
    }

    function test_MakeHydrogen() public returns (Solid H) {
        H = N.make("Hydrogen", "H");
        assertEq(H.totalSupply(), SUPPLY);
        assertEq(H.name(), "Hydrogen");
        assertEq(H.symbol(), "H");
    }
}
