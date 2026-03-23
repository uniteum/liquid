// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid, ILiquid} from "../src/Liquid.sol";
import {BaseTest} from "crucible/test/Base.t.sol";
import {LiquidUser, IERC20Metadata} from "./LiquidUser.sol";
import {TestToken} from "crucible/test/TestToken.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

/**
 * @notice Regression tests for bugs found in Liquid.sol.
 * All tests should PASS against the fixed implementation.
 */
contract LiquidBugsTest is BaseTest {
    uint256 constant SUPPLY = 1e9;
    uint256 constant GIFT = 1e4;

    ILiquid public W;
    ILiquid public U;
    ILiquid public V;
    LiquidUser public owen;
    LiquidUser public alex;
    LiquidUser public beck;

    function setUp() public virtual override {
        super.setUp();
        owen = newUser("owen");
        alex = newUser("alex");
        beck = newUser("beck");
        W = new Liquid(owen.newToken("W", SUPPLY));
        owen.heat(W, SUPPLY, 0);
        U = W.make(owen.newToken("U", SUPPLY));
        V = W.make(owen.newToken("V", SUPPLY));
    }

    function newUser(string memory name) internal returns (LiquidUser user) {
        user = new LiquidUser(name, W);
    }

    function give(LiquidUser user, uint256 amount, IERC20Metadata token) internal {
        owen.give(address(user), amount, token);
    }

    // ---------------------------------------------------------------
    // Bug 1: notHub modifier was checking msg.sender instead of address(this)
    // ---------------------------------------------------------------

    /**
     * @notice heats(s, e) called on the hub ignores e and returns u = m.
     */
    function test_Hub_HeatsIgnoresE() public view {
        (uint256 u, uint256 p) = W.heats(100, 100);
        assertEq(u, 100, "Hub heats should return u = m");
        assertEq(p, 0, "Hub heats should return p = 0");
    }

    /**
     * @notice cools(u, e) called on the hub ignores e and returns m = u.
     */
    function test_Hub_CoolsIgnoresE() public view {
        (uint256 m, uint256 p) = W.cools(100, 100);
        assertEq(m, 100, "Hub cools should return m = u");
        assertEq(p, 0, "Hub cools should return p = 0");
    }

    // ---------------------------------------------------------------
    // Bug 2: Missing events on non-hub heat(s) and cool(u)
    // ---------------------------------------------------------------

    /**
     * @notice heat(s) on a spoke must emit Heat.
     */
    function test_HeatSingleArg_EmitsEvent() public {
        give(owen, GIFT, IERC20Metadata(address(W)));
        owen.heat(U, GIFT, GIFT);

        give(alex, 100, U.solid());

        vm.expectEmit(true, false, false, false, address(U));
        emit ILiquid.Heat(U, 0, 0, 0, 0);

        alex.heat(U, 100, 0);
    }

    /**
     * @notice cool(u) on a spoke must emit Cool.
     */
    function test_CoolSingleArg_EmitsEvent() public {
        give(owen, GIFT, IERC20Metadata(address(W)));
        owen.heat(U, GIFT, GIFT);

        give(alex, 100, U.solid());
        alex.heat(U, 100, 0);

        uint256 alexLiquid = U.balanceOf(address(alex));

        vm.expectEmit(true, false, false, false, address(U));
        emit ILiquid.Cool(U, 0, 0, 0, 0);

        alex.cool(U, alexLiquid, 0);
    }

    // ---------------------------------------------------------------
    // Bug 3: Missing nonReentrant on heat(s)
    // ---------------------------------------------------------------

    /**
     * @notice heat(s) must block reentrancy via malicious solid token callbacks.
     */
    function test_Heat_ReentrancyBlocked() public {
        TestToken hookSolid = owen.newToken("HOOK", SUPPLY);
        ILiquid hookLiquid = W.make(IERC20Metadata(address(hookSolid)));

        owen.heat(hookLiquid, GIFT, GIFT);

        ReentrantHeater heater = new ReentrantHeater(hookLiquid, hookSolid);
        owen.give(address(heater), 200, IERC20Metadata(address(hookSolid)));
        heater.approve();

        // The reentrant call inside the hook should revert
        vm.expectRevert(ReentrancyGuardTransient.ReentrancyGuardReentrantCall.selector);
        heater.attack(100);
    }

    // ---------------------------------------------------------------
    // Bug 4: cool(u, e) — mass() read after transfer + missing hub transfer
    // ---------------------------------------------------------------

    /**
     * @notice cool(u, e) must transfer hub tokens to the caller.
     */
    function test_CoolWithHub_TransfersHubTokens() public {
        give(owen, GIFT, IERC20Metadata(address(W)));
        owen.heat(U, GIFT, GIFT);

        give(alex, 1000, U.solid());
        alex.heat(U, 1000, 0);

        uint256 alexLiquid = U.balanceOf(address(alex));
        uint256 hubAmount = 100;

        uint256 alexHubBefore = W.balanceOf(address(alex));

        alex.cool(U, alexLiquid, hubAmount);

        uint256 alexHubAfter = W.balanceOf(address(alex));
        assertGt(alexHubAfter, alexHubBefore, "Alex should receive hub tokens from cool(u, e)");
    }

    /**
     * @notice cool(u) pool burn should match the cools() quote.
     */
    function test_Cool_PoolBurnMatchesQuote() public {
        give(owen, GIFT, IERC20Metadata(address(W)));
        owen.heat(U, GIFT, GIFT);

        give(alex, 1000, U.solid());
        alex.heat(U, 1000, 0);

        uint256 alexLiquid = U.balanceOf(address(alex));
        uint256 poolBefore = U.balanceOf(address(U));

        (, uint256 quotedPoolBurn) = U.cools(alexLiquid, 0);

        alex.cool(U, alexLiquid, 0);

        uint256 poolAfter = U.balanceOf(address(U));
        uint256 actualPoolBurn = poolBefore - poolAfter;

        assertEq(actualPoolBurn, quotedPoolBurn, "Pool burn should match cools() quote");
    }

    // ---------------------------------------------------------------
    // Bug 5: sellFor was routing tokens incorrectly
    // ---------------------------------------------------------------

    /**
     * @notice sellFor must deliver target spoke tokens to the caller.
     */
    function test_SellFor_UserReceivesTargetSpokes() public {
        give(owen, GIFT, IERC20Metadata(address(W)));
        owen.heat(U, GIFT, GIFT);
        owen.heat(V, GIFT, GIFT);

        give(alex, 1000, U.solid());
        alex.heat(U, 1000, 0);

        uint256 alexU = U.balanceOf(address(alex));
        uint256 alexVBefore = V.balanceOf(address(alex));

        (, uint256 expectedV) = U.sellsFor(V, alexU);
        assertGt(expectedV, 0, "Should get non-zero target spokes");

        alex.sellFor(U, V, alexU);

        uint256 alexVAfter = V.balanceOf(address(alex));
        assertEq(alexVAfter - alexVBefore, expectedV, "User should receive target spoke tokens from sellFor");
    }

    /**
     * @notice After sellFor, the source spoke should NOT accumulate target tokens.
     */
    function test_SellFor_SpokeDoesNotAccumulateTargetTokens() public {
        give(owen, GIFT, IERC20Metadata(address(W)));
        owen.heat(U, GIFT, GIFT);
        owen.heat(V, GIFT, GIFT);

        give(alex, 1000, U.solid());
        alex.heat(U, 1000, 0);

        uint256 uHoldsVBefore = V.balanceOf(address(U));
        uint256 alexU = U.balanceOf(address(alex));

        alex.sellFor(U, V, alexU);

        uint256 uHoldsVAfter = V.balanceOf(address(U));
        assertEq(uHoldsVAfter, uHoldsVBefore, "Spoke U should not accumulate V tokens after sellFor");
    }

    // ---------------------------------------------------------------
    // Heat/cool roundtrip: cool(heat(m,0)) should restore state
    // ---------------------------------------------------------------

    /**
     * @notice heat(m,0) then cool(u,0) with the returned u should
     *         return exactly m solids and restore pool/supply.
     */
    function test_HeatCoolRoundtrip_RestoresState() public {
        // Bootstrap pool with non-zero P and E
        give(owen, GIFT, IERC20Metadata(address(W)));
        owen.heat(U, GIFT, GIFT);

        give(alex, 1000, U.solid());

        // Snapshot state before heat
        (uint256 P0, uint256 E0) = U.pool();
        uint256 T0 = U.totalSupply();
        uint256 M0 = U.mass();
        uint256 alexSolid0 = U.solid().balanceOf(address(alex));

        // Heat
        uint256 m = 500;
        (uint256 u,) = alex.heat(U, m, 0);
        assertGt(u, 0, "heat should mint user tokens");

        // Cool with the exact u returned by heat
        (uint256 mOut,) = alex.cool(U, u, 0);

        // Check solid roundtrip
        uint256 alexSolid1 = U.solid().balanceOf(address(alex));
        assertEq(mOut, m, "cool should return the same solids deposited");
        assertEq(alexSolid1, alexSolid0, "alex solid balance should be restored");

        // Check pool state restored
        (uint256 P1, uint256 E1) = U.pool();
        uint256 T1 = U.totalSupply();
        uint256 M1 = U.mass();
        assertEq(P1, P0, "pool spokes should be restored");
        assertEq(E1, E0, "pool hubs should be restored");
        assertEq(T1, T0, "total supply should be restored");
        assertEq(M1, M0, "mass should be restored");

        // Alex should hold no U tokens
        assertEq(U.balanceOf(address(alex)), 0, "alex should hold no liquid tokens");
    }

    // ---------------------------------------------------------------
    // Bug 6: zzInit had no access control
    // ---------------------------------------------------------------

    /**
     * @notice zzInit must revert when called by a non-liquid address.
     */
    function test_zzInitRevertsForNonLiquid() public {
        TestToken realBacking = owen.newToken("REAL", SUPPLY);
        W.make(IERC20Metadata(address(realBacking)));
        (, address predictedAddr,) = W.made(IERC20Metadata(address(realBacking)));
        Liquid spoke = Liquid(predictedAddr);

        TestToken fakeBacking = owen.newToken("FAKE", SUPPLY);

        // Non-liquid caller should be rejected
        vm.expectRevert();
        spoke.zzInit(IERC20Metadata(address(fakeBacking)));
    }
}

/**
 * @notice Helper contract that attempts reentrancy via heat(s).
 */
contract ReentrantHeater {
    ILiquid public target;
    TestToken public solid;
    bool public attacked;

    constructor(ILiquid target_, TestToken solid_) {
        target = target_;
        solid = solid_;
    }

    function approve() external {
        solid.approve(address(target), type(uint256).max);
    }

    function attack(uint256 amount) external {
        solid.doAfterUpdate(this.onTransfer);
        target.heat(amount, 0);
    }

    function onTransfer(IERC20Metadata, address, address, uint256) external {
        if (!attacked) {
            attacked = true;
            solid.clearAfterUpdate();
            target.heat(50, 0);
        }
    }
}
