// SPDX-License-Identifier: MIT

pragma solidity ^0.8.30;

import {Test, console} from "forge-std/Test.sol";

contract BaseTest is Test {
    uint256 public constant CHAIN = 31337; // Foundry/Hardhat/Anvil local test network

    function setUp() public virtual {
        console.log("Running tests on chain ID:", block.chainid);
    }
}
