// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 * @title UnitConverter
 * @author Oscar Onyenacho
 * @notice A utility library for converting between ether to wei
 * @dev This Library is deployed to be used internally by contracts for prices unit conversions
 */
library UnitConverter {
    /**
     * @notice Converts eth to wei
     * @dev uses 1 ether = 1e18
     * @param amount amount the amount in ether
     * @return amountWei the equivalent in wei
     */
    function toWei(uint256 amount) internal pure returns (uint256) {
        return amount * 1e18;
    }
}
