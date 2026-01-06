// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {ERC20} from "erc20/ERC20.sol";
import {ReentrancyGuardTransient} from "reentrancy/ReentrancyGuardTransient.sol";

contract WrappedNative is ERC20, ReentrancyGuardTransient {
    error WithdrawFailed();

    event Deposit(address indexed from, uint256 value);
    event Withdraw(address indexed to, uint256 value);

    constructor() ERC20("Wrapped Native", "WNATIVE") {}

    function deposit() public payable {
        uint256 value = msg.value;
        _mint(msg.sender, value);
        emit Deposit(msg.sender, value);
    }

    function withdraw(uint256 value) external nonReentrant {
        _burn(msg.sender, value);

        emit Withdraw(msg.sender, value);

        (bool ok, bytes memory returnData) = msg.sender.call{value: value}("");
        if (!ok) {
            if (returnData.length > 0) {
                assembly {
                    revert(add(returnData, 32), mload(returnData))
                }
            } else {
                revert WithdrawFailed();
            }
        }
    }

    receive() external payable {
        deposit();
    }
}
