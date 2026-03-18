// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import './Campaign.sol';
import './UnitConverter.sol';
import './error.sol';

contract CrowdFundingFactory{

    uint256 campaignCounter;
    uint256 constant public MINIMUM_USD = 1e16;
    uint256 constant public CREATION_FEE = 0.010 ether;


   event CampaignCreated(address indexed creator, uint256 feesPaid, uint256 campaignId);

    struct CampaignInfo{
        address campaignAddress;
        address creator;
        uint256 goal;
        uint256 createdAt;
    }
    mapping (uint256 => CampaignInfo) public campaigns;

   
    function createCampaign( uint256 _goal, uint256 _deadine) external payable   {
        uint256 durationInDays = _deadine * 1 days;
         
        if(_goal == 0 ) revert InvalidGoal();

        if(_goal < MINIMUM_USD) revert LessThanMinimumGoal();

        if(durationInDays == 0) revert InvalidDeadLine();

        if(durationInDays <=  1 days) revert DeadLineTooClose();

        if(durationInDays >=  365 days ) revert DeadLineToFar();

        if(msg.value <= CREATION_FEE) revert InsufficientFee();
        
        uint256 goal = UnitConverter.toWei(_goal);

        Campaign _campaign = new Campaign(
            msg.sender,
            goal,
            _deadine
        );

        campaigns[campaignCounter] = CampaignInfo({
            campaignAddress: address(_campaign),
            creator: msg.sender,
            goal: goal,
            createdAt: block.timestamp
        });

        campaignCounter++;

        emit CampaignCreated(msg.sender, msg.value, campaignCounter);
    
    }


}