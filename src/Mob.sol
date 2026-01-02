// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract Mob {
    error AlreadyInitialized();
    error NotMember();
    error LengthMismatch();
    error ActionImpossible();
    error QuorumZero();
    error BadMessage();
    error ActedAlready(bytes32 h);
    error CallFailed(bytes32 h);

    event Make(Mob mob, address[] members, uint256[] influence_, uint256 quorum);

    Mob public immutable MOB = this;

    mapping(address => uint256) public influence;
    uint256 public quorum;

    mapping(bytes32 => uint256) public tally;
    mapping(bytes32 => mapping(address => bool)) public voted;
    mapping(bytes32 => bool) public acted;

    function made(address[] memory members, uint256[] memory influence_, uint256 quorum_)
        public
        view
        returns (address location, bytes32 salt)
    {
        if (quorum_ == 0) {
            revert QuorumZero();
        }
        if (members.length != influence_.length) {
            revert LengthMismatch();
        }
        uint256 sum;
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            uint256 w = influence_[i];
            if (m == address(0) || w == 0) {
                revert NotMember();
            }
            sum += w;
        }
        if (quorum_ > sum) {
            revert ActionImpossible();
        }
        salt = keccak256(abi.encode(members, influence_, quorum_));
        location = Clones.predictDeterministicAddress(address(MOB), salt, address(MOB));
    }

    function make(address[] memory members, uint256[] memory influence_, uint256 quorum_) public returns (Mob mob) {
        if (this != MOB) {
            mob = MOB.make(members, influence_, quorum_);
        } else {
            (address location, bytes32 salt) = made(members, influence_, quorum_);
            mob = Mob(payable(location));
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(MOB), salt);
                mob.__initialize(members, influence_, quorum_);
                emit Make(mob, members, influence_, quorum_);
            }
        }
    }

    function __initialize(address[] memory members, uint256[] memory influence_, uint256 quorum_) external {
        if (quorum != 0) {
            revert AlreadyInitialized();
        }
        for (uint256 i = 0; i < members.length; i++) {
            influence[members[i]] = influence_[i];
        }
        quorum = quorum_;
    }

    receive() external payable {}

    fallback() external payable {
        uint256 w = influence[msg.sender];
        if (w == 0) revert NotMember();

        bytes calldata action = msg.data;
        if (action.length < 20 + 32) revert BadMessage();

        bytes32 h = keccak256(action);

        if (acted[h]) revert ActedAlready(h);
        uint256 total = tally[h];
        if (!voted[h][msg.sender]) {
            voted[h][msg.sender] = true;
            total += w;
            tally[h] = total;
        }

        if (total >= quorum) {
            act(h, action);
        }
    }

    function act(bytes32 h, bytes calldata action) private {
        acted[h] = true;
        address to;
        uint256 value;

        // to @ [0..20), value @ [20..52)
        assembly {
            to := shr(96, calldataload(action.offset))
            value := calldataload(add(action.offset, 20))
        }

        bytes calldata data = action[20 + 32:];
        (bool ok,) = to.call{value: value}(data);
        if (!ok) revert CallFailed(h);
    }
}
