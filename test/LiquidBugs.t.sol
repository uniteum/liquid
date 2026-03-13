// SPDX-License-Identifier: LicenseRef-Uniteum

pragma solidity ^0.8.30;

import {Liquid, ILiquid} from "../src/Liquid.sol";
import {BaseTest} from "./Base.t.sol";
import {LiquidUser, IERC20Metadata} from "./LiquidUser.sol";
import {TestToken} from "./TestToken.sol";
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
     * @notice heats(s, e) called on the hub should revert with HubNotPool.
     */
    function test_NotHub_RevertsOnHub() public {
        vm.expectRevert(ILiquid.HubNotPool.selector);
        W.heats(100, 100);
    }

    /**
     * @notice cools(u, e) called on the hub should revert with HubNotPool.
     */
    function test_NotHub_CoolsRevertsOnHub() public {
        vm.expectRevert(ILiquid.HubNotPool.selector);
        W.cools(100, 100);
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

        vm.startPrank(address(alex));
        U.solid().approve(address(U), 100);

        vm.expectEmit(true, false, false, false, address(U));
        emit ILiquid.Heat(U, 0, 0, 0);

        U.heat(100, 0);
        vm.stopPrank();
    }

    /**
     * @notice cool(u) on a spoke must emit Cool.
     */
    function test_CoolSingleArg_EmitsEvent() public {
        give(owen, GIFT, IERC20Metadata(address(W)));
        owen.heat(U, GIFT, GIFT);

        give(alex, 100, U.solid());
        vm.startPrank(address(alex));
        U.solid().approve(address(U), 100);
        U.heat(100, 0);
        vm.stopPrank();

        uint256 alexLiquid = U.balanceOf(address(alex));

        vm.expectEmit(true, false, false, false, address(U));
        emit ILiquid.Cool(U, 0, 0, 0);

        vm.prank(address(alex));
        U.cool(alexLiquid, 0);
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

        vm.prank(address(alex));
        U.cool(alexLiquid, hubAmount);

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

        vm.prank(address(alex));
        U.cool(alexLiquid, 0);

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
    // Bug 6: zzz_ had no access control
    // ---------------------------------------------------------------

    /**
     * @notice zzz_ must revert when called by a non-liquid address.
     */
    function test_zzz_RevertsForNonLiquid() public {
        TestToken realBacking = owen.newToken("REAL", SUPPLY);
        W.make(IERC20Metadata(address(realBacking)));
        (, address predictedAddr,) = W.made(IERC20Metadata(address(realBacking)));
        Liquid spoke = Liquid(predictedAddr);

        TestToken fakeBacking = owen.newToken("FAKE", SUPPLY);

        // Non-liquid caller should be rejected
        vm.expectRevert();
        spoke.zzz_(IERC20Metadata(address(fakeBacking)));
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
