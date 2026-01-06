// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Solid} from "../src/Solid.sol";
import {BaseTest} from "./Base.t.sol";
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

    function test_StartingDeposit(uint256 seed, uint256 d) public returns (Solid H, uint256 h, uint256 e, uint256 s) {
        (H, h, e) = makeHydrogen(seed);
        d = d % address(owen).balance;
        if (e != 0 || d != 0) {
            uint256 balanceBefore = address(owen).balance;
            uint256 poolSolidsBefore = H.balanceOf(address(H));

            s = owen.deposit(H, d);

            uint256 balanceAfter = address(owen).balance;
            uint256 poolSolidsAfter = H.balanceOf(address(H));

            assertEq(balanceBefore - balanceAfter, d, "should have spent d ETH");
            assertEq(H.balanceOf(address(owen)), s, "should have received s solids");
            assertEq(poolSolidsBefore - poolSolidsAfter, s, "pool should have decreased by s solids");
            if (d > 0) {
                assertGt(s, 0, "should receive some solids");
            }

            emit log_named_uint("e", d);
            emit log_named_uint("E", e);
            emit log_named_uint("h", s);
            emit log_named_uint("H", h);
        }
    }

    function test_StartingDeposit11() public returns (Solid H, uint256 h, uint256 e, uint256 s) {
        (H, h, e, s) = test_StartingDeposit(1e6, 1e6);
    }

    function test_StartingDeposit12() public returns (Solid H, uint256 h, uint256 e, uint256 s) {
        (H, h, e, s) = test_StartingDeposit(1e6, 2e6);
    }

    function test_StartingDeposit21() public returns (Solid H, uint256 h, uint256 e, uint256 s) {
        (H, h, e, s) = test_StartingDeposit(2e6, 1e6);
    }

    function test_StartingDeposit22() public returns (Solid H, uint256 h, uint256 e, uint256 s) {
        (H, h, e, s) = test_StartingDeposit(2e6, 2e6);
    }

    function test_DepositWithdraw(uint256 seed, uint256 d) public returns (Solid H, uint256 deposited, uint256 withdrawn) {
        (H,,) = makeHydrogen(seed);
        d = d % address(owen).balance;
        if (d != 0) {
            deposited = owen.deposit(H, d);

            uint256 balanceBefore = address(owen).balance;
            uint256 poolSolidsBefore = H.balanceOf(address(H));
            uint256 poolEthBefore = address(H).balance;

            withdrawn = owen.withdraw(H, deposited);

            uint256 balanceAfter = address(owen).balance;
            uint256 poolSolidsAfter = H.balanceOf(address(H));
            uint256 poolEthAfter = address(H).balance;

            assertEq(balanceAfter - balanceBefore, withdrawn, "should have received withdrawn ETH");
            assertEq(H.balanceOf(address(owen)), 0, "should have no solids left");
            assertEq(poolSolidsAfter - poolSolidsBefore, deposited, "pool should have received deposited solids back");
            assertEq(poolEthBefore - poolEthAfter, withdrawn, "pool should have decreased by withdrawn ETH");
            assertGt(withdrawn, 0, "should receive some ETH");

            emit log_named_uint("deposited eth", d);
            emit log_named_uint("received solids", deposited);
            emit log_named_uint("withdrawn eth", withdrawn);
        }
    }
}
