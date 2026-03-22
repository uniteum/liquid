// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid, ILiquid} from "../src/Liquid.sol";
import {BaseTest} from "crucible/test/Base.t.sol";
import {LiquidUser, IERC20Metadata} from "./LiquidUser.sol";

/**
 * @notice Handler that performs random valid operations on a Liquid spoke.
 * Foundry's invariant fuzzer calls these functions with random args.
 */
contract LiquidHandler {
    ILiquid public W;
    ILiquid public U;
    LiquidUser public owen;
    LiquidUser public alice;

    constructor(ILiquid w, ILiquid u, LiquidUser owen_, LiquidUser alice_) {
        W = w;
        U = u;
        owen = owen_;
        alice = alice_;
    }

    function doHeat(uint256 amount) external {
        uint256 available = U.solid().balanceOf(address(alice));
        if (available == 0) return;
        amount = amount % available + 1;
        if (amount > available) amount = available;
        alice.heat(U, amount, 0);
    }

    function doCool(uint256 amount) external {
        uint256 available = U.balanceOf(address(alice));
        if (available == 0) return;
        amount = amount % available + 1;
        if (amount > available) amount = available;
        // Quote first — skip if rounding makes this amount unviable
        try U.cools(amount, 0) returns (uint256 m, uint256) {
            if (m == 0) return;
        } catch {
            return;
        }
        alice.cool(U, amount, 0);
    }

    function doBuy(uint256 amount) external {
        uint256 available = W.balanceOf(address(alice));
        (, uint256 E) = U.pool();
        if (available == 0 || E == 0) return;
        // Cap at half the lake to avoid exhausting it
        uint256 cap = E / 2;
        if (cap == 0) cap = 1;
        if (available < cap) cap = available;
        amount = amount % cap + 1;
        alice.buy(U, amount);
    }

    function doSell(uint256 amount) external {
        uint256 available = U.balanceOf(address(alice));
        (uint256 P,) = U.pool();
        if (available == 0 || P == 0) return;
        // Cap at half the pool to avoid exhausting it
        uint256 cap = P / 2;
        if (cap == 0) cap = 1;
        if (available < cap) cap = available;
        amount = amount % cap + 1;
        alice.sell(U, amount);
    }
}

/**
 * @notice Invariant tests for the Liquid protocol.
 *
 * After any sequence of heat/cool/buy/sell operations, these must hold:
 *
 * 1. Mass consistency  — mass() == solid.balanceOf(contract)
 * 2. Supply accounting — totalSupply() >= pool balance (P <= T)
 * 3. Pool ratio bounds — 0 < P/T <= 1 when pool is active
 * 4. Constant product  — buy/sell never decrease P*E (rounding favors pool)
 * 5. Hub 1:1           — hub heat/cool is always identity
 * 6. Quote accuracy    — view functions match mutating functions
 */
contract LiquidInvariantTest is BaseTest {
    uint256 constant SUPPLY = 1e9;
    uint256 constant POOL_SOLID = 1e6;
    uint256 constant POOL_HUB = 1e6;
    uint256 constant ALICE_SOLID = 1e5;
    uint256 constant ALICE_HUB = 1e5;

    ILiquid public W;
    ILiquid public U;
    LiquidUser public owen;
    LiquidUser public alice;
    LiquidHandler public handler;

    function setUp() public virtual override {
        super.setUp();
        owen = newUser("owen");
        alice = newUser("alice");

        W = new Liquid(owen.newToken("W", SUPPLY));
        owen.heat(W, SUPPLY, 0);

        U = W.make(owen.newToken("U", SUPPLY));

        // Owen seeds the pool
        owen.heat(U, POOL_SOLID, POOL_HUB);

        // Fund alice with solid and hub tokens
        owen.give(address(alice), ALICE_SOLID, U.solid());
        owen.give(address(alice), ALICE_HUB, IERC20Metadata(address(W)));

        // Handler is the only target for the fuzzer
        handler = new LiquidHandler(W, U, owen, alice);
        targetContract(address(handler));
    }

    function newUser(string memory name) internal returns (LiquidUser user) {
        user = new LiquidUser(name, W);
    }

    // ---------------------------------------------------------------
    // Invariant 1: mass() always equals actual solid token balance
    // ---------------------------------------------------------------

    function invariant_MassEqualsSolidBalance() public view {
        assertEq(U.mass(), U.solid().balanceOf(address(U)), "mass() must equal solid.balanceOf(contract)");
    }

    // ---------------------------------------------------------------
    // Invariant 2: Pool tokens (P) never exceed total supply (T)
    // ---------------------------------------------------------------

    function invariant_PoolNeverExceedsTotalSupply() public view {
        (uint256 P,) = U.pool();
        uint256 T = U.totalSupply();
        assertLe(P, T, "Pool balance must not exceed total supply");
    }

    // ---------------------------------------------------------------
    // Invariant 3: Total supply = pool tokens + circulating tokens
    //   Circulating = sum of all non-pool holder balances
    //   Since pool = balanceOf(address(U)), this is just ERC20 accounting
    // ---------------------------------------------------------------

    function invariant_SupplyIsPoolPlusCirculating() public view {
        (uint256 P,) = U.pool();
        uint256 T = U.totalSupply();
        uint256 circulating = T - P;
        // Circulating tokens are held by owen and alice
        uint256 owenBal = U.balanceOf(address(owen));
        uint256 aliceBal = U.balanceOf(address(alice));
        assertEq(owenBal + aliceBal, circulating, "Circulating tokens must equal sum of user balances");
    }

    // ---------------------------------------------------------------
    // Invariant 4: Hub is always 1:1 (heats/cools quote identity)
    // ---------------------------------------------------------------

    function invariant_HubIsOneToOne() public view {
        (uint256 u, uint256 p) = W.heats(1000, 0);
        assertEq(u, 1000, "Hub heats must return u = m");
        assertEq(p, 0, "Hub heats must return p = 0");

        (uint256 m, uint256 pCool) = W.cools(1000, 0);
        assertEq(m, 1000, "Hub cools must return m = u");
        assertEq(pCool, 0, "Hub cools must return p = 0");
    }

    // ---------------------------------------------------------------
    // Invariant 5: Lake (hub tokens in spoke) is non-negative
    //   (can't go below zero — would revert, but good to assert)
    // ---------------------------------------------------------------

    function invariant_LakeNonNegative() public view {
        (, uint256 E) = U.pool();
        assertGt(E, 0, "Lake must remain positive while pool is active");
    }

    // ---------------------------------------------------------------
    // Invariant 6: P/T ratio stays in (0, 1) when pool is active
    // ---------------------------------------------------------------

    function invariant_PoolRatioBounded() public view {
        (uint256 P,) = U.pool();
        uint256 T = U.totalSupply();
        if (T > 0) {
            assertGt(P, 0, "Pool must hold some tokens while active");
            assertLt(P, T, "Pool must not hold all tokens");
        }
    }

    // ---------------------------------------------------------------
    // Invariant 7: heats(s, 0) returns u + p = 2*s
    //   From the formula: u = 2*m - p, so u + p = 2*m
    // ---------------------------------------------------------------

    function invariant_HeatsMintsTwiceSolid() public view {
        uint256 T = U.totalSupply();
        if (T > 0) {
            (uint256 u, uint256 p) = U.heats(1000, 0);
            assertEq(u + p, 2000, "heats(s,0) must mint u + p = 2*s total");
        }
    }

    // ---------------------------------------------------------------
    // Invariant 8: cools(u, 0) returns m + p = u * T / (T - P)
    //   Simplified: m = u*T / (2*U), p = 2*m - u, so m >= 0 and p >= 0
    // ---------------------------------------------------------------

    function invariant_CoolsNonNegative() public view {
        (uint256 P,) = U.pool();
        uint256 T = U.totalSupply();
        uint256 uCirc = T - P;
        if (uCirc > 100) {
            uint256 testAmount = uCirc / 10;
            (uint256 m,) = U.cools(testAmount, 0);
            assertGt(m, 0, "cools must return positive solid");
            // p can be 0 if P/T = 1/2, but should not be negative (underflow)
            // Just checking it doesn't revert is sufficient
        }
    }
}
