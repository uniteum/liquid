// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.30;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract Ice is ERC20 {
    string constant NAME = "Watar";
    string constant SYMBOL = "WATAR";
    uint256 constant SUPPLY = 1e9 ether;
    address constant ISSUER = 0xEbCaD83FeAD16e7D18DD691fFD2b39eca56677d8;

    constructor() ERC20(NAME, SYMBOL) {
        _mint(ISSUER, SUPPLY);
    }
}
