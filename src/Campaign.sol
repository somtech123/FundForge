// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

import {CrowdFundingFactory} from "./CrowdFundingFactory.sol";

import {CrowdFundingFactoryLibary} from "./libary/CrowdFundingLiary.sol";
import "./UnitConverter.sol";

/// @title Campaign
/// @author Oscar Onyenacho
/// @notice A crowdfunding campaign contract that handles milestone-based funding withdrawals and refund
/// @dev Deployed by CrowdFundingFactory. All interactions are validated against the factory registry.
///      Uses a custom nonReentrant guard and milestone-based payment system.
contract Campaign is Ownable {
    // ═══════════════════════════════════════════════════════
    //   STRUCTS
    // ═══════════════════════════════════════════════════════

    /// @notice Represents a single milestone in the campaign
    /// @dev Milestones must be submitted before withdrawal is allowed
    struct Milestone {
        string description;
        uint256 amount;
        bool completed;
        bool paid;
    }

    /// @notice Tracks funding state per campaign address
    /// @dev Keyed by address(this) in s_campaignState mapping
    struct CampaignState {
        uint256 totalFunded;
        bool withdraw;
        mapping(address => uint256) contributors;
    }

    //=======================================================
    //        State Variables
    //=======================================================

    address public immutable I_FACTORY;
    address private s_creator;
    uint256 private s_goal;
    uint256 private s_deadline;

    uint256 public totalMilestoneTarget;
    bool private s_funded;
    bool private s_locked;

    Milestone[] public milestones;

    mapping(bytes32 => bool) public milestoneExists;
    mapping(address => CampaignState) private s_campaignState;

    //=======================================================
    //        Events
    //=======================================================

    /// @notice Emitted when a new milestone is added to the campaign
    /// @param campaignAddress Address of the campaign (indexed)
    /// @param description Description of the milestone
    /// @param targetAmount Target amount in wei for this milestone

    event MilestoneAdded(
        address indexed campaignAddress,
        string description,
        uint256 targetAmount
    );

    /// @notice Emitted when a contributor funds the campaign
    /// @param sender Address of the contributor (indexed)
    /// @param amount Amount accepted in wei (may differ from sent if overfunded)
    event CampaignFunded(address indexed sender, uint256 amount);

    /// @notice Emitted when a milestone is submitted as complete
    /// @param sender Address of the creator (indexed)
    /// @param status Completion status (always true when emitted)
    event SubmitMilestone(address indexed sender, bool status);

    // @notice Emitted when a milestone withdrawal is made
    /// @param sender Address of the creator receiving funds (indexed)
    /// @param amount Amount withdrawn in wei
    event WithdrawMilestoneAmount(address indexed sender, uint256 amount);

    /// @notice Emitted when a contributor claims a refund
    /// @param sender Address of the contributor receiving refund (indexed)
    /// @param amount Amount refunded in wei
    event RefundContributors(address indexed sender, uint256 amount);

    //═══════════════════════════════════════════════════════
    //   ERRORS
    // ═══════════════════════════════════════════════════════

    /// @notice Thrown when caller is not the campaign owner
    error Campaign__NotOwner();

    /// @notice Thrown when caller is not a valid campaign contract
    error Campaign__NotCampaign();

    /// @notice Thrown when campaign is not registered in factory
    error Campaign__InValidCampaign();

    /// @notice Thrown when campaign has been cancelled or is inactive
    error Campaign__NotActiveCampaign();

    /// @notice Thrown when factory address does not match stored factory
    error Campaign__FactoryMismatch();

    /// @notice Thrown when a zero address is provided
    error Campaign__ZeroAddress();

    /// @notice Thrown when milestone amount is invalid
    error Campaign__InvalidMilestoneAmount();

    /// @notice Thrown when milestone target amount is zero
    error Campaign__ZeroMilestoneTarget();

    /// @notice Thrown when milestone description is empty
    error Campaign__InvalidMilestoneDescription();

    /// @notice Thrown when campaign has already been funded
    error Campaign__AlreadyFunded();

    /// @notice Thrown when a duplicate milestone is detected
    /// @dev Duplicates detected via keccak256 hash of description + amount
    error Campaign__DuplicateMilestone();

    /// @notice Thrown when adding a milestone would exceed the campaign goal
    error Campaign__MilestoneExceedGoal();

    /// @notice Thrown when ETH sent is zero
    error Campaign__ZeroAmount();

    /// @notice Thrown when total milestone target does not equal campaign goal
    /// @dev All milestones must sum to exactly the campaign goal before funding
    error Campaign__MilestoneTargetNotEqualCampaignGoal();

    /// @notice Thrown when funding attempt is made after campaign deadline
    error Campaign__CampaignDeadlinePassed();

    /// @notice Thrown when funding attempt is made after goal is already reached
    error Campaign__CampaignGoalReached();

    /// @notice Thrown when milestone index is out of bounds
    error Campaign__InvalidMilesToneIndex();

    /// @notice Thrown when milestone is already marked as completed
    error Campaign__AlreayCompleted();

    /// @notice Thrown when total milestone target does not equal goal during submission
    error Campaign__TotalMilesToneTargetNotMeet();

    /// @notice Thrown when milestone payment has already been withdrawn
    error Campaign_AlreadyPaidMilestone();

    /// @notice Thrown when ETH transfer fails
    error Campaign_TransferFailed();

    /// @notice Thrown when refund is attempted while campaign is still active
    error Campaign__CampaignStillActive();

    /// @notice Thrown when refund is attempted but goal has been met
    error Campaign__CampaignGoalMeet();

    /// @notice Thrown when refund is attempted by non-contributor
    error Campaign__ZeroContribution();

    /// @notice Thrown when milestone not submitted before withdrawal
    error Campaign__MilestoneNotCompleted();

    // ═══════════════════════════════════════════════════════
    //   MODIFIERS
    // ═══════════════════════════════════════════════════════

    /// @notice Restricts function to campaign creator only
    /// @dev Uses Ownable owner() for creator check
    modifier onlyCreator() {
        if (msg.sender != owner()) revert Campaign__NotOwner();
        _;
    }

    /// @notice Prevents reentrancy attacks using a lock flag
    /// @dev Sets s_locked = true before execution, false after
    ///      Reverts with "Reentrant" if called while locked
    modifier nonReentrant() {
        require(!s_locked, "Reentrant");
        s_locked = true;

        _;

        s_locked = false;
    }

    /// @notice Validates campaign is registered and active in factory
    /// @dev Checks three conditions:
    ///      1. Campaign address is not zero
    ///      2. Campaign is registered in factory whitelist
    ///      3. Campaign is marked as active in factory

    modifier onlyValidCampaign() {
        address _campaignAddress = address(this);

        if (_campaignAddress == address(0)) revert Campaign__ZeroAddress();

        if (!CrowdFundingFactory(I_FACTORY).isValidCampaign(_campaignAddress))
            revert Campaign__InValidCampaign();

        CrowdFundingFactoryLibary.CampaignInfo
            memory info = CrowdFundingFactory(I_FACTORY).getCampaignByAddress(
                _campaignAddress
            );

        if (!info.active) revert Campaign__NotActiveCampaign();
        _;
    }

    // ═══════════════════════════════════════════════════════
    //   CONSTRUCTOR
    // ═══════════════════════════════════════════════════════

    /// @notice Initializes a new Campaign contract
    /// @dev Called exclusively by CrowdFundingFactory.createCampaign()
    ///      Factory address is locked as immutable
    /// @param _creator Address of the campaign creator — becomes Ownable owner
    /// @param _factory Address of the deploying factory contract
    /// @param _goal Funding goal in wei
    /// @param _deadine Unix timestamp of campaign end time
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

    // ═══════════════════════════════════════════════════════
    //   MILESTONE FUNCTIONS
    // ═══════════════════════════════════════════════════════

    /// @notice Adds a new milestone to the campaign
    /// @dev Requirements:
    ///      - Caller must be campaign creator
    ///      - Campaign must be valid and active
    ///      - Description must not be empty
    ///      - Amount must be greater than zero
    ///      - Milestone must not be a duplicate
    ///      - Adding milestone must not exceed campaign goal
    /// @param _description Human-readable description of the milestone deliverable
    /// @param _goal Milestone target amount in whole units (converted to wei internally)

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

        if (totalMilestoneTarget + _targetAmount > s_goal)
            revert Campaign__MilestoneExceedGoal();

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

    /// @notice Marks a milestone as complete — enables withdrawal
    /// @dev Requirements:
    ///      - Caller must be campaign creator
    ///      - Index must be valid
    ///      - Total milestone target must equal campaign goal
    ///      - Milestone must not already be completed
    /// @param index Zero-based index of the milestone in the milestones array

    function submitMilestone(uint256 index) public onlyCreator {
        if (index >= milestones.length)
            revert Campaign__InvalidMilesToneIndex();

        if (totalMilestoneTarget != s_goal)
            revert Campaign__TotalMilesToneTargetNotMeet();

        Milestone storage _milestone = milestones[index];
        if (_milestone.completed == true) revert Campaign__AlreayCompleted();

        _milestone.completed = true;

        emit SubmitMilestone(msg.sender, _milestone.completed);
    }

    // ═══════════════════════════════════════════════════════
    //   FUNDING FUNCTIONS
    // ═══════════════════════════════════════════════════════

    /// @notice Allows contributors to fund the campaign
    /// @dev Handles overfunding by accepting only the remaining amount
    ///      and refunding any excess ETH to the sender.
    ///      Requirements:
    ///      - Campaign must be valid and active
    ///      - Sent value must be greater than zero
    ///      - Total milestone target must equal campaign goal
    ///      - Campaign must not already be fully funded
    ///      - Current timestamp must be before deadline

    function fundCampaign() external payable onlyValidCampaign {
        uint256 _sentValue = msg.value;

        if (_sentValue == 0) revert Campaign__ZeroAmount();

        if (totalMilestoneTarget != s_goal)
            revert Campaign__MilestoneTargetNotEqualCampaignGoal();

        if (s_funded) revert Campaign__CampaignGoalReached();

        uint256 _deadline = getCampaignInfo().deadline;
        if (block.timestamp >= _deadline)
            revert Campaign__CampaignDeadlinePassed();

        CampaignState storage state = s_campaignState[address(this)];
        uint256 totalFunded = state.totalFunded;

        uint256 target = s_goal - totalFunded;
        uint256 accepted;
        uint256 refund;

        // handle overfunding — only accept what's needed
        if (_sentValue > target) {
            accepted = target;
            refund = _sentValue - target;
        } else {
            accepted = _sentValue;
        }

        uint256 newTotal = totalFunded + accepted;

        // update state before external call
        state.contributors[msg.sender] += accepted;
        state.totalFunded = newTotal;

        if (newTotal == s_goal) {
            s_funded = true;
        }
        emit CampaignFunded(msg.sender, accepted);

        //  refund excess after state update
        if (refund > 0) {
            (bool success, ) = msg.sender.call{value: refund}("");
            require(success, "refunf failed");
        }
    }

    // ═══════════════════════════════════════════════════════
    //   WITHDRAWAL FUNCTIONS
    // ═══════════════════════════════════════════════════════

    /// @notice Withdraws milestone payment to the campaign creator
    /// @dev Protected by nonReentrant modifier.
    ///      Follows checks-effects-interactions pattern:
    ///      state is updated before ETH transfer.
    ///      Requirements:
    ///      - Caller must be campaign creator
    ///      - Index must be valid
    ///      - Milestone must be marked as completed via submitMilestone()
    ///      - Milestone must not already be paid
    /// @param index Zero-based index of the milestone to withdraw

    function withdraw(uint256 index) public onlyCreator nonReentrant {
        if (index >= milestones.length)
            revert Campaign__InvalidMilesToneIndex();

        Milestone storage _milestone = milestones[index];
        if (_milestone.completed == false)
            revert Campaign__MilestoneNotCompleted();

        if (_milestone.paid == true) revert Campaign_AlreadyPaidMilestone();

        _milestone.paid = true;

        emit WithdrawMilestoneAmount(msg.sender, _milestone.amount);

        (bool success, ) = payable(msg.sender).call{value: _milestone.amount}(
            ""
        );

        if (!success) revert Campaign_TransferFailed();
    }

    /// @notice Allows contributors to claim a refund if goal is not met
    /// @dev Protected by nonReentrant modifier.
    ///      Follows checks-effects-interactions pattern:
    ///      contribution zeroed before ETH transfer.
    ///      Requirements:
    ///      - Campaign must be valid and active
    ///      - Campaign deadline must have passed
    ///      - Campaign goal must not have been met
    ///      - Caller must have a non-zero contribution

    function refundContributors() public onlyValidCampaign nonReentrant {
        if (block.timestamp < s_deadline)
            revert Campaign__CampaignStillActive();

        CampaignState storage _state = s_campaignState[address(this)];
        uint256 totalFunded = _state.totalFunded;

        if (totalFunded >= s_goal) revert Campaign__CampaignGoalMeet();

        uint256 amountContributed = _state.contributors[msg.sender];

        if (amountContributed == 0) revert Campaign__ZeroContribution();

        //  zero before transfer — prevents double claim
        _state.contributors[msg.sender] = 0;

        emit RefundContributors(msg.sender, amountContributed);

        (bool success, ) = payable(msg.sender).call{value: amountContributed}(
            ""
        );

        if (!success) revert Campaign_TransferFailed();
    }

    // ═══════════════════════════════════════════════════════
    //   VIEW FUNCTIONS
    // ═══════════════════════════════════════════════════════

    /// @notice Returns whether the campaign has reached its funding goal
    /// @return bool True if campaign is fully funded, false otherwise

    function getStatus() public view returns (bool) {
        return s_funded;
    }

    /// @notice Returns the total amount funded so far
    /// @return uint256 Total funded amount in wei
    function getTotalFunded() public view returns (uint256) {
        CampaignState storage state = s_campaignState[address(this)];
        uint256 amt = state.totalFunded;
        return amt;
    }

    /// @notice Returns the contribution amount for a specific address
    /// @param _address Address of the contributor to query
    /// @return uint256 Contribution amount in wei
    function getContributors(address _address) public view returns (uint256) {
        CampaignState storage state = s_campaignState[address(this)];
        uint256 fund = state.contributors[_address];
        return fund;
    }

    /// @notice Returns full campaign info from the factory
    /// @dev Calls back to the factory contract to retrieve stored info
    /// @return CampaignInfo struct containing creator, goal, deadline, active status
    function getCampaignInfo()
        public
        view
        returns (CrowdFundingFactoryLibary.CampaignInfo memory)
    {
        CrowdFundingFactoryLibary.CampaignInfo
            memory info = CrowdFundingFactory(I_FACTORY).getCampaignByAddress(
                address(this)
            );

        return info;
    }

    /// @notice Returns a specific milestone by index
    /// @param index Zero-based index of the milestone
    /// @return Milestone struct with description, amount, completed and paid fields
    function getMilestone(
        uint256 index
    ) public view returns (Milestone memory) {
        return milestones[index];
    }

    /// @notice Returns the campaign funding goal in wei
    /// @return uint256 Campaign goal in wei
    function getGoal() external view returns (uint256) {
        return s_goal;
    }

    /// @notice Returns the campaign deadline as a Unix timestamp
    /// @return uint256 Deadline timestamp
    function getDeadline() external view returns (uint256) {
        return s_deadline;
    }

    /// @notice Returns the total number of milestones
    /// @return uint256 Length of the milestones array
    function getTotalMileStoneLength() external view returns (uint256) {
        return milestones.length;
    }

    function getMileStoneTotalFunded(
        uint256 index
    ) external view returns (uint256) {
        Milestone storage _milestone = milestones[index];
        return _milestone.amount;
    }

    function getamountContributed(
        address user
    ) external view returns (uint256) {
        CampaignState storage _state = s_campaignState[address(this)];

        uint256 _amountContributed = _state.contributors[user];

        return _amountContributed;
    }
}
