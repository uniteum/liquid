// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {IERC20Metadata} from "ierc20/IERC20Metadata.sol";

/**
 * @notice Interface for Solid - a constant-product AMM for ETH/SOL pairs with deterministic deployment
 */
interface ISolid is IERC20Metadata {
    /**
     * @notice Returns the NOTHING instance (the base Solid used as factory)
     * @return The immutable NOTHING Solid instance
     */
    function NOTHING() external view returns (ISolid);

    /**
     * @notice Returns the minimum payment required to make a new Solid
     * @return The minimum ETH payment required (default 0.001 ether)
     */
    function MAKER_PAYMENT() external view returns (uint256);

    /**
     * @notice Returns the current pool balances of SOL tokens and ETH
     * @return solPool The amount of SOL tokens in the pool
     * @return ethPool The amount of ETH in the pool
     */
    function pool() external view returns (uint256 solPool, uint256 ethPool);

    /**
     * @notice Withdraws ETH from the pool by depositing SOL tokens
     * @dev Uses constant-product formula: eth = ethPool - ethPool * solPool / (solPool + sol)
     * Transfers SOL tokens from caller to pool, sends ETH to caller.
     * Protected by reentrancy guard.
     * @param sol The amount of SOL tokens to deposit into the pool
     * @return eth The amount of ETH withdrawn from the pool
     */
    function withdraw(uint256 sol) external returns (uint256 eth);

    /**
     * @notice Deposits ETH into the pool and receives SOL tokens
     * @dev Uses constant-product formula: sol = solPool - solPool * (ethPool - eth) / ethPool
     * Transfers SOL tokens from pool to caller. Does not mint new tokens.
     * @return sol The amount of SOL tokens received from the pool
     */
    function deposit() external payable returns (uint256 sol);

    /**
     * @notice Checks if a Solid exists and computes its deterministic address
     * @dev Uses CREATE2 with salt = keccak256(abi.encode(n, s)) for deterministic deployment
     * @param n The name of the Solid token
     * @param s The symbol of the Solid token
     * @return yes True if the Solid with given name and symbol already exists
     * @return home The predicted (or actual if exists) contract address
     * @return salt The CREATE2 salt used for deployment (keccak256(abi.encode(n, s)))
     */
    function made(string calldata n, string calldata s) external view returns (bool yes, address home, bytes32 salt);

    /**
     * @notice Makes a new Solid instance with the given name and symbol
     * @dev Requires minimum payment of MAKER_PAYMENT. Reverts if already made.
     * Mints 50% of SUPPLY to maker and 50% to pool. Initial ETH becomes pool liquidity.
     * Uses CREATE2 for deterministic deployment based on name and symbol.
     * @param n The name of the new Solid token
     * @param s The symbol of the new Solid token
     * @return sol The newly made Solid instance
     */
    function make(string calldata n, string calldata s) external payable returns (ISolid sol);

    /**
     * @notice Emitted when a new Solid is made
     * @param solid The address of the newly made Solid
     * @param name The name of the Solid token (indexed)
     * @param symbol The symbol of the Solid token (indexed)
     */
    event Make(ISolid indexed solid, string indexed name, string indexed symbol);

    /**
     * @notice Emitted when ETH is deposited into the pool for SOL tokens
     * @param solid The Solid instance where deposit occurred
     * @param eth The amount of ETH deposited
     * @param sol The amount of SOL tokens received from the pool
     */
    event Deposit(ISolid indexed solid, uint256 eth, uint256 sol);

    /**
     * @notice Emitted when SOL is deposited into the pool for ETH
     * @param solid The Solid instance where withdrawal occurred
     * @param sol The amount of SOL tokens deposited
     * @param eth The amount of ETH withdrawn
     */
    event Withdraw(ISolid indexed solid, uint256 sol, uint256 eth);

    /**
     * @notice Thrown when name or symbol is empty in made() or make()
     */
    error Nothing();

    /**
     * @notice Thrown when ETH transfer to withdrawer fails
     */
    error WithdrawFailed();

    /**
     * @notice Thrown when payment is less than MAKER_PAYMENT in make()
     */
    error PaymentLow();

    /**
     * @notice Thrown when attempting to make a Solid that has already been made
     */
    error MadeAlready();
}
