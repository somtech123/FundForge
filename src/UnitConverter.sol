

// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library UnitConverter{

    function toWei(uint256 amount) internal pure returns(uint256){
        return amount * 1e18;
    }
}