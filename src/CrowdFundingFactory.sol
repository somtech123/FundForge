// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "./Campaign.sol";
import "./UnitConverter.sol";
// import "./error.sol";

contract CrowdFundingFactory is Ownable {
    struct CampaignInfo {
        address campaignAddress;
        address creator;
        uint256 goal;
        uint256 createdAt;
    }

    uint256 private s_campaignCounter;

    uint256 private constant MINIMUM_USD = 1e16;
    uint256 private constant CREATION_FEE = 0.010 ether;

    address[] private s_campaigns;

    mapping(uint256 => CampaignInfo) private campaignInfo;
    mapping(address => bool) internal isCampaign;

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

    constructor() Ownable(msg.sender) {}

    function createCampaign(uint256 _goal, uint256 _deadine) external payable {
        uint256 durationInDays = _deadine * 1 days;

        uint256 campaignCounter = s_campaignCounter;

        if (_goal == 0) revert CrowdFundingFactory__InvalidGoal();

        if (_goal < MINIMUM_USD)
            revert CrowdFundingFactory__LessThanMinimumGoal();

        if (durationInDays == 0) revert CrowdFundingFactory__InvalidDeadLine();

        if (durationInDays <= 1 days)
            revert CrowdFundingFactory__DeadLineTooClose();

        if (durationInDays >= 365 days)
            revert CrowdFundingFactory__DeadLineToFar();

        if (msg.value <= CREATION_FEE)
            revert CrowdFundingFactory__InsufficientFee();

        uint256 goal = UnitConverter.toWei(_goal);

        Campaign _campaign = new Campaign(
            msg.sender,
            goal,
            block.timestamp + durationInDays
        );

        s_campaigns.push(address(_campaign));

        campaignInfo[campaignCounter] = CampaignInfo({
            campaignAddress: address(_campaign),
            creator: msg.sender,
            goal: goal,
            createdAt: block.timestamp
        });

        isCampaign[address(_campaign)] = true;

        campaignCounter++;

        emit CampaignCreated(msg.sender, msg.value, campaignCounter);

        // refund excess creation fee
        if (msg.value > CREATION_FEE) {
            uint256 refund = msg.value - CREATION_FEE;

            (bool sucess, ) = payable(msg.sender).call{value: refund}("");

            require(sucess, "Refund Failed");
        }
    }

    // View functions

    function getCampaignInfo(
        uint256 _campaignId
    ) external view returns (CampaignInfo memory) {
        return campaignInfo[_campaignId];
    }

    function getAllCampaigns() external view returns (address[] memory) {
        return s_campaigns;
    }

    // function isValidCampaign(address _campaign) external view returns (bool) {
    //     return isCampaign[_campaign];
    // }

    // function verifyCampaign(address _campaign) external view returns (bool) {
    //     if (!isCampaign[_campaign]) return false;

    //     Campaign campaign = Campaign(_campaign);

    //     return campaign.getFactory() == address(this);
    // }

    // function setCreationFee(uint256 _amount) external onlyOwner{
    //     if(_amount == 0) revert InsufficientFee();

    //     uint256 amoutInwei = UnitConverter.toWei(_amount);

    //     creation_fee = amoutInwei;
    // }
}
