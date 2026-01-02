// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract Mob {
    error NotMember();
    error LengthMismatch();
    error RiotImpossible();
    error RiotAlways();
    error AlreadyInitialized();
    error AlreadyRioted(bytes32 h);
    error BadMessage();
    error CallFailed(bytes32 h);

    event Make(Mob mob, address[] members, uint256[] rage_, uint256 riot);

    Mob public immutable MOB = this;

    mapping(address => uint256) public rage;
    uint256 public riot;

    mapping(bytes32 => uint256) public fury;
    mapping(bytes32 => mapping(address => bool)) public yelled;
    mapping(bytes32 => bool) public rioted;

    function made(address[] memory members, uint256[] memory rage_, uint256 riot_)
        public
        view
        returns (address location, bytes32 salt)
    {
        if (riot_ == 0) {
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
        if (riot_ > sum) {
            revert RiotImpossible();
        }
        salt = keccak256(abi.encode(members, rage_, riot_));
        location = Clones.predictDeterministicAddress(address(MOB), salt, address(MOB));
    }

    function make(address[] memory members, uint256[] memory rage_, uint256 riot_) public returns (Mob mob) {
        if (this != MOB) {
            mob = MOB.make(members, rage_, riot_);
        } else {
            (address location, bytes32 salt) = made(members, rage_, riot_);
            mob = Mob(payable(location));
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(MOB), salt);
                mob.__initialize(members, rage_, riot_);
                emit Make(mob, members, rage_, riot_);
            }
        }
    }

    function __initialize(address[] memory members, uint256[] memory rage_, uint256 riot_) external {
        if (riot != 0) {
            revert AlreadyInitialized();
        }
        for (uint256 i = 0; i < members.length; i++) {
            rage[members[i]] = rage_[i];
        }
        riot = riot_;
    }

    receive() external payable {}

    fallback() external payable {
        uint256 w = rage[msg.sender];
        if (w == 0) revert NotMember();

        bytes calldata yell = msg.data;
        if (yell.length < 20 + 32) revert BadMessage();

        bytes32 h = keccak256(yell);

        if (rioted[h]) revert AlreadyRioted(h);
        uint256 total = fury[h];
        if (!yelled[h][msg.sender]) {
            yelled[h][msg.sender] = true;
            total += w;
            fury[h] = total;
        }

        if (total >= riot) {
            _riot(h, yell);
        }
    }

    function _riot(bytes32 h, bytes calldata yell) private {
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

        rioted[h] = true;
    }
}
