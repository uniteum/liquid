// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract Mob {
    error MobClosed();
    error NoSway();
    error LengthMismatch();
    error ActionImpossible();
    error NoQuorum();
    error NoVoters();
    error ActDone(bytes32 h);
    error ActFailed(bytes32 h);

    event Make(Mob mob, address[] voters, uint256[] sway_, uint256 quorum);

    Mob public immutable MOB = this;

    mapping(address => uint256) public sway;
    uint256 public quorum;

    mapping(bytes32 => uint256) public tally;
    mapping(bytes32 => mapping(address => bool)) public voted;
    mapping(bytes32 => bool) public acted;

    function made(address[] memory voters, uint256[] memory sway_, uint256 quorum_)
        public
        view
        returns (address location, bytes32 salt)
    {
        if (quorum_ == 0) {
            revert NoQuorum();
        }
        if (voters.length == 0) {
            revert NoVoters();
        }
        if (voters.length != sway_.length) {
            revert LengthMismatch();
        }
        uint256 sum;
        for (uint256 i = 0; i < voters.length; i++) {
            sum += sway_[i];
        }
        if (quorum_ > sum) {
            revert ActionImpossible();
        }
        salt = keccak256(abi.encode(voters, sway_, quorum_));
        location = Clones.predictDeterministicAddress(address(MOB), salt, address(MOB));
    }

    function make(address[] memory voters, uint256[] memory sway_, uint256 quorum_) public returns (Mob mob) {
        if (this != MOB) {
            mob = MOB.make(voters, sway_, quorum_);
        } else {
            (address location, bytes32 salt) = made(voters, sway_, quorum_);
            mob = Mob(payable(location));
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(MOB), salt);
                mob.__initialize(voters, sway_, quorum_);
                emit Make(mob, voters, sway_, quorum_);
            }
        }
    }

    function __initialize(address[] memory voters, uint256[] memory sway_, uint256 quorum_) external {
        if (quorum != 0) {
            revert MobClosed();
        }
        quorum = quorum_;
        for (uint256 i = 0; i < voters.length; i++) {
            sway[voters[i]] = sway_[i];
        }
    }

    receive() external payable {}

    fallback() external payable {
        uint256 sway_ = sway[msg.sender];
        if (sway_ == 0) revert NoSway();

        bytes calldata action = msg.data;
        // Decode standard ABI-encoded message: (address to, uint256 value, uint256 nonce, bytes data)
        (address to, uint256 value,, bytes memory data) = abi.decode(action, (address, uint256, uint256, bytes));

        bytes32 h = keccak256(action);

        if (acted[h]) revert ActDone(h);
        uint256 tally_ = tally[h];
        if (!voted[h][msg.sender]) {
            voted[h][msg.sender] = true;
            tally_ += sway_;
            tally[h] = tally_;
        }

        if (tally_ >= quorum) {
            acted[h] = true;
            (bool ok,) = to.call{value: value}(data);
            if (!ok) revert ActFailed(h);
        }
    }
}
