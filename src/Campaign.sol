// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "./error.sol";
import {CrowdFundingFactory} from "./CrowdFundingFactory.sol";

contract Campaign is Ownable {
    struct Milestone {
        string description;
        uint256 amount;
        bool completed;
        bool paid;
    }
    address public immutable I_FACTORY;
    address creator;
    uint256 goal;
    uint256 deadline;
    uint256 public totalMilestoneTarget;
    uint256 totalFunded;

    Milestone[] public milestones;

    mapping(bytes32 => bool) public milestoneExists;

    error Campaign__NotOwner();
    error Campaign__NotCampaign();
    error Campaign__InValidCampaign();
    error Campaign__NotActiveCampaign();
    error Campaign__FactoryMismatch();
    error Campaign__ZeroAddress();
    error Campaign__InvalidMilestoneAmount();
    error Campaign__ZeroMilestoneTarget();
    error Campaign__InvalidMilestoneDescription();
    error Campaign__AlreadyFunded();
    error Campaign__DuplicateMilestone();
    error Campaign__MilestoneExceedGoal();

    event MilestoneAdded(
        address indexed campaignAddress,
        string description,
        uint256 targetAmount
    );

    //============================
    //       Modifiers
    //============================

    modifier onlyCreator() {
        if (msg.sender != owner()) revert Campaign__NotOwner();

        _;
    }

    modifier onlyValidCampaign() {
        address _campaignAddress = address(this);

        if (_campaignAddress == address(0)) revert Campaign__ZeroAddress();

        if (!CrowdFundingFactory(I_FACTORY).isValidCampaign(_campaignAddress))
            revert Campaign__InValidCampaign();

        CrowdFundingFactory.CampaignInfo memory info = CrowdFundingFactory(
            I_FACTORY
        ).getCampaignByAddress(_campaignAddress);
        if (!info.active) revert Campaign__NotActiveCampaign();

        // if (
        //     CrowdFundingFactory(I_FACTORY).getFactoryOf(_campaignAddress) !=
        //     I_FACTORY
        // ) revert Campaign__FactoryMismatch();

        _;
    }

    constructor(
        address _creator,
        address _factory,
        uint256 _goal,
        uint256 _deadine
    ) Ownable(_creator) {
        if (_factory == address(0)) revert Campaign__ZeroAddress();

        goal = _goal;
        deadline = _deadine;
        I_FACTORY = _factory;
    }

    function addMilestone(
        string calldata _description,
        uint256 _targetAmount
    ) external onlyCreator onlyValidCampaign {
        if (_targetAmount == 0) revert Campaign__ZeroMilestoneTarget();
        if (bytes(_description).length == 0)
            revert Campaign__InvalidMilestoneDescription();

        // if (totalFunded > 0) revert Campaign__AlreadyFunded();

        bytes32 mileStoneHash = keccak256(
            abi.encode(_description, _targetAmount)
        );
        if (milestoneExists[mileStoneHash])
            revert Campaign__DuplicateMilestone();
            

        if (totalMilestoneTarget + _targetAmount > goal) revert Campaign__MilestoneExceedGoal();

        milestoneExists[mileStoneHash] = true;
        totalMilestoneTarget += _targetAmount;

        milestones.push(
            Milestone({
                description: _description,
                amount: _targetAmount,
                completed: false,
                paid: false
            })
        );
        emit MilestoneAdded(msg.sender, _description, _targetAmount);
    }

    function getGoal() external view returns (uint256) {
        return goal;
    }

    function getDeadline() external view returns (uint256) {
        return deadline;
    }
    function getTotalMileStoneLength() external view returns (uint256){
        return milestones.length;
    }
}
