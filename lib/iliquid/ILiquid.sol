// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.30;

import {IERC20Metadata} from "ierc20/IERC20Metadata.sol";

interface ILiquid is IERC20Metadata {
    function solid() external view returns (IERC20Metadata);

    function pool() external view returns (uint256 S, uint256 E);

    function mass() external view returns (uint256);

    function heats(uint256 s) external view returns (uint256 u, uint256 p);

    function heat(uint256 s) external returns (uint256 u, uint256 p);

    function heats(uint256 s, uint256 e) external view returns (uint256 u, uint256 p);

    function heat(uint256 s, uint256 e) external returns (uint256 u, uint256 p);

    function cools(uint256 u) external view returns (uint256 s, uint256 p);

    function cool(uint256 u) external returns (uint256 s, uint256 p);

    function cools(uint256 u, uint256 e) external view returns (uint256 s, uint256 p);

    function cool(uint256 u, uint256 e) external returns (uint256 s, uint256 p);

    function sells(uint256 s) external view returns (uint256 e);

    function sell(uint256 s) external returns (uint256 hubs);

    function sellsFor(ILiquid that, uint256 s) external view returns (uint256 e, uint256 thats);

    function sellFor(ILiquid that, uint256 s) external returns (uint256 e, uint256 thats);

    function buys(uint256 e) external view returns (uint256 s);

    function buy(uint256 e) external returns (uint256 s);

    function made(IERC20Metadata backing) external view returns (bool cloned, address home, bytes32 salt);

    function make(IERC20Metadata backing) external returns (ILiquid liquid);

    event Heat(ILiquid indexed liquid, uint256 solids, uint256 pools, uint256 senders);
    event Cool(ILiquid indexed liquid, uint256 liquids, uint256 hubs, uint256 solids);
    event Buy(ILiquid indexed liquid, uint256 liquids, uint256 hubs);
    event Sell(ILiquid indexed liquid, uint256 liquids, uint256 hubs);
    event Make(ILiquid indexed liquid, IERC20Metadata indexed solid);

    error HubNotPool();
    error Nothing();
    error Unauthorized();
}
