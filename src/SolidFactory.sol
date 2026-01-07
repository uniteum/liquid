// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Solid} from "./Solid.sol";

/**
 * @notice Factory for batch creation of Solid tokens
 */
contract SolidFactory {
    Solid public immutable SOLID;

    struct Element {
        string name;
        string symbol;
    }

    event BatchCreate(uint256 created, uint256 skipped, uint256 total);

    constructor(Solid solid) {
        SOLID = solid;
    }

    /**
     * @notice Create multiple Solids in a single transaction
     * @param elements Array of elements to create
     * @return created Number of new Solids created
     * @return skipped Number of Solids skipped (already existed)
     */
    function batchMake(Element[] calldata elements) external payable returns (uint256 created, uint256 skipped) {
        for (uint256 i = 0; i < elements.length; i++) {
            Element calldata element = elements[i];

            // Check if already exists
            (bool yes,,) = SOLID.made(element.name, element.symbol);

            if (yes) {
                skipped++;
            } else {
                // Create the solid
                SOLID.make{value: 0.001 ether}(element.name, element.symbol);
                created++;
            }
        }

        emit BatchCreate(created, skipped, elements.length);
    }
}
