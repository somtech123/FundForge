// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;


interface IFactory {
    function isCampaign(address) external view returns (bool);
    
}