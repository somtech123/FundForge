// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

library CrowdFundingFactoryLibary {
    
        struct CampaignInfo {
        address campaignAddress;
        address creator;
        uint256 createdAt;
        uint256 goal;
        bool active;
        uint256 deadline;
    }
    
}