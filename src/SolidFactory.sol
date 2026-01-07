// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Solid} from "./Solid.sol";

/**
 * @notice Factory for batch creation of Solid tokens
 */
contract SolidFactory {
    Solid public immutable SOLID;

    struct SolidSpec {
        string name;
        string symbol;
    }

    event BatchCreate(uint256 created, uint256 skipped, uint256 total);

    constructor(Solid solid) {
        SOLID = solid;
    }

    /**
     * @notice Create multiple Solids in a single transaction
     * @dev Refunds excess ETH to msg.sender
     * @param solids Array of solids to create
     * @return created Number of new Solids created
     * @return skipped Number of Solids skipped (already existed)
     */
    function batchMake(SolidSpec[] calldata solids) external payable returns (uint256 created, uint256 skipped) {
        uint256 spent = 0;

        for (uint256 i = 0; i < solids.length; i++) {
            SolidSpec calldata solid = solids[i];

            // Check if already exists
            (bool yes,,) = SOLID.made(solid.name, solid.symbol);

            if (yes) {
                skipped++;
            } else {
                // Create the solid
                SOLID.make{value: 0.001 ether}(solid.name, solid.symbol);
                spent += 0.001 ether;
                created++;
            }
        }

        emit BatchCreate(created, skipped, solids.length);

        // Refund excess ETH
        uint256 excess = msg.value - spent;
        if (excess > 0) {
            (bool ok,) = msg.sender.call{value: excess}("");
            require(ok, "Refund failed");
        }
    }
}
