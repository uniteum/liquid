// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Solid} from "../src/Solid.sol";
import {BaseTest} from "./Base.t.sol";
import {SolidUser} from "./SolidUser.sol";

contract SolidTest is BaseTest {
    uint256 constant MOLE = 6.02214076e23;
    uint256 constant MOLES = 10000;
    uint256 constant SUPPLY = MOLES * MOLE;
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
        H = N.make{value: 0.001 ether}("Hydrogen", "H");
        assertEq(H.totalSupply(), SUPPLY);
        assertEq(H.name(), "Hydrogen");
        assertEq(H.symbol(), "H");
        assertEq(H.balanceOf(address(this)), SUPPLY / 100, "creator should have 1% of supply");
        assertEq(H.balanceOf(address(H)), SUPPLY - SUPPLY / 100, "pool should have 99% of supply");
        assertEq(address(H).balance, 0.001 ether, "pool should have 0.001 ETH");
    }

    function test_MakeWithExtraPayment() public {
        Solid H = N.make{value: 0.002 ether}("Helium", "He");
        assertEq(H.totalSupply(), SUPPLY);
        assertEq(H.balanceOf(address(this)), SUPPLY / 100, "creator should have 1% of supply");
        assertEq(H.balanceOf(address(H)), SUPPLY - SUPPLY / 100, "pool should have 99% of supply");
        assertEq(address(H).balance, 0.002 ether, "pool should have 0.002 ETH");
    }

    function test_MakeRevertsWithInsufficientPayment() public {
        vm.expectRevert(Solid.LowPayment.selector);
        N.make{value: 0.0001 ether}("Lithium", "Li");
    }

    function test_MakeRevertsWithNoPayment() public {
        vm.expectRevert(Solid.LowPayment.selector);
        N.make("Beryllium", "Be");
    }

    function test_MakeRevertsWhenAlreadyMade() public {
        N.make{value: 0.001 ether}("Carbon", "C");
        vm.expectRevert(Solid.AlreadyMade.selector);
        N.make{value: 0.001 ether}("Carbon", "C");
    }

    function test_DepositDoesNotCreateTokens() public {
        Solid H = N.make{value: 0.001 ether}("TestToken", "TT");

        uint256 supplyBefore = H.totalSupply();
        uint256 poolBefore = H.balanceOf(address(H));
        uint256 creatorBefore = H.balanceOf(address(this));

        // Deposit a large amount of ETH
        uint256 depositAmount = 78227239616666287245;
        H.deposit{value: depositAmount}();

        uint256 supplyAfter = H.totalSupply();
        uint256 poolAfter = H.balanceOf(address(H));
        uint256 creatorAfter = H.balanceOf(address(this));
        uint256 receivedSolids = creatorAfter - creatorBefore;

        // Total supply should not change
        assertEq(supplyAfter, supplyBefore, "Total supply changed!");

        // Sum of all balances should equal total supply
        uint256 sum = poolAfter + creatorAfter;
        assertEq(sum, SUPPLY, "Sum of balances != total supply");

        // Pool should have decreased by the amount user received
        assertEq(poolBefore - poolAfter, receivedSolids, "Pool decrease != user increase");
    }

    function test_DepositWithdrawBalanceIntegrity() public {
        Solid H = N.make{value: 0.001 ether}("Integrity", "INT");

        // Have owen deposit
        uint256 depositAmt = 78227239616666287245;
        vm.deal(address(owen), depositAmt);
        vm.prank(address(owen));
        H.deposit{value: depositAmt}();

        // Check total balances
        uint256 poolBal = H.balanceOf(address(H));
        uint256 creatorBal = H.balanceOf(address(this));
        uint256 owenBal = H.balanceOf(address(owen));
        uint256 sum = poolBal + creatorBal + owenBal;

        assertEq(sum, SUPPLY, "Sum != SUPPLY after owen deposit");
        assertEq(H.totalSupply(), SUPPLY, "Total supply changed!");
    }

    function makeHydrogen(uint256 seed) public returns (Solid H, uint256 h, uint256 e) {
        seed = seed % ETH;
        H = test_MakeHydrogen();
        // H already has 0.001 ether from make(), add seed on top
        vm.deal(address(H), 0.001 ether + seed);
        (h, e) = H.pool();
    }

    function test_StartingPrice(uint256 seed) public returns (Solid H, uint256 h, uint256 e) {
        (H, h, e) = makeHydrogen(seed);
        assertEq(h, SUPPLY - SUPPLY / 100, "h should be 99% of SUPPLY");
        assertEq(e, 0.001 ether + (seed % ETH), "e should be 0.001 ether + seed");
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

    function test_DepositWithdraw(uint256 seed, uint256 d)
        public
        returns (Solid H, uint256 deposited, uint256 withdrawn)
    {
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

    function test_MakeFromNonNothingSendsSharesToCaller() public {
        // Create a first Solid (Hydrogen) from NOTHING
        Solid H = N.make{value: 0.001 ether}("Hydrogen", "H");
        assertEq(H.balanceOf(address(this)), SUPPLY / 100, "creator should have 1% of H");

        // Now call make from H (non-NOTHING) to create Helium
        // The maker shares should still go to msg.sender (this), not to H
        Solid he = H.make{value: 0.001 ether}("Helium", "He");

        // Verify maker shares went to the actual caller (this), not to H
        assertEq(he.balanceOf(address(this)), SUPPLY / 100, "creator should have 1% of He");
        assertEq(he.balanceOf(address(H)), 0, "H should not have any He tokens");
        assertEq(he.balanceOf(address(he)), SUPPLY - SUPPLY / 100, "He pool should have 99% of supply");
    }
}
