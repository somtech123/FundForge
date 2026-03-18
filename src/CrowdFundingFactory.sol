// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import './Campaign.sol';
import './UnitConverter.sol';
import './error.sol';

contract CrowdFundingFactory{

    uint256 campaignCounter;
    uint256 constant public MINIMUM_USD = 1e16;
    uint256 constant public CREATION_FEE = 0.010 ether;
   

    struct CampaignInfo{
        address campaignAddress;
        address creator;
        uint256 goal;
    }
    mapping (uint256 => CampaignInfo) public campaign;
    mapping (address => uint256) public campaignCreated;

    function createCampaign( uint256 _goal, uint256 _deadine) external payable   {
        uint256 daysValue = _deadine * 1 days;
         
        if(_goal == 0 ) revert InvalidGoal();
        if(_goal < MINIMUM_USD) revert LessThanMinimumGoal();
        if(daysValue == 0) revert InvalidDeadLine();
        if(daysValue <=  1 days) revert DeadLineTooClose();
        if(daysValue >=  365 days ) revert DeadLineToFar();
        if(msg.value <= CREATION_FEE) revert InsufficientFee();
        
        uint256 goal = UnitConverter.toWei(_goal);

        Campaign _campaign = new Campaign(
            msg.sender,
            goal,
            _deadine
        );

        campaign[campaignCounter] = CampaignInfo({
            campaignAddress: address(_campaign),
            creator: msg.sender,
            goal: goal
        });

        campaignCounter++;
    
    }


}