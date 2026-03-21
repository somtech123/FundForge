// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

// import {ICampaign} from "./interfaces/ICampaign.sol";
// import "./Campaign.sol";

// contract CampaignFactory {
//     address public immutable i_factory;

//     event MilestoneAdded(
//         address indexed campaign,
//         string description,
//         uint256 amount
//     );

//     error CampaignFactory__InValidCampaign();
//     error CampaignFactory__NotCreator();
//     error CampaignFactory__ZeroAmount();

//     modifier onlyValidCampaign(address campaignAddress) {
//         if (!ICampaign(i_factory).isCampaign(campaignAddress)) {
//             revert CampaignFactory__InValidCampaign();
//         }
//         _;
//     }

//     modifier onlyCreator(address campaignAddress) {
//         if (msg.sender != Campaign(campaignAddress).owner()) {
//             revert CampaignFactory__NotCreator();
//         }

//         _;
//     }

//     constructor(address _factory) {
//         i_factory = _factory;
//     }

//     function addMilestones(
//         address _campaignAddress,
//         string calldata _description,
//         uint256 _amount
//     )
//         external
//         onlyValidCampaign(_campaignAddress)
//         onlyCreator(_campaignAddress)
//     {
//         if (_amount == 0) revert CampaignFactory__ZeroAmount();

//         // Campaign(_campaignAddress).addMilestone(_description, _amount);
//         emit MilestoneAdded(_campaignAddress, _description, _amount);
//     }
// }
