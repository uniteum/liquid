// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

contract Random {
    uint256 seed;

    constructor() {
        seed = uint256(keccak256(abi.encode(this)));
    }

    function rnd(int256 min, int256 max) internal returns (int256 r) {
        seed = uint256(keccak256(abi.encode(seed)));
        // forge-lint: disable-next-line(unsafe-typecast)
        r = min + int256(seed % uint256(max - min));
    }
}
