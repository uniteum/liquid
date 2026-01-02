// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract Mob {
    error NotMember();
    error LengthMismatch();
    error QuorumImpossible();
    error QuorumZero();
    error AlreadyInitialized();
    error AlreadyExecuted(bytes32 h);
    error BadMessage();
    error CallFailed(bytes32 h);

    event Make(Mob mob, address[] members, uint256[] mass_, uint256 quorum);

    Mob public immutable MOB = this;

    mapping(address => uint256) public mass;
    uint256 public quorum;

    mapping(bytes32 => uint256) public approval;
    mapping(bytes32 => mapping(address => bool)) public approvedBy;
    mapping(bytes32 => bool) public executed;

    function made(address[] memory members, uint256[] memory mass_, uint256 quorum_)
        public
        view
        returns (address location, bytes32 salt)
    {
        if (quorum_ == 0) {
            revert QuorumZero();
        }
        if (members.length != mass_.length) {
            revert LengthMismatch();
        }
        uint256 sum;
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            uint256 w = mass_[i];
            if (m == address(0) || w == 0) {
                revert NotMember();
            }
            sum += w;
        }
        if (quorum_ > sum) {
            revert QuorumImpossible();
        }
        salt = keccak256(abi.encode(members, mass_, quorum_));
        location = Clones.predictDeterministicAddress(address(MOB), salt, address(MOB));
    }

    function make(address[] memory members, uint256[] memory mass_, uint256 quorum_) public returns (Mob mob) {
        if (this != MOB) {
            mob = MOB.make(members, mass_, quorum_);
        } else {
            (address location, bytes32 salt) = made(members, mass_, quorum_);
            mob = Mob(payable(location));
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(MOB), salt);
                mob.__initialize(members, mass_, quorum_);
                emit Make(mob, members, mass_, quorum_);
            }
        }
    }

    function __initialize(address[] memory members, uint256[] memory mass_, uint256 quorum_) external {
        if (quorum != 0) {
            revert AlreadyInitialized();
        }
        for (uint256 i = 0; i < members.length; i++) {
            mass[members[i]] = mass_[i];
        }
        quorum = quorum_;
    }

    receive() external payable {}

    fallback() external payable {
        uint256 w = mass[msg.sender];
        if (w == 0) revert NotMember();

        bytes calldata m = msg.data;
        if (m.length < 20 + 32) revert BadMessage();

        bytes32 h = keccak256(m);

        if (executed[h]) revert AlreadyExecuted(h);
        uint256 total = approval[h];
        if (!approvedBy[h][msg.sender]) {
            approvedBy[h][msg.sender] = true;
            total += w;
            approval[h] = total;
        }

        if (total >= quorum) {
            _exec(h, m);
        }
    }

    function _exec(bytes32 h, bytes calldata m) private {
        address to;
        uint256 value;

        // to @ [0..20), value @ [20..52)
        assembly {
            to := shr(96, calldataload(m.offset))
            value := calldataload(add(m.offset, 20))
        }

        bytes calldata data = m[20 + 32:];

        (bool ok,) = to.call{value: value}(data);
        if (!ok) revert CallFailed(h);

        executed[h] = true;
    }
}
