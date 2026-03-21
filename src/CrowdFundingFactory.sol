// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
// import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "./Campaign.sol";
import "./UnitConverter.sol";
// import "./error.sol";

contract CrowdFundingFactory {
    struct CampaignInfo {
        address campaignAddress;
        address creator;
        uint256 createdAt;
        uint256 goal;
        bool active;
        uint256 deadline;
    }

    uint256 private s_campaignCounter;

    uint256 private constant MINIMUM_USD = 1e16;
    uint256 private constant CREATION_FEE = 0.010 ether;
    address[] private s_campaigns;

    mapping(uint256 => CampaignInfo) private s_campaignInfo;
    mapping(address => CampaignInfo) private s_campaign;
    mapping(address => bool) internal s_isCampaign;
    mapping(address => address) private s_campaignFactory;

    event CampaignCreated(
        address indexed creator,
        uint256 feesPaid,
        uint256 campaignId
    );

    error CrowdFundingFactory__LessThanMinimumGoal();
    error CrowdFundingFactory__InvalidGoal();
    error CrowdFundingFactory__InvalidDeadLine();
    error CrowdFundingFactory__DeadLineToFar();
    error CrowdFundingFactory__DeadLineTooClose();
    error CrowdFundingFactory__InsufficientFee();

    constructor() {}

    function createCampaign(
        uint256 _goal,
        uint256 _deadine
    ) external payable returns (address) {
        address sender = msg.sender;
        uint256 value = msg.value;

        uint256 campaignCounter = s_campaignCounter;

        if (_goal == 0) revert CrowdFundingFactory__InvalidGoal();

        if (_goal < MINIMUM_USD)
            revert CrowdFundingFactory__LessThanMinimumGoal();

        uint256 durationInDays = _deadine * 1 days;

        if (durationInDays == 0) revert CrowdFundingFactory__InvalidDeadLine();

        if (durationInDays <= 1 days)
            revert CrowdFundingFactory__DeadLineTooClose();

        if (durationInDays >= 365 days)
            revert CrowdFundingFactory__DeadLineToFar();

        if (value < CREATION_FEE) revert CrowdFundingFactory__InsufficientFee();

        uint256 goal = UnitConverter.toWei(_goal);

        Campaign _campaign = new Campaign(
            sender,
            address(this),
            goal,
            block.timestamp + durationInDays
        );

        address campaignAddr = address(_campaign);
        s_campaigns.push(address(_campaign));

        s_campaignInfo[campaignCounter] = CampaignInfo({
            campaignAddress: campaignAddr,
            creator: sender,
            createdAt: block.timestamp,
            goal: goal,
            active: true,
            deadline: block.timestamp + durationInDays
        });

        s_campaign[campaignAddr] = CampaignInfo({
            campaignAddress: campaignAddr,
            creator: sender,
            createdAt: block.timestamp,
            goal: goal,
            active: true,
            deadline: block.timestamp + durationInDays
        });

        // whitelist

        s_isCampaign[address(_campaign)] = true;
        s_campaignFactory[campaignAddr] = address(this);

        unchecked {
            ++campaignCounter;
        }

        s_campaignCounter = campaignCounter;

        emit CampaignCreated(sender, value, campaignCounter);

        // refund excess creation fee
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

    function getCampaignInfo(
        uint256 _campaignId
    ) external view returns (CampaignInfo memory) {
        return s_campaignInfo[_campaignId];
    }

    function getAllCampaigns() external view returns (address[] memory) {
        return s_campaigns;
    }

    function getCampaignCount() external view returns (uint256) {
        return s_campaignCounter;
    }

    function getCampaign(uint256 _id) external view returns (address) {
        return s_campaignInfo[_id].campaignAddress;
    }

    function isValidCampaign(address _campaign) external view returns (bool) {
        return s_isCampaign[_campaign];
    }

    function getCampaignByAddress(
        address _campaign
    ) external view returns (CampaignInfo memory) {
        return s_campaign[_campaign];
    }

    function getFactoryOf(address _campaign) external view returns (address) {
        return s_campaignFactory[_campaign];
    }
}
