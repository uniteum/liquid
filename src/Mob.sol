// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Clones} from "@openzeppelin/contracts/proxy/Clones.sol";

contract Mob {
    error NotMember();
    error AlreadyExecuted(bytes32 h);
    error BadMessage();
    error CallFailed(bytes32 h);
    error AlreadyInitialized();
    error LengthMismatch();
    error ThresholdNotMet();
    error ThresholdZero();
    error DuplicateMember();

    event Make(Mob mob, address[] members, uint256[] weights, uint256 threshold);

    Mob public immutable MOB = this;

    mapping(address => uint256) public weight;
    uint256 public threshold;

    mapping(bytes32 => uint256) public approvedWeight;
    mapping(bytes32 => mapping(address => bool)) public approvedBy;
    mapping(bytes32 => bool) public executed;

    function made(address[] memory members, uint256[] memory weights, uint256 _threshold)
        public
        view
        returns (address location, bytes32 salt)
    {
        if (_threshold == 0) {
            revert ThresholdZero();
        }
        if (members.length != weights.length) {
            revert LengthMismatch();
        }
        uint256 sum;
        for (uint256 i = 0; i < members.length; i++) {
            address m = members[i];
            uint256 w = weights[i];
            if (m == address(0) || w == 0) {
                revert NotMember();
            }
            if (weight[m] != 0) {
                revert DuplicateMember();
            }
            sum += w;
        }
        if (_threshold > sum) {
            revert ThresholdNotMet();
        }
        salt = keccak256(abi.encode(members, weights, _threshold));
        location = Clones.predictDeterministicAddress(address(MOB), salt, address(MOB));
    }

    function make(address[] memory members, uint256[] memory weights, uint256 _threshold) public returns (Mob mob) {
        if (this != MOB) {
            mob = MOB.make(members, weights, _threshold);
        } else {
            (address location, bytes32 salt) = made(members, weights, _threshold);
            mob = Mob(payable(location));
            if (location.code.length == 0) {
                location = Clones.cloneDeterministic(address(MOB), salt);
                mob.__initialize(members, weights, _threshold);
                emit Make(mob, members, weights, _threshold);
            }
        }
    }

    function __initialize(address[] memory members, uint256[] memory weights, uint256 _threshold) external {
        if (threshold != 0) {
            revert AlreadyInitialized();
        }
        for (uint256 i = 0; i < members.length; i++) {
            weight[members[i]] = weights[i];
        }
        threshold = _threshold;
    }

    receive() external payable {}

    fallback() external payable {
        uint256 w = weight[msg.sender];
        if (w == 0) revert NotMember();

        bytes calldata m = msg.data;
        if (m.length < 20 + 32) revert BadMessage();

        bytes32 h = keccak256(m);

        if (executed[h]) revert AlreadyExecuted(h);
        uint256 total = approvedWeight[h];
        if (!approvedBy[h][msg.sender]) {
            approvedBy[h][msg.sender] = true;
            total += w;
            approvedWeight[h] = total;
        }

        if (total >= threshold) {
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
