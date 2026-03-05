// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IERC20Metadata} from "ierc20/IERC20Metadata.sol";

/// @title ILiquid — Hub-and-spoke AMM liquidity wrapper
/// @notice Wraps ERC-20 tokens with built-in constant-product AMM liquidity.
/// A single Hub instance wraps a backing token 1:1. Spoke instances created
/// via `make` each wrap a different ERC-20 and maintain a two-sided pool
/// (spoke tokens × hub tokens) for trading against the Hub.
interface ILiquid is IERC20Metadata {
    /// @notice The backing ERC-20 token this Liquid instance wraps.
    function solid() external view returns (IERC20Metadata);

    /// @notice Current pool reserves.
    /// @return S Spoke tokens held by the pool (this contract's own balance).
    /// @return E Hub tokens held by the pool (the "lake").
    function pool() external view returns (uint256 S, uint256 E);

    /// @notice Backing token balance held by this contract, redeemable via `cool`.
    function mass() external view returns (uint256);

    /// @notice Quote a heat: how many tokens the caller and pool would receive.
    /// @param m Amount of backing (solid) tokens to deposit (mass).
    /// @return u Liquid tokens the caller would receive.
    /// @return p Liquid tokens the pool would receive.
    function heats(uint256 m) external view returns (uint256 u, uint256 p);

    /// @notice Deposit backing tokens, mint liquid tokens. The 2× mint splits
    /// newly minted tokens between the caller and the pool, seeding AMM liquidity.
    /// @param m Amount of backing (solid) tokens to deposit (mass).
    /// @return u Liquid tokens minted to the caller.
    /// @return p Liquid tokens minted to the pool.
    function heat(uint256 m) external returns (uint256 u, uint256 p);

    /// @notice Quote a heat with an explicit hub-token deposit.
    /// @param m Amount of backing (solid) tokens to deposit (mass).
    /// @param e Amount of hub tokens to deposit into the pool's lake.
    /// @return u Liquid tokens the caller would receive.
    /// @return p Liquid tokens the pool would receive.
    function heats(uint256 m, uint256 e) external view returns (uint256 u, uint256 p);

    /// @notice Deposit backing tokens and hub tokens, mint liquid tokens.
    /// @param m Amount of backing (solid) tokens to deposit (mass).
    /// @param e Amount of hub tokens to deposit into the pool's lake.
    /// @return u Liquid tokens minted to the caller.
    /// @return p Liquid tokens minted to the pool.
    function heat(uint256 m, uint256 e) external returns (uint256 u, uint256 p);

    /// @notice Quote a cool: how many backing tokens and pool burns result.
    /// @param u Amount of liquid tokens to burn.
    /// @return m Backing (solid) tokens the caller would receive (mass).
    /// @return p Liquid tokens that would be burned from the pool.
    function cools(uint256 u) external view returns (uint256 m, uint256 p);

    /// @notice Burn liquid tokens and redeem proportional backing tokens.
    /// @param u Amount of liquid tokens to burn from the caller.
    /// @return m Backing (solid) tokens returned to the caller (mass).
    /// @return p Liquid tokens burned from the pool.
    function cool(uint256 u) external returns (uint256 m, uint256 p);

    /// @notice Quote a cool with an explicit hub-token withdrawal.
    /// @param u Amount of liquid tokens to burn.
    /// @param e Amount of hub tokens to withdraw from the pool's lake.
    /// @return m Backing (solid) tokens the caller would receive (mass).
    /// @return p Liquid tokens that would be burned from the pool.
    function cools(uint256 u, uint256 e) external view returns (uint256 m, uint256 p);

    /// @notice Burn liquid tokens and redeem backing tokens plus hub tokens.
    /// @param u Amount of liquid tokens to burn from the caller.
    /// @param e Amount of hub tokens to withdraw from the pool's lake.
    /// @return m Backing (solid) tokens returned to the caller (mass).
    /// @return p Liquid tokens burned from the pool.
    function cool(uint256 u, uint256 e) external returns (uint256 m, uint256 p);

    /// @notice Quote a sell: how many hub tokens would be received.
    /// @param s Amount of spoke tokens to sell into the pool.
    /// @return e Hub tokens that would be received.
    function sells(uint256 s) external view returns (uint256 e);

    /// @notice Sell spoke tokens for hub tokens via the constant-product AMM.
    /// @param s Amount of spoke tokens to sell.
    /// @return hubs Hub tokens received.
    function sell(uint256 s) external returns (uint256 hubs);

    /// @notice Quote a cross-spoke swap: sell this spoke's tokens for another's.
    /// @param that The target spoke to buy into.
    /// @param s Amount of this spoke's tokens to sell.
    /// @return e Hub tokens used as intermediary.
    /// @return thats Target spoke tokens that would be received.
    function sellsFor(ILiquid that, uint256 s) external view returns (uint256 e, uint256 thats);

    /// @notice Atomic cross-spoke swap: sell this spoke's tokens, buy another's,
    /// routing through the hub in a single transaction.
    /// @param that The target spoke to buy into.
    /// @param s Amount of this spoke's tokens to sell.
    /// @return e Hub tokens used as intermediary.
    /// @return thats Target spoke tokens received.
    function sellFor(ILiquid that, uint256 s) external returns (uint256 e, uint256 thats);

    /// @notice Quote a buy: how many spoke tokens would be received.
    /// @param e Amount of hub tokens to spend.
    /// @return s Spoke tokens that would be received.
    function buys(uint256 e) external view returns (uint256 s);

    /// @notice Buy spoke tokens with hub tokens via the constant-product AMM.
    /// @param e Amount of hub tokens to spend.
    /// @return s Spoke tokens received.
    function buy(uint256 e) external returns (uint256 s);

    /// @notice Check whether a spoke for the given backing token exists.
    /// @param backing The ERC-20 token to query.
    /// @return cloned True if the spoke has already been deployed.
    /// @return home The deterministic CREATE2 address (valid even before deployment).
    /// @return salt The CREATE2 salt derived from the backing token address.
    function made(IERC20Metadata backing) external view returns (bool cloned, address home, bytes32 salt);

    /// @notice Deploy a new spoke for the given backing token via deterministic CREATE2.
    /// @param backing The ERC-20 token the new spoke will wrap.
    /// @return liquid The newly created spoke instance.
    function make(IERC20Metadata backing) external returns (ILiquid liquid);

    /// @notice Emitted on `heat` — backing tokens deposited, liquid minted.
    event Heat(ILiquid indexed liquid, uint256 solids, uint256 pools, uint256 senders);
    /// @notice Emitted on `cool` — liquid burned, backing tokens redeemed.
    event Cool(ILiquid indexed liquid, uint256 liquids, uint256 hubs, uint256 solids);
    /// @notice Emitted on `buy` — hub tokens spent for spoke tokens.
    event Buy(ILiquid indexed liquid, uint256 liquids, uint256 hubs);
    /// @notice Emitted on `sell` — spoke tokens sold for hub tokens.
    event Sell(ILiquid indexed liquid, uint256 liquids, uint256 hubs);
    /// @notice Emitted on `make` — new spoke deployed.
    event Make(ILiquid indexed liquid, IERC20Metadata indexed solid);

    /// @notice The hub has no AMM pool; sell/buy operations are not available.
    error HubNotPool();
    /// @notice The operation resulted in zero output.
    error Nothing();
    /// @notice Caller is not authorized for this operation.
    error Unauthorized();
}
