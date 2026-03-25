// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import "./error.sol";
import {CrowdFundingFactory} from "./CrowdFundingFactory.sol";

import {CrowdFundingFactoryLibary} from "./libary/CrowdFundingLiary.sol";
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
    address private s_creator;
    uint256 private  s_goal;
    uint256 private s_deadline;

    uint256 public totalMilestoneTarget;
    bool private s_funded;
    bool private s_locked;

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
    error Campaign__InvalidMilesToneIndex();
    error Campaign__AlreayCompleted();
    error Campaign__TotalMilesToneTargetNotMeet();
    error Campaign_AlreadyPaidMilestone();
    error Campaign_TransferFailed();
    error Campaign__CampaignStillActive();
    error Campaign__CampaignGoalMeet();
    error Campaign__ZeroContribution();

    event MilestoneAdded(
        address indexed campaignAddress,
        string description,
        uint256 targetAmount
    );

    event CampaignFunded(address indexed sender, uint256 amount);
    event SubmitMilestone(address indexed sender, bool status);
    event WithdrawMilestoneAmount(address indexed sender,  uint256 amount);
    event RefundContributors(address indexed sender,  uint256 amount);


    //============================
    //       Modifiers
    //============================

    modifier onlyCreator() {
        if (msg.sender != owner()) revert Campaign__NotOwner();
        _;
    }

    modifier nonReentrant(){
        require(!s_locked, 'Reentrant');
        s_locked = true;

        _;

        s_locked = false;
    }

    modifier onlyValidCampaign() {
        address _campaignAddress = address(this);

        if (_campaignAddress == address(0)) revert Campaign__ZeroAddress();

        if (!CrowdFundingFactory(I_FACTORY).isValidCampaign(_campaignAddress))
            revert Campaign__InValidCampaign();

        CrowdFundingFactoryLibary.CampaignInfo memory info = CrowdFundingFactory(
            I_FACTORY
        ).getCampaignByAddress(_campaignAddress);

        if (!info.active) revert Campaign__NotActiveCampaign();
        _;
    }

    constructor(
        address _creator,
        address _factory,
        uint256 _goal,
        uint256 _deadine
    ) Ownable(_creator) {
        if (_factory == address(0)) revert Campaign__ZeroAddress();

        s_goal = _goal;
        s_deadline = _deadine;
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
            

        if (totalMilestoneTarget + _targetAmount > s_goal) revert Campaign__MilestoneExceedGoal();

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

   


    function submitMilestone(uint256 index) public onlyCreator {
        if(index >= milestones.length) revert Campaign__InvalidMilesToneIndex();

        if(totalMilestoneTarget != s_goal) revert Campaign__TotalMilesToneTargetNotMeet();

        Milestone storage _milestone = milestones[index];
        if(_milestone.completed == true) revert Campaign__AlreayCompleted();

        _milestone.completed = true;

        emit SubmitMilestone(msg.sender, _milestone.completed);

    }

    //==========================================
    //    Funding
    //============================================

    //=====================Fund Campaign====================

    function fundCampaign() external payable onlyValidCampaign {

        uint256 _sentValue =  msg.value; 
        //  UnitConverter.toWei(msg.value);

        if(_sentValue == 0) revert Campaign__ZeroAmount();

        if(totalMilestoneTarget != s_goal) revert Campaign__MilestoneTargetNotEqualCampaignGoal();

        if(s_funded)revert Campaign__CampaignGoalReached();

        uint256 _deadline = getCampaignInfo().deadline;
        if(block.timestamp >= _deadline) revert Campaign__CampaignDeadlinePassed();

        CampaignState storage state = s_campaignState[address(this)];
        uint256 totalFunded = state.totalFunded;

        uint256 target = s_goal - totalFunded;
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

        if(newTotal == s_goal){
            s_funded = true;
        }
        emit CampaignFunded(msg.sender, accepted);

        if(refund > 0){
            (bool success, ) = msg.sender.call{value: refund}('');
            require(success, "refunf failed");
        }    

    }

    //==========================================
    //    Withdrawal
    //============================================

    function withdraw(uint256 index) public  onlyCreator nonReentrant{

        if(index >= milestones.length) revert Campaign__InvalidMilesToneIndex();

        Milestone storage _milestone = milestones[index];
        if(_milestone.completed == false) revert Campaign__AlreayCompleted();

        if(_milestone.paid == true) revert Campaign_AlreadyPaidMilestone();

        _milestone.paid  = true;

        emit WithdrawMilestoneAmount(msg.sender, _milestone.amount);

        (bool success, ) = payable(msg.sender).call{value: _milestone.amount}('');
        
        if(!success) revert Campaign_TransferFailed();
        
    }



    function refund() public external payable onlyValidCampaign nonReentrant {
        if(block.timestamp > s_deadline) revert Campaign__CampaignStillActive();

        if(totalMilestoneTarget >= s_goal) revert Campaign__CampaignGoalMeet();

        CampaignState storage _state = s_campaignState[address(this)];

        uint256 amountContributed = _state.contributors[msg.sender];

        if(amountContributed == 0) revert Campaign__ZeroContribution();

        _state.contributors[msg.sender] = 0;

        emit RefundContributors(msg.sender, amountContributed);

        (bool success, ) = payable(msg.sender).call{value: amountContributed}('');
        
        if(!success) revert Campaign_TransferFailed();  

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

    

    function getCampaignInfo() public view returns(CrowdFundingFactoryLibary.CampaignInfo memory){
        CrowdFundingFactoryLibary.CampaignInfo memory info = CrowdFundingFactory(
            I_FACTORY
        ).getCampaignByAddress(address(this));

        return info;

    }
    function getMilestone(uint256 index) public view returns(Milestone memory){
        return milestones[index];
    }


    function getGoal() external view returns (uint256) {
        return s_goal;
    }

    function getDeadline() external view returns (uint256) {
        return s_deadline;
    }
    function getTotalMileStoneLength() external view returns (uint256){
        return milestones.length;
    }

    // function isFunded() external view 
}
