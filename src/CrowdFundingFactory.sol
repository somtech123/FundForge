// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import "./Campaign.sol";
import "./UnitConverter.sol";
import {CrowdFundingFactoryLibary} from "./libary/CrowdFundingLiary.sol";

/**
 * @title Crowdfunding Campaign Factory
 * @author Oscar Onyenacho
 * @notice  A factory contract for deploying and managing crowdfunding campaigns.
 * @dev Campaigns are deployed as individual `Campaign` contracts. A creation fee is required.
        Deadlines are expressed in days and must be between 1 and 365 days.
 */

contract CrowdFundingFactory {
    /// @notice Thrown when the campaign goal is below the minimum allowed ETH amount.
    error CrowdFundingFactory__LessThanMinimumGoal();

    /// @notice Thrown when the provided goal is zero or otherwise invalid.
    error CrowdFundingFactory__InvalidGoal();

    /// @notice Thrown when the provided deadline resolves to zero duration.
    error CrowdFundingFactory__InvalidDeadLine();

    /// @notice Thrown when the deadline exceeds the maximum allowed duration (365 days).
    error CrowdFundingFactory__DeadLineToFar();

    /// @notice Thrown when the deadline is too close to the current time (≤ 1 day).
    error CrowdFundingFactory__DeadLineTooClose();

    /// @notice Thrown when the ETH sent is less than the required creation fee.
    error CrowdFundingFactory__InsufficientFee();

    //=======================================================
    //        Events
    //=======================================================

    /// @notice Emitted when a new campaign is successfully created.
    /// @param creator The address of the campaign creator.
    /// @param feesPaid The amount of ETH (in wei) paid as the creation fee.
    /// @param campaignId The ID assigned to the newly created campaign.

    event CampaignCreated(
        address indexed creator,
        uint256 feesPaid,
        uint256 campaignId
    );

    //=======================================================
    //        State Variables
    //=======================================================

    uint256 private s_campaignCounter;
    uint256 private s_minimumEth = 2;
    uint256 private constant CREATION_FEE = 1000000000000000;

    mapping(uint256 => CrowdFundingFactoryLibary.CampaignInfo)
        private s_campaignInfo;

    mapping(address => CrowdFundingFactoryLibary.CampaignInfo)
        private s_campaign;

    mapping(address => bool) private s_isCampaign;

    mapping(address => address) private s_campaignFactory;

    //=======================================================
    //        External Functions
    //=======================================================

    /// @notice Creates and deploys a new crowdfunding campaign.
    /// @dev The goal is converted from ETH to wei internally. Excess fee is refunded to the caller.
    ///      The campaign deadline is calculated as `block.timestamp + (_deadline * 1 days)`.
    /// @param _goal The fundraising target in ETH (not wei). Must be at least `s_minimumEth`.
    /// @param _deadine The campaign duration in days. Must be greater than 1 and less than 365.
    /// @return The address of the newly deployed `Campaign` contract.

    function createCampaign(
        uint256 _goal,
        uint256 _deadine
    ) external payable returns (address) {
        address sender = msg.sender;
        uint256 value = msg.value;

        uint256 campaignCounter = s_campaignCounter;
        uint256 minEth = UnitConverter.toWei(s_minimumEth);
        uint256 goal = UnitConverter.toWei(_goal);

        if (goal == 0) revert CrowdFundingFactory__InvalidGoal();

        if (goal < minEth) revert CrowdFundingFactory__LessThanMinimumGoal();

        uint256 durationInDays = _deadine * 1 days;

        if (durationInDays == 0) revert CrowdFundingFactory__InvalidDeadLine();

        if (durationInDays <= 1 days)
            revert CrowdFundingFactory__DeadLineTooClose();

        if (durationInDays >= 365 days)
            revert CrowdFundingFactory__DeadLineToFar();

        if (value < CREATION_FEE) revert CrowdFundingFactory__InsufficientFee();

        Campaign _campaign = new Campaign(
            sender,
            address(this),
            goal,
            block.timestamp + durationInDays
        );

        address campaignAddr = address(_campaign);

        s_campaignInfo[campaignCounter] = CrowdFundingFactoryLibary
            .CampaignInfo({
                campaignAddress: campaignAddr,
                creator: sender,
                createdAt: block.timestamp,
                goal: goal,
                active: true,
                deadline: block.timestamp + durationInDays
            });

        s_campaign[campaignAddr] = CrowdFundingFactoryLibary.CampaignInfo({
            campaignAddress: campaignAddr,
            creator: sender,
            createdAt: block.timestamp,
            goal: goal,
            active: true,
            deadline: block.timestamp + durationInDays
        });

        s_isCampaign[address(_campaign)] = true;
        s_campaignFactory[campaignAddr] = address(this);

        unchecked {
            ++campaignCounter;
        }

        s_campaignCounter = campaignCounter;

        emit CampaignCreated(sender, value, campaignCounter);

        // Refund any ETH sent above the required creation fee
        if (value > CREATION_FEE) {
            unchecked {
                uint256 refund = value - CREATION_FEE;
                (bool sucess, ) = payable(sender).call{value: refund}("");
                require(sucess, "Refund Failed");
            }
        }

        return address(_campaign);
    }

    //=======================================================
    //        View functions
    //=======================================================

    /// @notice Returns the full campaign info struct for a given campaign ID.
    /// @param _campaignId The numeric ID of the campaign.
    /// @return A `CampaignInfo` struct containing metadata about the campaign.

    function getCampaignInfo(
        uint256 _campaignId
    ) external view returns (CrowdFundingFactoryLibary.CampaignInfo memory) {
        return s_campaignInfo[_campaignId];
    }

    /// @notice Returns the total number of campaigns created.
    /// @return The current campaign counter value.

    function getCampaignCount() external view returns (uint256) {
        return s_campaignCounter;
    }

    /// @notice Returns the contract address of a campaign by its ID.
    /// @param _id The numeric ID of the campaign.
    /// @return The address of the corresponding campaign contract.

    function getCampaign(uint256 _id) external view returns (address) {
        return s_campaignInfo[_id].campaignAddress;
    }

    /// @notice Checks whether a given address is a campaign deployed by this factory.
    /// @param _campaign The address to check.
    /// @return True if the address is a valid campaign, false otherwise.

    function isValidCampaign(address _campaign) external view returns (bool) {
        return s_isCampaign[_campaign];
    }

    /// @notice Returns the campaign info struct for a given campaign address.
    /// @param _campaign The address of the campaign contract.
    /// @return A `CampaignInfo` struct containing metadata about the campaign

    function getCampaignByAddress(
        address _campaign
    ) external view returns (CrowdFundingFactoryLibary.CampaignInfo memory) {
        return s_campaign[_campaign];
    }

    /// @notice Returns the factory address that deployed a given campaign.
    /// @param _campaign The address of the campaign contract.
    /// @return The address of the factory that created the campaign.

    function getFactoryOf(address _campaign) external view returns (address) {
        return s_campaignFactory[_campaign];
    }
}
