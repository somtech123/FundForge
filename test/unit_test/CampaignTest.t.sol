// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {Campaign} from "../../src/Campaign.sol";
import {CrowdFundingFactory} from "../../src/CrowdFundingFactory.sol";

contract CampaignTest is Test {
    Campaign campaign;
    CrowdFundingFactory factory;

    address USER = makeAddr("user");
    address ANOTHER_USER = makeAddr("another_user");
    address ATTACKER = makeAddr("attacker");

    uint256 constant MIN_FEE = 0.010 ether;
    uint256 constant STARTING_BALANCE = 10 ether;

    uint256 private constant VALID_GOAL = 1e18;
    uint256 private constant VALID_DURATION = 55;

    uint256 private constant VALID_TARGET = 1;
    string private constant VALID_DESC = "phase 1";

    function setUp() public {
        factory = new CrowdFundingFactory();

        vm.deal(USER, STARTING_BALANCE);
        vm.deal(ANOTHER_USER, STARTING_BALANCE);
        vm.deal(ATTACKER, STARTING_BALANCE);

        vm.prank(USER);
        address campaignAddress = factory.createCampaign{value: MIN_FEE}(
            VALID_GOAL,
            VALID_DURATION
        );

        campaign = Campaign(campaignAddress);
    }

    modifier asCreator() {
        vm.startPrank(USER);
        _;
        vm.stopPrank(); 
        
    }

    

    modifier notCreator(){
        vm.prank(ATTACKER);
        _;
    }

    modifier asAttacker(){
        vm.prank(ATTACKER);
        _;
    }


    //=================================
    // Constructor Test
    //==================================

    function testCampaignConstructorSetsFactoryCorrectly() public view {
        assertEq(campaign.I_FACTORY(), address(factory));
    }

    function testCampaignConstructorSetCreatorCorrectly() public view {
        assertEq(campaign.owner(), USER);
    }

    function testCampaignConstructorSetGoalCorrectly() public view {
        assertEq(campaign.getGoal(), VALID_GOAL * 1e18);
    }

    function testCampaignConstructorSetDeadlineCorrectly() public view  {
        assertGt(campaign.getDeadline(), block.timestamp);
    }

    function testCampaignIsActive() public view {
        CrowdFundingFactory.CampaignInfo memory info = factory.getCampaignByAddress(address(campaign));
        assertTrue(info.active);
    }

    //===========================
    //     Add Milestone
    //============================

    function testCampaignAddMilestoneNotCreator() public notCreator {
        vm.expectRevert(Campaign.Campaign__NotOwner.selector);
        campaign.addMilestone(VALID_DESC, VALID_TARGET);

    }

    function testCampaignAddMilesToneWithInValidCampaign() public asAttacker{
        Campaign fakeCampaign = new Campaign(ATTACKER, address(factory), VALID_GOAL, VALID_DURATION);

        assertFalse(factory.isValidCampaign(address(fakeCampaign)));
        
    }

    function testCampaignAddMilestoneWithInvalidCampagn() public {
        vm.startPrank(ATTACKER);
        Campaign fakeCampaign = new Campaign(ATTACKER, address(factory), VALID_GOAL, VALID_DURATION);

        vm.expectRevert(Campaign.Campaign__InValidCampaign.selector);

        fakeCampaign.addMilestone(VALID_DESC, VALID_TARGET);
        vm.stopPrank(); 

    }

    function testCampaignAddMilestoneWithZeroAmount() public asCreator{

        vm.expectRevert(Campaign.Campaign__ZeroMilestoneTarget.selector);

        campaign.addMilestone(VALID_DESC, 0);

    }

    function testCampaignAddMilestoneWithEmptyDesc() public asCreator{
        vm.expectRevert(Campaign.Campaign__InvalidMilestoneDescription.selector);

        campaign.addMilestone('', VALID_TARGET);
        
    }

    function testCampaignAddUniqueMilestone() public asCreator{
        campaign.addMilestone(VALID_DESC, VALID_TARGET);

        bytes32 _hash =keccak256(abi.encode(VALID_DESC, VALID_TARGET));

        assertTrue(campaign.milestoneExists(_hash));

    }

    function testCampaignAddDuplicateMilestone() public {
        vm.startPrank(USER);

        campaign.addMilestone(VALID_DESC, VALID_TARGET);

        vm.expectRevert(Campaign.Campaign__DuplicateMilestone.selector);

        campaign.addMilestone(VALID_DESC, VALID_TARGET);

        vm.stopPrank(); 

    }

    function testCampaignTargetMustNotExceedGoal() public  asCreator{
        campaign.addMilestone(VALID_DESC, VALID_TARGET);

        uint256 amount = campaign.totalMilestoneTarget() + VALID_TARGET;

        assertGt(campaign.getGoal(), amount);
    }

    function testCampaignAddMilestoneTarget() public asCreator {
      
         uint256 target = campaign.getGoal() + 1e10;
       
        vm.expectRevert(Campaign.Campaign__MilestoneExceedGoal.selector);
        
        campaign.addMilestone(VALID_DESC, target);
    }

    function testCampaignMilestoneTargetIncrement() public asCreator{

        uint256 beforeTarget = campaign.totalMilestoneTarget();

        campaign.addMilestone(VALID_DESC, VALID_TARGET);
        uint256 afterTarget = campaign.totalMilestoneTarget();

        vm.assertGt(afterTarget, beforeTarget);

    }

    function testCampaignMilestoneAddedProperly() public asCreator{

        campaign.addMilestone(VALID_DESC, VALID_TARGET);

        assertEq(campaign.getTotalMileStoneLength(), 1);

        (string memory description,
        uint256 amount,
        bool completed,
        bool paid) = campaign.milestones(0);

        assertEq(description, VALID_DESC);
        assertEq(amount, VALID_TARGET);
        assertEq(completed, false);
        assertEq(paid, false);
    }

    function testCampaignAddMilestoneEmitEventProperly() public asCreator{
        vm.expectEmit(true, false, false, true);

        emit Campaign.MilestoneAdded(USER,VALID_DESC, VALID_TARGET);

        campaign.addMilestone(VALID_DESC, VALID_TARGET);
    }



    

  
}
