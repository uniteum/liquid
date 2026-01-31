// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid, ILiquid} from "../src/Liquid.sol";
import {BaseTest, console} from "./Base.t.sol";
import {LiquidUser, IERC20Metadata} from "./LiquidUser.sol";

contract LiquidTest is BaseTest {
    uint256 constant SUPPLY = 1e9;
    uint256 constant GIFT = 1e4;
    uint256 constant DOLLIP = 100;
    uint256 constant U_WATER = 1e4;
    ILiquid public W;
    ILiquid public U;
    ILiquid public V;
    IERC20Metadata public S;
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

    function give(LiquidUser user, uint256 amount, IERC20Metadata token) internal {
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

    function test_FixedHeatCool(uint256 s) public returns (uint256 u, uint256 p) {
        s = s % (GIFT - 1) + 1;
        giveAlex();
        owen.heat(U, GIFT, GIFT);
        (uint256 P, uint256 E) = U.pool();
        assertEq(P, 2 * GIFT, "Pool had unexpected U");
        assertEq(E, GIFT, "Pool had unexpected E");
        s = DOLLIP;
        (u, p) = alex.heat(U, s);
        assertEq(u, s, "1. alex liquid != solid");
        assertEq(p, s, "1. pool liquid != solid");
        (u, s) = alex.liquidate(U);
        assertEq(u, s, "2. alex liquid != solid");
        assertEq(p, s, "2. pool liquid != solid");
        (uint256 P2, uint256 E2) = U.pool();
        assertEq(P2, P, "Pool should have starting U");
        assertEq(E2, E, "Pool should have starting E");
    }

    function test_SimpleHeatCool(uint256 P, uint256 s, uint256 E) public returns (uint256 u, uint256 p) {
        giveAlex();
        uint256 owenSStart = owen.balance(S);
        uint256 owenWStart = owen.balance(W);
        P = P % (owenSStart - 1) + 1;
        E = E % (owenWStart - 1) + 1;
        s = s % alex.balance(S);
        (u, p) = U.heats(P, E);
        (u, p) = owen.heat(U, P, E);
        (uint256 P2, uint256 E2) = U.pool();
        assertEq(P2, 2 * P, "Pool had unexpected U");
        assertEq(E2, E, "Pool had unexpected E");
        console.log("2.test_SimpleHeatCool.alex.heat.s:", s);
        (u, p) = alex.heat(U, s);
        assertEq(u, s, "1. alex liquid != solid");
        assertEq(p, s, "1. pool liquid != solid");
        (u, s) = alex.liquidate(U);
        assertEq(u, s, "2. alex liquid != solid");
        assertEq(p, s, "2. pool liquid != solid");
        (P2, E2) = U.pool();
        assertEq(P2, 2 * P, "Pool should have starting U");
        assertEq(E2, E, "Pool should have starting E");
    }

    /**
     * @notice Test that arbitrage is profitable when trading against a noise trader.
     *
     * Scenario:
     * 1. Owen creates a balanced pool and seeds alex/beck with equal funds
     * 2. Alex heats solid to acquire U tokens for arbitrage
     * 3. Beck (trader) buys U with W, moving the price unfavorably
     * 4. Alex (arbitrager) sells U for W, restoring the pool to balance
     * 5. Result: Pool returns to original state, alex profits, beck loses
     */
    function test_ArbitrageProfit(uint256 poolSolid, uint256 poolHub, uint256 tradeSize) public {
        // Constrain pool sizes to valid ranges (reserve funds for alex and beck)
        // Minimum of 1000 to ensure meaningful trades where slippage is observable
        uint256 minSize = 1000;
        uint256 maxPoolSolid = owen.balance(S) / 3;
        uint256 maxPoolHub = owen.balance(W) / 2;
        poolSolid = poolSolid % (maxPoolSolid - minSize) + minSize;
        poolHub = poolHub % (maxPoolHub - minSize) + minSize;

        // Owen creates pool
        owen.heat(U, poolSolid, poolHub);

        // Alex heats same solid as pool to ensure enough U for arbitrage
        give(alex, poolSolid, U.solid());
        alex.heat(U, poolSolid);

        // Record pool state after setup (this is the "balanced" state)
        (uint256 P0, uint256 E0) = U.pool();

        // Limit trade size: beck buying with tradeSize gets at most 3*poolSolid*tradeSize/(poolHub+tradeSize)
        // For beckU <= alexU (poolSolid), need tradeSize <= poolHub/2
        // Minimum trade of poolHub/10 to ensure observable slippage (at least ~10% price impact)
        uint256 maxTrade = poolHub / 2;
        uint256 minTrade = poolHub / 10;
        tradeSize = tradeSize % (maxTrade - minTrade) + minTrade;

        // Seed beck with W to trade
        give(beck, tradeSize, W);

        // Beck buys U with W (noise trade that moves the price)
        uint256 beckU = beck.buy(U, tradeSize);

        // Pool is now unbalanced
        (uint256 Pmid, uint256 Emid) = U.pool();
        assertLt(Pmid, P0, "Beck's buy should decrease pool U");
        assertGt(Emid, E0, "Beck's buy should increase pool W");

        // Alex sells exactly what beck bought to restore pool balance
        uint256 alexW = alex.sell(U, beckU);

        // Pool should be restored to original state (within 1% rounding tolerance)
        (uint256 P1, uint256 E1) = U.pool();
        assertEq(P1, P0, "Pool U should be restored");
        assertApproxEqRel(E1, E0, 0.01e18, "Pool W should be approximately restored");

        // Calculate fair value of beckU at the balanced pool price (E0/P0)
        uint256 fairValue = beckU * E0 / P0;

        // Beck lost money: paid tradeSize W for beckU U worth only fairValue W
        assertLt(fairValue, tradeSize, "Beck overpaid due to slippage");

        // Alex made money: sold beckU U (worth fairValue) but received alexW W
        assertGt(alexW, fairValue, "Alex received more than fair value");
        assertApproxEqRel(alexW, tradeSize, 0.05e18, "Alex captured beck's trade amount");

        // Verify the profit approximately equals the slippage loss
        // Note: fairValue computation has rounding, so use 5% tolerance
        uint256 slippage = tradeSize - fairValue;
        uint256 profit = alexW - fairValue;
        assertApproxEqRel(profit, slippage, 0.05e18, "Alex's profit approximates beck's slippage loss");
    }

    /**
     * @notice Test arbitrage with round-trip trades - no FMV computation needed.
     *
     * Scenario:
     * 1. Owen creates pool and seeds alex/beck with equal W
     * 2. Beck buys U with W, then sells U back (round trip)
     * 3. Alex sells U, then buys U back (opposite round trip)
     * 4. Result: Both have same U as start, but alex gained W and beck lost W
     */
    function test_ArbitrageProfitRoundTrip(uint256 poolSolid, uint256 poolHub, uint256 tradeSize) public {
        // Constrain pool sizes to valid ranges (reserve funds for alex and beck)
        // Minimum of 1000 to ensure meaningful trades where slippage is observable
        uint256 minSize = 1000;
        uint256 maxPoolSolid = owen.balance(S) / 3;
        uint256 maxPoolHub = owen.balance(W) / 3;
        poolSolid = poolSolid % (maxPoolSolid - minSize) + minSize;
        poolHub = poolHub % (maxPoolHub - minSize) + minSize;

        // Owen creates pool
        owen.heat(U, poolSolid, poolHub);

        // Alex heats same solid as pool to ensure enough U for arbitrage
        give(alex, poolSolid, U.solid());
        alex.heat(U, poolSolid);

        // Record pool state after setup
        (uint256 P0, uint256 E0) = U.pool();

        // Limit trade size: for beckU <= alexU, need tradeSize <= poolHub/2
        // Minimum trade of poolHub/10 to ensure observable effects
        uint256 maxTrade = poolHub / 2;
        uint256 minTrade = poolHub / 10;
        tradeSize = tradeSize % (maxTrade - minTrade) + minTrade;

        // Seed alex and beck with equal W (hub tokens)
        give(alex, tradeSize, W);
        give(beck, tradeSize, W);

        // Record starting balances
        uint256 alexWStart = alex.balance(W);
        uint256 alexUStart = alex.balance(U);
        uint256 beckWStart = beck.balance(W);
        uint256 beckUStart = beck.balance(U);

        // Step 1: Beck buys U with all his W (moves price up)
        uint256 beckU = beck.buy(U, tradeSize);

        // Step 2: Alex sells same amount of U (captures high price)
        alex.sell(U, beckU);

        // Step 3: Beck sells his U back (at lower price now)
        uint256 beckW = beck.sell(U, beckU);

        // Step 4: Alex buys back U with same W that beck received
        alex.buy(U, beckW);

        // Verify pool restored to original state (within 2% rounding tolerance for 4 trades)
        (uint256 P1, uint256 E1) = U.pool();
        assertApproxEqRel(P1, P0, 0.02e18, "Pool U should be approximately restored");
        assertApproxEqRel(E1, E0, 0.02e18, "Pool W should be approximately restored");

        // Verify both have approximately same U as they started (within rounding)
        uint256 alexUEnd = alex.balance(U);
        uint256 beckUEnd = beck.balance(U);
        assertEq(beckUEnd, beckUStart, "Beck should have same U as start");
        assertApproxEqRel(alexUEnd, alexUStart, 0.02e18, "Alex should have approximately same U as start");

        // Verify beck lost W and alex gained W
        uint256 alexWEnd = alex.balance(W);
        uint256 beckWEnd = beck.balance(W);
        assertGt(alexWEnd, alexWStart, "Alex should have more W than start");
        assertLt(beckWEnd, beckWStart, "Beck should have less W than start");

        // Verify conservation: alex's gain approximately equals beck's loss (within rounding)
        uint256 alexGain = alexWEnd - alexWStart;
        uint256 beckLoss = beckWStart - beckWEnd;
        assertApproxEqRel(alexGain, beckLoss, 0.02e18, "Alex's gain approximately equals beck's loss");
    }

    /**
     * @notice Test that cools(u, e) returns sensible values.
     *
     * This test exposes bugs in cools(uint256 u, uint256 e):
     * 1. s is used before initialization (always 0)
     * 2. Result assigned to u instead of return value s
     * 3. Return values s and p are never set (always 0)
     */
    function test_CoolsWithHub(uint256 poolSolid, uint256 poolHub) public {
        // Constrain pool sizes
        uint256 minSize = 1000;
        uint256 maxPoolSolid = owen.balance(S) / 2;
        uint256 maxPoolHub = owen.balance(W) / 2;
        poolSolid = poolSolid % (maxPoolSolid - minSize) + minSize;
        poolHub = poolHub % (maxPoolHub - minSize) + minSize;

        // Owen creates pool
        owen.heat(U, poolSolid, poolHub);

        // Get pool state
        (uint256 P, uint256 E) = U.pool();
        assertGt(P, 0, "Pool should have U");
        assertGt(E, 0, "Pool should have W");

        // Test cools(u, e) - the two-parameter version
        uint256 testU = poolSolid / 10;
        uint256 testE = poolHub / 10;

        // Call cools(u, e) and check it returns non-zero values
        (uint256 s, uint256 p) = U.cools(testU, testE);

        // These assertions will FAIL if cools is broken (returns 0)
        assertGt(s, 0, "cools(u,e) should return non-zero solid");
        // p might legitimately be 0 in some cases, but s should not be
    }
}
