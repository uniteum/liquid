// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract Mob {
    error AlreadyInitialized();
    error NotMember();
    error LengthMismatch();
    error RiotImpossible();
    error RiotAlways();
    error BadMessage();
    error AlreadyRioted(bytes32 h);
    error CallFailed(bytes32 h);

    event Make(Mob mob, address[] members, uint256[] rage_, uint256 boil);

    Mob public immutable MOB = this;

    mapping(address => uint256) public rage;
    uint256 public boil;

    mapping(bytes32 => uint256) public fury;
    mapping(bytes32 => mapping(address => bool)) public yelled;
    mapping(bytes32 => bool) public boiled;

    function made(address[] memory members, uint256[] memory rage_, uint256 boil_)
        public
        view
        returns (address location, bytes32 salt)
    {
        if (boil_ == 0) {
            revert RiotAlways();
        }
        if (members.length != rage_.length) {
            revert LengthMismatch();
        }
        uint256 sum;
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            uint256 w = rage_[i];
            if (m == address(0) || w == 0) {
                revert NotMember();
            }
            sum += w;
        }
        if (boil_ > sum) {
            revert RiotImpossible();
        }
        salt = keccak256(abi.encode(members, rage_, boil_));
        location = Clones.predictDeterministicAddress(address(MOB), salt, address(MOB));
    }

    function make(address[] memory members, uint256[] memory rage_, uint256 boil_) public returns (Mob mob) {
        if (this != MOB) {
            mob = MOB.make(members, rage_, boil_);
        } else {
            (address location, bytes32 salt) = made(members, rage_, boil_);
            mob = Mob(payable(location));
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(MOB), salt);
                mob.__initialize(members, rage_, boil_);
                emit Make(mob, members, rage_, boil_);
            }
        }
    }

    function __initialize(address[] memory members, uint256[] memory rage_, uint256 boil_) external {
        if (boil != 0) {
            revert AlreadyInitialized();
        }
        for (uint256 i = 0; i < members.length; i++) {
            rage[members[i]] = rage_[i];
        }
        boil = boil_;
    }

    receive() external payable {}

    fallback() external payable {
        uint256 w = rage[msg.sender];
        if (w == 0) revert NotMember();

        bytes calldata yell = msg.data;
        if (yell.length < 20 + 32) revert BadMessage();

        bytes32 h = keccak256(yell);

        if (boiled[h]) revert AlreadyRioted(h);
        uint256 total = fury[h];
        if (!yelled[h][msg.sender]) {
            yelled[h][msg.sender] = true;
            total += w;
            fury[h] = total;
        }

        if (total >= boil) {
            _boil(h, yell);
        }
    }

    function _boil(bytes32 h, bytes calldata yell) private {
        address to;
        uint256 value;

        // to @ [0..20), value @ [20..52)
        assembly {
            to := shr(96, calldataload(yell.offset))
            value := calldataload(add(yell.offset, 20))
        }

        bytes calldata data = yell[20 + 32:];
        (bool ok,) = to.call{value: value}(data);
        if (!ok) revert CallFailed(h);

        boiled[h] = true;
    }
}
