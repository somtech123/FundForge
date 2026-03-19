// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract Campaign is Ownable{
    uint256 goal;
    uint256 deadline;
    address creator;
    address public immutable i_factory;

    constructor(address _creator, uint256 _goal, uint256 _deadine) Ownable(_creator)
    {
        goal = _goal;
        deadline = _deadine;
        i_factory = msg.sender;
    }

    function addMilestone() external view onlyOwner returns (address) {
        return i_factory;
    }

    function getFactory() public view returns (address) {
        return i_factory;
    }

    
}