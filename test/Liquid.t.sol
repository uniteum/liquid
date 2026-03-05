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
        (uint256 p2, uint256 e2) = U.pool();
        assertEq(p2, P, "Pool should have starting U");
        assertEq(e2, E, "Pool should have starting E");
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
        (uint256 p2, uint256 e2) = U.pool();
        assertEq(p2, 2 * P, "Pool had unexpected U");
        assertEq(e2, E, "Pool had unexpected E");
        console.log("2.test_SimpleHeatCool.alex.heat.s:", s);
        (u, p) = alex.heat(U, s);
        assertEq(u, s, "1. alex liquid != solid");
        assertEq(p, s, "1. pool liquid != solid");
        (u, s) = alex.liquidate(U);
        assertEq(u, s, "2. alex liquid != solid");
        assertEq(p, s, "2. pool liquid != solid");
        (p2, e2) = U.pool();
        assertEq(p2, 2 * P, "Pool should have starting U");
        assertEq(e2, E, "Pool should have starting E");
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
        (uint256 p0, uint256 e0) = U.pool();

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
        (uint256 pMid, uint256 eMid) = U.pool();
        assertLt(pMid, p0, "Beck's buy should decrease pool U");
        assertGt(eMid, e0, "Beck's buy should increase pool W");

        // Alex sells exactly what beck bought to restore pool balance
        uint256 alexW = alex.sell(U, beckU);

        // Pool should be restored to original state (within 1% rounding tolerance)
        (uint256 p1, uint256 e1) = U.pool();
        assertEq(p1, p0, "Pool U should be restored");
        assertApproxEqRel(e1, e0, 0.01e18, "Pool W should be approximately restored");

        // Calculate fair value of beckU at the balanced pool price (e0/p0)
        uint256 fairValue = beckU * e0 / p0;

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
        (uint256 p0, uint256 e0) = U.pool();

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
        (uint256 p1, uint256 e1) = U.pool();
        assertApproxEqRel(p1, p0, 0.02e18, "Pool U should be approximately restored");
        assertApproxEqRel(e1, e0, 0.02e18, "Pool W should be approximately restored");

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

        // Verify conservation: alex's gain approximately equals beck's loss
        // 3% tolerance for 4 trades with cumulative rounding
        uint256 alexGain = alexWEnd - alexWStart;
        uint256 beckLoss = beckWStart - beckWEnd;
        assertApproxEqRel(alexGain, beckLoss, 0.03e18, "Alex's gain approximately equals beck's loss");
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
        (uint256 s,) = U.cools(testU, testE);

        // These assertions will FAIL if cools is broken (returns 0)
        assertGt(s, 0, "cools(u,e) should return non-zero solid");
    }

    /**
     * @notice Test that heat/cool maintain u = s equilibrium.
     *
     * The tokenomics are designed so that:
     * 1. Initial heat(s, e) sets P/T = 1/2 (pool holds half the supply)
     * 2. When P/T = 1/2, heats(s) returns u = s and cools(u) returns s = u
     * 3. Both heat and cool preserve the P/T ratio
     *
     * This means arbitrage keeps u = s because:
     * - If P > T/2: cooling is favorable (s > u), people cool, reducing P
     * - If P < T/2: heating is favorable (u > s), people heat, increasing P
     * - At equilibrium P = T/2: u = s, no arbitrage opportunity
     */
    function test_HeatCoolEquilibrium(uint256 poolSolid, uint256 poolHub, uint256) public {
        // Constrain inputs
        uint256 minSize = 1000;
        uint256 maxPoolSolid = owen.balance(S) / 4;
        uint256 maxPoolHub = owen.balance(W) / 4;
        poolSolid = poolSolid % (maxPoolSolid - minSize) + minSize;
        poolHub = poolHub % (maxPoolHub - minSize) + minSize;

        // Owen creates initial pool with heat(s, e)
        owen.heat(U, poolSolid, poolHub);

        // Verify initial state: P = T/2 (pool holds half the supply)
        (uint256 p0,) = U.pool();
        uint256 t0 = U.totalSupply();
        assertEq(p0 * 2, t0, "Initial pool should hold half the supply (P = T/2)");

        // At P = T/2, heats(s) should return u = s
        uint256 testSolid = poolSolid / 10;
        (uint256 uHeat, uint256 pHeat) = U.heats(testSolid);
        assertEq(uHeat, testSolid, "At equilibrium, heats(s) should return u = s");
        assertEq(pHeat, testSolid, "At equilibrium, heats(s) should return p = s");

        // At P = T/2, cools(u) should return s = u
        uint256 testLiquid = poolSolid / 10;
        (uint256 sCool, uint256 pCool) = U.cools(testLiquid);
        assertEq(sCool, testLiquid, "At equilibrium, cools(u) should return s = u");
        assertEq(pCool, testLiquid, "At equilibrium, cools(u) should return p = u");

        // Now verify that heat preserves P/T ratio
        give(alex, testSolid, U.solid());
        alex.heat(U, testSolid);

        (uint256 p1,) = U.pool();
        uint256 t1 = U.totalSupply();
        // P/T should still equal 1/2
        assertEq(p1 * 2, t1, "Heat should preserve P = T/2 ratio");

        // Verify u = s still holds after the heat
        (uint256 uAfter,) = U.heats(testSolid);
        assertEq(uAfter, testSolid, "After heat, u should still equal s");

        // Cool and verify ratio is preserved
        uint256 alexLiquid = U.balanceOf(address(alex));
        if (alexLiquid > 0) {
            alex.cool(U, alexLiquid / 2);
            (uint256 p2,) = U.pool();
            uint256 t2 = U.totalSupply();
            assertEq(p2 * 2, t2, "Cool should preserve P = T/2 ratio");
        }
    }

    /**
     * @notice Test arbitrage incentives when pool ratio deviates from equilibrium.
     *
     * This test demonstrates the arbitrage incentives:
     * - When P > T/2: cooling gives s > u (favorable to cool)
     * - When P < T/2: heating gives u > s (favorable to heat)
     */
    function test_ArbitrageIncentivesFromImbalance() public {
        // Create initial balanced pool
        uint256 poolSize = 10000;
        owen.heat(U, poolSize, poolSize);

        // Verify starting equilibrium
        (uint256 p0,) = U.pool();
        uint256 t0 = U.totalSupply();
        assertEq(p0 * 2, t0, "Should start at equilibrium");

        // At equilibrium, u = s
        (uint256 uEq,) = U.heats(1000);
        (uint256 sEq,) = U.cools(1000);
        assertEq(uEq, 1000, "At equilibrium: heat gives u = s");
        assertEq(sEq, 1000, "At equilibrium: cool gives s = u");

        // The ratio P/T is preserved by heat/cool, so the system stays at equilibrium
        // This is by design - the initial heat(s,e) sets P = T/2, and all subsequent
        // operations preserve this ratio.

        // Verify this invariant holds after multiple operations
        give(alex, 5000, U.solid());
        alex.heat(U, 5000);

        (uint256 p1,) = U.pool();
        uint256 t1 = U.totalSupply();
        assertEq(p1 * 2, t1, "Ratio preserved after alex heat");

        give(beck, 3000, U.solid());
        beck.heat(U, 3000);

        (uint256 p2,) = U.pool();
        uint256 t2 = U.totalSupply();
        assertEq(p2 * 2, t2, "Ratio preserved after beck heat");

        // Alex cools some
        uint256 alexBalance = U.balanceOf(address(alex));
        alex.cool(U, alexBalance / 2);

        (uint256 p3,) = U.pool();
        uint256 t3 = U.totalSupply();
        assertEq(p3 * 2, t3, "Ratio preserved after alex cool");

        // u = s should still hold
        (uint256 uFinal,) = U.heats(1000);
        (uint256 sFinal,) = U.cools(1000);
        assertEq(uFinal, 1000, "After all operations: heat still gives u = s");
        assertEq(sFinal, 1000, "After all operations: cool still gives s = u");
    }

    /**
     * @notice Test that buy/sell break the P/T equilibrium, creating heat/cool arbitrage.
     *
     * Buy/sell transfer tokens between pool and users without mint/burn:
     * - buy(hub): P decreases, E increases, T unchanged → P/T < 1/2
     * - sell(liquid): P increases, E decreases, T unchanged → P/T > 1/2
     *
     * This creates arbitrage opportunities:
     * - After buy (P/T < 1/2): heating is favorable (u > s)
     * - After sell (P/T > 1/2): cooling is favorable (s > u)
     */
    function test_BuySellBreaksEquilibrium(uint256 poolSolid, uint256 poolHub, uint256 tradeSize) public {
        // Constrain inputs
        uint256 minSize = 1000;
        uint256 maxPoolSolid = owen.balance(S) / 4;
        uint256 maxPoolHub = owen.balance(W) / 4;
        poolSolid = poolSolid % (maxPoolSolid - minSize) + minSize;
        poolHub = poolHub % (maxPoolHub - minSize) + minSize;

        // Owen creates initial balanced pool
        owen.heat(U, poolSolid, poolHub);

        // Verify starting equilibrium: P = T/2, so u = s
        (uint256 p0, uint256 e0) = U.pool();
        uint256 t0 = U.totalSupply();
        assertEq(p0 * 2, t0, "Should start at equilibrium P = T/2");

        (uint256 uBefore,) = U.heats(1000);
        (uint256 sBefore,) = U.cools(1000);
        assertEq(uBefore, 1000, "Before trade: u = s for heat");
        assertEq(sBefore, 1000, "Before trade: s = u for cool");

        // Limit trade size to avoid exhausting pool
        tradeSize = tradeSize % (poolHub / 4) + minSize;

        // Alex buys liquid with hub (P decreases, T unchanged → P/T < 1/2)
        give(alex, tradeSize, W);
        uint256 liquidBought = alex.buy(U, tradeSize);

        // Verify P decreased but T unchanged
        (uint256 p1, uint256 e1) = U.pool();
        uint256 t1 = U.totalSupply();
        assertLt(p1, p0, "Buy should decrease pool liquid (P)");
        assertGt(e1, e0, "Buy should increase pool hub (E)");
        assertEq(t1, t0, "Buy should not change total supply");

        // Now P/T < 1/2, so heating should be favorable (u > s)
        (uint256 uAfterBuy,) = U.heats(1000);
        (uint256 sAfterBuy,) = U.cools(1000);
        assertGt(uAfterBuy, 1000, "After buy: heating favorable, u > s");
        assertLt(sAfterBuy, 1000, "After buy: cooling unfavorable, s < u");

        // Alex sells liquid back (P increases, T unchanged → P/T moves toward 1/2)
        alex.sell(U, liquidBought);

        // Verify P increased back
        (uint256 p2,) = U.pool();
        uint256 t2 = U.totalSupply();
        assertGt(p2, p1, "Sell should increase pool liquid (P)");
        assertEq(t2, t0, "Sell should not change total supply");

        // P should be approximately restored (may have small rounding)
        assertApproxEqRel(p2, p0, 0.01e18, "P should be approximately restored after round-trip");

        // u = s should be approximately restored
        (uint256 uAfterSell,) = U.heats(1000);
        assertApproxEqAbs(uAfterSell, 1000, 10, "After sell: u approx s restored");
    }

    /**
     * @notice Test that heat captures arbitrage profit after buy creates imbalance.
     *
     * Key insight: heat/cool PRESERVE P/T ratio, they don't restore it to 1/2.
     * The arbitrage profit is in the favorable RATE (u > s), not in changing the ratio.
     *
     * Scenario:
     * 1. Pool starts balanced (P = T/2)
     * 2. Beck buys liquid → P/T < 1/2 → heating favorable (u > s)
     * 3. Alex heats to capture arbitrage profit (gets more liquid than solid)
     * 4. P/T ratio is preserved (not restored) but alex profited from favorable rate
     */
    function test_HeatArbitrageAfterBuy(uint256 poolSolid, uint256 poolHub, uint256 tradeSize) public {
        // Constrain inputs
        uint256 minSize = 1000;
        uint256 maxPoolSolid = owen.balance(S) / 4;
        uint256 maxPoolHub = owen.balance(W) / 4;
        poolSolid = poolSolid % (maxPoolSolid - minSize) + minSize;
        poolHub = poolHub % (maxPoolHub - minSize) + minSize;

        // Owen creates initial balanced pool
        owen.heat(U, poolSolid, poolHub);

        // Verify starting equilibrium
        uint256 t0 = U.totalSupply();
        (uint256 p0,) = U.pool();
        assertEq(p0 * 2, t0, "Should start at equilibrium");

        // Limit trade size
        tradeSize = tradeSize % (poolHub / 4) + minSize;

        // Beck buys liquid (creates imbalance: P/T < 1/2)
        give(beck, tradeSize, W);
        beck.buy(U, tradeSize);

        // Verify imbalance: P/T < 1/2
        (uint256 p1,) = U.pool();
        uint256 t1 = U.totalSupply();
        assertLt(p1 * 2, t1, "After buy: P/T < 1/2");

        // Check heating is now favorable (u > s)
        (uint256 uImbalanced,) = U.heats(1000);
        assertGt(uImbalanced, 1000, "Imbalanced pool: heating gives u > s");

        // Alex heats to capture arbitrage (gets more liquid than solid deposited)
        uint256 alexSolid = poolSolid / 10;
        give(alex, alexSolid, U.solid());
        (uint256 alexLiquid,) = alex.heat(U, alexSolid);

        // Alex got more liquid than solid (arbitrage profit)
        assertGt(alexLiquid, alexSolid, "Alex arbitrage: received more liquid than solid deposited");

        // IMPORTANT: P/T ratio is PRESERVED by heat, not restored to 1/2
        (uint256 p2,) = U.pool();
        uint256 t2 = U.totalSupply();
        uint256 ratioBefore = p1 * 1e18 / t1;
        uint256 ratioAfter = p2 * 1e18 / t2;
        assertApproxEqRel(ratioAfter, ratioBefore, 0.001e18, "Heat preserves P/T ratio");
    }

    /**
     * @notice Test that cool captures arbitrage profit after sell creates imbalance.
     *
     * Key insight: heat/cool PRESERVE P/T ratio, they don't restore it to 1/2.
     * The arbitrage profit is in the favorable RATE (s > u), not in changing the ratio.
     *
     * Scenario:
     * 1. Pool starts balanced (P = T/2)
     * 2. Beck sells liquid → P/T > 1/2 → cooling favorable (s > u)
     * 3. Alex cools to capture arbitrage profit (gets more solid than liquid burned)
     * 4. P/T ratio is preserved (not restored) but alex profited from favorable rate
     */
    function test_CoolArbitrageAfterSell(uint256 poolSolid, uint256 poolHub, uint256 tradeSize) public {
        // Constrain inputs
        uint256 minSize = 1000;
        uint256 maxPoolSolid = owen.balance(S) / 4;
        uint256 maxPoolHub = owen.balance(W) / 4;
        poolSolid = poolSolid % (maxPoolSolid - minSize) + minSize;
        poolHub = poolHub % (maxPoolHub - minSize) + minSize;

        // Owen creates initial balanced pool
        owen.heat(U, poolSolid, poolHub);

        // Beck needs liquid to sell - heat some first
        uint256 beckSolid = poolSolid / 2;
        give(beck, beckSolid, U.solid());
        (uint256 beckLiquid,) = beck.heat(U, beckSolid);

        // Verify still at equilibrium after beck's heat
        uint256 t0 = U.totalSupply();
        (uint256 p0,) = U.pool();
        assertEq(p0 * 2, t0, "Should still be at equilibrium after beck heat");

        // Trade size must be significant to create observable imbalance
        // Minimum 10% of beck's liquid to ensure s > u is detectable
        uint256 minTrade = beckLiquid / 10;
        uint256 maxTrade = beckLiquid / 2;
        tradeSize = tradeSize % (maxTrade - minTrade) + minTrade;

        // Beck sells liquid (creates imbalance: P/T > 1/2)
        beck.sell(U, tradeSize);

        // Verify imbalance: P/T > 1/2
        (uint256 p1,) = U.pool();
        uint256 t1 = U.totalSupply();
        assertGt(p1 * 2, t1, "After sell: P/T > 1/2");

        // Check cooling is now favorable (s > u)
        (uint256 sImbalanced,) = U.cools(1000);
        assertGt(sImbalanced, 1000, "Imbalanced pool: cooling gives s > u");

        // Alex needs liquid to cool - get some from owen who has liquid from initial heat
        // Note: owen has liquid from heat(poolSolid, poolHub)
        uint256 alexLiquid = poolSolid / 10;
        // Owen gives alex some liquid tokens directly
        give(alex, alexLiquid, U);

        // Now alex cools to capture arbitrage
        (uint256 alexSolidGained,) = alex.cool(U, alexLiquid);

        // At P/T > 1/2, cooling gives s > u, so alex gets more solid than liquid burned
        assertGt(alexSolidGained, alexLiquid, "Alex arbitrage: received more solid than liquid burned");

        // IMPORTANT: P/T ratio is PRESERVED by cool, not restored to 1/2
        (uint256 p2,) = U.pool();
        uint256 t2 = U.totalSupply();
        uint256 ratioBefore = p1 * 1e18 / t1;
        uint256 ratioAfter = p2 * 1e18 / t2;
        assertApproxEqRel(ratioAfter, ratioBefore, 0.001e18, "Cool preserves P/T ratio");
    }
}
