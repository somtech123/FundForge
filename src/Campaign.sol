// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "./error.sol";
import {CrowdFundingFactory} from "./CrowdFundingFactory.sol";
import "./UnitConverter.sol";

contract Campaign is Ownable {
    struct Milestone {
        string description;
        uint256 amount;
        bool completed;
        bool paid;
    }

    struct CampaignState{
        uint256 totalFunded;
        bool withdraw;
        mapping (address => uint256) contributors;
    }

    address public immutable I_FACTORY;
    address creator;
    uint256 goal;
    uint256 deadline;
    uint256 public totalMilestoneTarget;
    // uint256 totalFunded;
    bool private s_funded;

    Milestone[] public milestones;

    mapping(bytes32 => bool) public milestoneExists;
    mapping(address => CampaignState) private s_campaignState;

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
    error Campaign__ZeroAmount();
    error Campaign__MilestoneTargetNotEqualCampaignGoal();
    error Campaign__CampaignDeadlinePassed();
    error Campaign__CampaignGoalReached();

    event MilestoneAdded(
        address indexed campaignAddress,
        string description,
        uint256 targetAmount
    );

    event CampaignFunded(address indexed sender, uint256 amount);

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

    //==========================================
    //    Milestone
    //============================================

    //====================Add Milestone=================================

    function addMilestone(
        string calldata _description,
        uint256 _goal
    ) external onlyCreator onlyValidCampaign {
         uint256 _targetAmount = UnitConverter.toWei(_goal);

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

    //==========================================
    //    Funding
    //============================================

    //=====================Fund Campaign====================

    function fundCampaign() external payable onlyValidCampaign{
        uint256 _sentValue =  msg.value; 
        //  UnitConverter.toWei(msg.value);

        if(_sentValue == 0) revert Campaign__ZeroAmount();

        if(totalMilestoneTarget != goal) revert Campaign__MilestoneTargetNotEqualCampaignGoal();

        if(s_funded)revert Campaign__CampaignGoalReached();

        uint256 _deadline = getCampaignInfo().deadline;
        if(block.timestamp >= _deadline) revert Campaign__CampaignDeadlinePassed();

        CampaignState storage state = s_campaignState[address(this)];
        uint256 totalFunded = state.totalFunded;

        uint256 target = goal - totalFunded;
        uint256 accepted;
        uint256 refund;
        
        // handle overfunding
        if(_sentValue > target){
            accepted = target;
            refund = _sentValue - target;
        }else {
            accepted = _sentValue;
        }

        uint256 newTotal = totalFunded + accepted;

        state.contributors[msg.sender] += accepted;
        state.totalFunded = newTotal;

        if(newTotal == goal){
            s_funded = true;
        }
        emit CampaignFunded(msg.sender, accepted);

        if(refund > 0){
            (bool success, ) = msg.sender.call{value: refund}('');
            require(success, "refunf failed");
        }    

    }
    function getStatus() public view returns (bool){
        return s_funded;
    }

    function getTotalFunded() public view returns(uint256){
        CampaignState storage state = s_campaignState[address(this)];
        uint256 amt = state.totalFunded;
        return amt;
    }

    function getContributors(address _address) public view returns(uint256){
        CampaignState storage state = s_campaignState[address(this)];
        uint256 fund = state.contributors[_address];
        return fund;

    }

    

    function getCampaignInfo() public view returns(CrowdFundingFactory.CampaignInfo memory){
        CrowdFundingFactory.CampaignInfo memory info = CrowdFundingFactory(
            I_FACTORY
        ).getCampaignByAddress(address(this));

        return info;

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

    // function isFunded() external view 
}
