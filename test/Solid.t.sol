// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Solid} from "../src/Solid.sol";
import {BaseTest, console} from "./Base.t.sol";
import {SolidUser} from "./SolidUser.sol";

contract SolidTest is BaseTest {
    uint256 constant MOLE = 6.02214076e23;
    uint256 constant SUPPLY = 1000 * MOLE;
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

    function makeHydrogen(uint256 seed) public returns (Solid H, uint256 h, uint256 e) {
        seed = seed % ETH;
        H = test_MakeHydrogen();
        vm.deal(address(H), seed);
        (h, e) = H.pool();
    }

    function test_StartingPrice(uint256 seed) public returns (Solid H, uint256 h, uint256 e) {
        (H, h, e) = makeHydrogen(seed);
        assertEq(h, SUPPLY, "h != SUPPLY");
        assertEq(e, seed % ETH, "e != seed");
    }

    function test_StartingDeposit(uint256 seed, uint256 deposit)
        public
        returns (Solid H, uint256 h, uint256 e, uint256 s)
    {
        (H, h, e) = makeHydrogen(seed);
        deposit = deposit % address(owen).balance;
        if (e != 0 || deposit != 0) {
            s = owen.deposit(H, deposit);
            emit log_named_uint("h", h);
            emit log_named_uint("e", e);
            emit log_named_uint("s", s);
        }
    }

    function test_StartingDepositDebug() public returns (Solid H, uint256 h, uint256 e, uint256 s) {
        (H, h, e, s) = test_StartingDeposit(1e6, 1e6);
        (H, h, e, s) = test_StartingDeposit(1e6, 2e6);
    }
}
