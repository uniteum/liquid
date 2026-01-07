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

    event MadeBatch(uint256 created, uint256 skipped, uint256 total);

    constructor(Solid solid) {
        SOLID = solid;
    }

    /**
     * @notice Check which solids exist and which don't
     * @param solids Array of solids to check
     * @return existing Array of SolidSpecs that already exist
     * @return notExisting Array of SolidSpecs that don't exist yet
     */
    function made(SolidSpec[] calldata solids)
        public
        view
        returns (SolidSpec[] memory existing, SolidSpec[] memory notExisting)
    {
        uint256 existingCount = 0;
        uint256 notExistingCount = 0;

        // First pass: count
        for (uint256 i = 0; i < solids.length; i++) {
            (bool yes,,) = SOLID.made(solids[i].name, solids[i].symbol);
            if (yes) {
                existingCount++;
            } else {
                notExistingCount++;
            }
        }

        // Allocate arrays
        existing = new SolidSpec[](existingCount);
        notExisting = new SolidSpec[](notExistingCount);

        // Second pass: populate
        uint256 existingIndex = 0;
        uint256 notExistingIndex = 0;
        for (uint256 i = 0; i < solids.length; i++) {
            (bool yes,,) = SOLID.made(solids[i].name, solids[i].symbol);
            if (yes) {
                existing[existingIndex++] = solids[i];
            } else {
                notExisting[notExistingIndex++] = solids[i];
            }
        }
    }

    /**
     * @notice Create multiple Solids in a single transaction
     * @dev Refunds excess ETH to msg.sender
     * @param solids Array of solids to create
     * @return existing Array of SolidSpecs that already existed
     * @return created Array of SolidSpecs that were created
     */
    function make(SolidSpec[] calldata solids)
        external
        payable
        returns (SolidSpec[] memory existing, SolidSpec[] memory created)
    {
        // Get arrays of existing and non-existing solids
        (existing, created) = made(solids);

        // Get the maker payment amount from the Solid contract
        uint256 makerPayment = SOLID.MAKER_FEE();

        // Create the non-existing ones
        for (uint256 i = 0; i < created.length; i++) {
            SOLID.make{value: makerPayment}(created[i].name, created[i].symbol);
        }

        emit MadeBatch(created.length, existing.length, solids.length);

        // Refund excess ETH
        uint256 spent = created.length * makerPayment;
        uint256 excess = msg.value - spent;
        if (excess > 0) {
            (bool ok,) = msg.sender.call{value: excess}("");
            require(ok, "Refund failed");
        }
    }
}
