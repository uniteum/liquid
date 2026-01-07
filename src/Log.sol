// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Clones} from "clones/Clones.sol";

contract Log {
    Log public immutable PROTO = this;
    address public subject;
    address public observer;
    uint256 public variant;
    uint256[] blockNumber;
    mapping(uint256 => mapping(address => mapping(address => uint256[]))) fore;
    mapping(uint256 => mapping(address => mapping(address => uint256[]))) back;
    mapping(uint256 => mapping(address => address[])) zz;
    mapping(uint256 => address[]) zzq;

    function update(address f, address t, uint256 amount) external {
        if (blockNumber.length == 0 || blockNumber[blockNumber.length - 1] != block.number) {
            blockNumber.push(block.number);
        }
        fore[block.number][f][t].push(amount);
        back[block.number][t][f].push(amount);
        zz[block.number][t].push(f);
    }

    function made(address s, address o, uint256 v) public view returns (bool yes, address location, bytes32 salt) {
        if (s == address(0)) revert Null();
        if (o == address(0)) revert Null();
        salt = keccak256(abi.encode(s, o, v));
        location = Clones.predictDeterministicAddress(address(PROTO), salt, address(PROTO));
        yes = location.code.length > 0;
    }

    function make(address s, address o, uint256 v) external returns (Log log) {
        if (this != PROTO) {
            log = PROTO.make(s, o, v);
        } else {
            (bool yes, address location, bytes32 salt) = made(s, o, v);
            log = Log(location);
            if (!yes) {
                location = Clones.cloneDeterministic(address(PROTO), salt, 0);
                Log(location).zzz_(s, o, v);
                emit Make(s, o, v);
            }
        }
    }

    function zzz_(address s, address o, uint256 v) external {
        if (subject == address(0)) {
            subject = s;
            observer = o;
            variant = v;
        }
    }

    event Make(address indexed subject, address indexed observer, uint256 v);

    error Null();
}
