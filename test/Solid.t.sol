// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ISolid} from "isolid/ISolid.sol";
import {Solid} from "../src/Solid.sol";
import {BaseTest} from "./Base.t.sol";
import {SolidUser} from "./SolidUser.sol";

contract SolidTest is BaseTest {
    uint256 constant ETH = 1e9;
    Solid public N;
    SolidUser public owen;

    function setUp() public virtual override {
        super.setUp();
        owen = newUser("owen");
        N = new Solid();
    }

    // Helper to get SUPPLY from a Solid instance
    function SUPPLY(ISolid solid) internal view returns (uint256) {
        return solid.totalSupply();
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

    function test_MakeHydrogen() public returns (ISolid H) {
        H = N.make{value: N.MAKER_FEE()}("Hydrogen", "H");
        uint256 supply = SUPPLY(H);
        assertEq(H.totalSupply(), supply);
        assertEq(H.name(), "Hydrogen");
        assertEq(H.symbol(), "H");
        assertEq(H.balanceOf(address(this)), supply / 2, "creator should have 50% of supply");
        assertEq(H.balanceOf(address(H)), supply / 2, "pool should have 50% of supply");
        assertEq(address(H).balance, N.MAKER_FEE(), "pool should have MAKER_FEE ETH");
    }

    function test_MakeWithExtraPayment() public {
        ISolid H = N.make{value: N.MAKER_FEE() * 2}("Helium", "He");
        uint256 supply = SUPPLY(H);
        assertEq(H.totalSupply(), supply);
        assertEq(H.balanceOf(address(this)), supply / 2, "creator should have 50% of supply");
        assertEq(H.balanceOf(address(H)), supply / 2, "pool should have 50% of supply");
        assertEq(address(H).balance, N.MAKER_FEE() * 2, "pool should have double MAKER_FEE ETH");
    }

    function test_MakeRevertsWithInsufficientPayment() public {
        uint256 insufficientPayment = N.MAKER_FEE() - 1;
        vm.expectRevert(abi.encodeWithSelector(ISolid.PaymentLow.selector, insufficientPayment, N.MAKER_FEE()));
        N.make{value: insufficientPayment}("Lithium", "Li");
    }

    function test_MakeRevertsWithNoPayment() public {
        vm.expectRevert(abi.encodeWithSelector(ISolid.PaymentLow.selector, 0, N.MAKER_FEE()));
        N.make("Beryllium", "Be");
    }

    function test_MakeRevertsWhenAlreadyMade() public {
        uint256 payment = N.MAKER_FEE();
        N.make{value: payment}("Carbon", "C");
        vm.expectRevert(abi.encodeWithSelector(ISolid.MadeAlready.selector, "Carbon", "C"));
        N.make{value: payment}("Carbon", "C");
    }

    function test_DepositDoesNotCreateTokens() public {
        ISolid H = N.make{value: N.MAKER_FEE()}("TestToken", "TT");
        uint256 supply = SUPPLY(H);

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
        assertEq(sum, supply, "Sum of balances != total supply");

        // Pool should have decreased by the amount user received
        assertEq(poolBefore - poolAfter, receivedSolids, "Pool decrease != user increase");
    }

    function test_DepositWithdrawBalanceIntegrity() public {
        ISolid H = N.make{value: N.MAKER_FEE()}("Integrity", "INT");
        uint256 supply = SUPPLY(H);

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

        assertEq(sum, supply, "Sum != SUPPLY after owen deposit");
        assertEq(H.totalSupply(), supply, "Total supply changed!");
    }

    function makeHydrogen(uint256 seed) public returns (ISolid H, uint256 h, uint256 e) {
        seed = seed % ETH;
        H = test_MakeHydrogen();
        // H already has MAKER_FEE from make(), add seed on top
        vm.deal(address(H), N.MAKER_FEE() + seed);
        (h, e) = H.pool();
    }

    function test_StartingPrice(uint256 seed) public returns (ISolid H, uint256 h, uint256 e) {
        (H, h, e) = makeHydrogen(seed);
        uint256 supply = SUPPLY(H);
        assertEq(h, supply / 2, "h should be 50% of SUPPLY");
        assertEq(e, N.MAKER_FEE() + (seed % ETH), "e should be MAKER_FEE + seed");
    }

    function test_StartingDeposit(uint256 seed, uint256 d)
        public
        returns (ISolid H, uint256 h, uint256 e, uint256 symbol)
    {
        (H, h, e) = makeHydrogen(seed);
        d = d % address(owen).balance;
        if (e != 0 || d != 0) {
            uint256 balanceBefore = address(owen).balance;
            uint256 poolSolidsBefore = H.balanceOf(address(H));

            symbol = owen.deposit(H, d);

            uint256 balanceAfter = address(owen).balance;
            uint256 poolSolidsAfter = H.balanceOf(address(H));

            assertEq(balanceBefore - balanceAfter, d, "should have spent d ETH");
            assertEq(H.balanceOf(address(owen)), symbol, "should have received symbol solids");
            assertEq(poolSolidsBefore - poolSolidsAfter, symbol, "pool should have decreased by symbol solids");
            if (d > 0) {
                assertGt(symbol, 0, "should receive some solids");
            }

            emit log_named_uint("e", d);
            emit log_named_uint("E", e);
            emit log_named_uint("h", symbol);
            emit log_named_uint("H", h);
        }
    }

    function test_StartingDeposit11() public returns (ISolid H, uint256 h, uint256 e, uint256 symbol) {
        (H, h, e, symbol) = test_StartingDeposit(1e6, 1e6);
    }

    function test_StartingDeposit12() public returns (ISolid H, uint256 h, uint256 e, uint256 symbol) {
        (H, h, e, symbol) = test_StartingDeposit(1e6, 2e6);
    }

    function test_StartingDeposit21() public returns (ISolid H, uint256 h, uint256 e, uint256 symbol) {
        (H, h, e, symbol) = test_StartingDeposit(2e6, 1e6);
    }

    function test_StartingDeposit22() public returns (ISolid H, uint256 h, uint256 e, uint256 symbol) {
        (H, h, e, symbol) = test_StartingDeposit(2e6, 2e6);
    }

    function test_DepositWithdraw(uint256 seed, uint256 d)
        public
        returns (ISolid H, uint256 deposited, uint256 withdrawn)
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

    function test_DepositWithdrawPoolReturnsToStartSpecific() public {
        test_DepositWithdrawPoolReturnsToStart(12345, 5 ether);
    }

    function test_DepositWithdrawPoolReturnsToStart(uint256 seed, uint256 d) public {
        // Create a Solid with random initial ETH
        (ISolid H,,) = makeHydrogen(seed);

        // Ensure owen has enough ETH and bound deposit amount
        uint256 owenBalance = address(owen).balance;
        if (owenBalance < 1e15) {
            return; // Skip test if owen doesn't have minimum
        }
        d = bound(d, 1e15, owenBalance);

        // Capture initial pool state BEFORE any deposit
        uint256 poolSolidsInitial = H.balanceOf(address(H));
        uint256 poolEthInitial = address(H).balance;

        // Do deposit
        uint256 solidsReceived = owen.deposit(H, d);

        // Verify pool state changed
        assertGt(H.balanceOf(address(H)), poolSolidsInitial, "pool solids should increase after deposit");
        assertGt(address(H).balance, poolEthInitial, "pool ETH should increase after deposit");

        // Do withdraw (all solids received)
        uint256 ethReceived = owen.withdraw(H, solidsReceived);

        // Verify pool returned to initial state
        uint256 poolSolidsFinal = H.balanceOf(address(H));
        uint256 poolEthFinal = address(H).balance;

        assertEq(poolSolidsFinal, poolSolidsInitial, "pool solids should return to initial state");
        assertEq(poolEthFinal, poolEthInitial, "pool ETH should return to initial state");

        // Verify user has no solids left
        assertEq(H.balanceOf(address(owen)), 0, "user should have no solids after full withdraw");

        emit log_named_uint("initial pool solids", poolSolidsInitial);
        emit log_named_uint("initial pool ETH", poolEthInitial);
        emit log_named_uint("deposit amount", d);
        emit log_named_uint("solids received", solidsReceived);
        emit log_named_uint("ETH received back", ethReceived);
        emit log_named_uint("final pool solids", poolSolidsFinal);
        emit log_named_uint("final pool ETH", poolEthFinal);
    }

    function test_MakeFromNonNothingSendsSharesToCaller() public {
        // Create a first Solid (Hydrogen) from NOTHING
        ISolid H = N.make{value: N.MAKER_FEE()}("Hydrogen", "H");
        uint256 supplyH = SUPPLY(H);
        assertEq(H.balanceOf(address(this)), supplyH / 2, "creator should have 50% of H");

        // Now call make from H (non-NOTHING) to create Helium
        // The maker shares should still go to msg.sender (this), not to H
        ISolid he = Solid(payable(address(H))).make{value: N.MAKER_FEE()}("Helium", "He");
        uint256 supplyHe = SUPPLY(he);

        // Verify maker shares went to the actual caller (this), not to H
        assertEq(he.balanceOf(address(this)), supplyHe / 2, "creator should have 50% of He");
        assertEq(he.balanceOf(address(H)), 0, "H should not have any He tokens");
        assertEq(he.balanceOf(address(he)), supplyHe / 2, "He pool should have 50% of supply");
    }
}
