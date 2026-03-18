// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

contract Campaign{
    uint256 goal;
    uint256 deadline;
    address creator;


    constructor(address _creator, uint256 _goal, uint256 _deadine){
        creator = _creator;
        goal = _goal;
        deadline = _deadine;
    }

    
}