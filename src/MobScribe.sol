// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract MobScribe {
    error ZeroToken();
    error ZeroRecipient();

    /**
     * @notice Build the exact msg.data bytes to send to Mob using standard ABI encoding.
     * @dev Message format: abi.encode(token, value, calldata)
     *      where `token` is the ERC-20 address, `value` is 0, and calldata is token.transfer(to, amount).
     */
    function transfer(address token, address to, uint256 amount, uint256 nonce) external pure returns (bytes memory) {
        if (token == address(0)) revert ZeroToken();
        if (to == address(0)) revert ZeroRecipient();

        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector, to, amount);

        // Mob message format: abi.encode(to, value, data)
        return abi.encode(token, uint256(0), nonce, callData);
    }
}
