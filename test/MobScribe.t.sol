// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "forge-std/Test.sol";

import {Mob} from "../src/Mob.sol";
import {MobScribe} from "../src/MobScribe.sol";

contract MockERC20 {
    string public name = "Mock";
    string public symbol = "MOCK";
    uint8 public decimals = 18;

    mapping(address => uint256) public balanceOf;

    event Transfer(address indexed from, address indexed to, uint256 amount);

    function mint(address to, uint256 amount) external {
        balanceOf[to] += amount;
        emit Transfer(address(0), to, amount);
    }

    function transfer(address to, uint256 amount) external returns (bool) {
        uint256 bal = balanceOf[msg.sender];
        require(bal >= amount, "insufficient");
        unchecked {
            balanceOf[msg.sender] = bal - amount;
        }
        balanceOf[to] += amount;
        emit Transfer(msg.sender, to, amount);
        return true;
    }
}

contract MobScribeTest is Test {
    Mob private mobProto;
    Mob private mob;
    MobScribe private builder;
    MockERC20 private token;

    address private alice = address(0xA11CE);
    address private bob = address(0xB0B);
    address private carol = address(0xCA301);
    address private recipient = address(0xBEEF);

    function setUp() public {
        address[] memory members = new address[](2);
        uint256[] memory weights = new uint256[](2);

        members[0] = alice;
        weights[0] = 2;

        members[1] = bob;
        weights[1] = 1;

        mobProto = new Mob();
        mob = mobProto.make(members, weights, 3);
        builder = new MobScribe();
        token = new MockERC20();

        token.mint(address(mob), 1_000e18);
    }

    function test_MessageBuildsAndExecutesOnce_WhenThresholdReached() public {
        uint256 amount = 123e18;

        bytes memory message = builder.transfer(address(token), recipient, amount, 0);

        assertEq(token.balanceOf(address(mob)), 1_000e18);
        assertEq(token.balanceOf(recipient), 0);

        // Alice approves (weight 2) => not enough to execute yet.
        vm.prank(alice);
        (bool ok1,) = address(mob).call(message);
        assertTrue(ok1);

        assertEq(token.balanceOf(address(mob)), 1_000e18);
        assertEq(token.balanceOf(recipient), 0);

        // Bob approves (weight 1) => total 3, executes.
        vm.prank(bob);
        (bool ok2,) = address(mob).call(message);
        assertTrue(ok2);

        assertEq(token.balanceOf(address(mob)), 1_000e18 - amount);
        assertEq(token.balanceOf(recipient), amount);

        // Any further approval of the exact same message should revert AlreadyRioted.
        vm.prank(alice);
        vm.expectRevert(Mob.ActFailed.selector);
        (bool ok,) = address(mob).call(message);
        assertTrue(!ok, "expected revert");
    }

    function test_RevertsForNonMember() public {
        bytes memory message = builder.transfer(address(token), recipient, 1, 0);

        vm.prank(carol);
        vm.expectRevert(Mob.NoSway.selector);
        (bool ok,) = address(mob).call(message);
        assertTrue(ok);
    }
}
