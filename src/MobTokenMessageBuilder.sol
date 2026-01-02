// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

interface IERC20 {
    function transfer(address to, uint256 amount) external returns (bool);
}

contract MobTokenMessageBuilder {
    error ZeroMob();
    error ZeroToken();
    error ZeroRecipient();

    /// @notice Build the exact msg.data bytes to send to Mob (CALL-only format):
    ///         [20 bytes to][32 bytes value][calldata...]
    ///         where `to` is the ERC-20 token address, `value` is 0, and calldata is token.transfer(recipient, amount).
    function tokenTransferMessage(address token, address recipient, uint256 amount)
        external
        pure
        returns (bytes memory)
    {
        if (token == address(0)) revert ZeroToken();
        if (recipient == address(0)) revert ZeroRecipient();

        bytes memory callData = abi.encodeWithSelector(IERC20.transfer.selector, recipient, amount);

        // Mob message format: to (20) || value (32) || calldata (N)
        return abi.encodePacked(token, uint256(0), callData);
    }
}
