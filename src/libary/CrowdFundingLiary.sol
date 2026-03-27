// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/// @title CrowdFundingFactoryLibary
/// @author Oscar Onyenacho
/// @notice A crowdfundingFactory library that hows the struct to get campaign info.
/// @dev Imported and used with the create campaign function in crowdfunding.sol

library CrowdFundingFactoryLibary {
    /// @notice Tracks CampaignInfo per campaign address
    /// @dev Should be imported in  CrowdFundingFactory.sol and used in campaign creation
    struct CampaignInfo {
        address campaignAddress;
        address creator;
        uint256 createdAt;
        uint256 goal;
        bool active;
        uint256 deadline;
    }
}
