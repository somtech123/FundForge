// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Campaign} from "../../src/Campaign.sol";
import {CrowdFundingFactory} from "../../src/CrowdFundingFactory.sol";
import {CrowdFundingFactoryLibary} from  "../../src/libary/CrowdFundingLiary.sol";

contract CampaignTest is Test {
    Campaign campaign;
    CrowdFundingFactory factory;

    address USER = makeAddr("user");
    address ANOTHER_USER = makeAddr("another_user");
    address ATTACKER = makeAddr("attacker");

   
    uint256 constant MIN_FEE = 1000000000000000;
    uint256 constant STARTING_BALANCE = 10 ether;

    uint256 private constant VALID_GOAL = 6;
    uint256 private constant VALID_DURATION = 55;

    uint256 private constant VALID_TARGET = 3;
    uint256 private constant VALID_FUND = 2;
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
        vm.startPrank(ATTACKER);
        _;
        vm.stopPrank(); 
    }

    modifier addMilestoneTarget(){
        campaign.addMilestone(VALID_DESC, VALID_GOAL);
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
        CrowdFundingFactoryLibary.CampaignInfo memory info = factory.getCampaignByAddress(address(campaign));
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

        bytes32 _hash =keccak256(abi.encode(VALID_DESC, VALID_TARGET *1e18));

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
        assertEq(amount, VALID_TARGET*1e18);
        assertEq(completed, false);
        assertEq(paid, false);
    }

    function testCampaignAddMilestoneEmitEventProperly() public asCreator{
        vm.expectEmit(true, false, false, true);

        emit Campaign.MilestoneAdded(USER,VALID_DESC, VALID_TARGET * 1e18);

        campaign.addMilestone(VALID_DESC, VALID_TARGET);
    }

     //===========================
    //     Funding Test 
    //============================
    

    // test funding with zero amount
    function testCampaignFundWithZeroAmount() public asCreator{
        vm.expectRevert(Campaign.Campaign__ZeroAmount.selector);

        campaign.fundCampaign{value: 0}();
    }
     
      // test funding with milestone not equal target
    function testCampaignMilestoneTargetEqaualGoal() public asCreator{
        vm.expectRevert(Campaign.Campaign__MilestoneTargetNotEqualCampaignGoal.selector);

        campaign.fundCampaign{value: VALID_FUND}();
    }

    function testCampaignFunded() public asCreator{
    
        campaign.addMilestone(VALID_DESC, VALID_GOAL);
        campaign.fundCampaign{value: 6 ether}();
        
         vm.expectRevert(Campaign.Campaign__CampaignGoalReached.selector);
        campaign.fundCampaign{value: 1 ether}();

    }

    function testCampaignFundingAfterDeadline() public asCreator addMilestoneTarget{
  
        vm.warp(block.timestamp + VALID_DURATION * 1 days + 1);

       vm.expectRevert(Campaign.Campaign__CampaignDeadlinePassed.selector);

       campaign.fundCampaign{value: VALID_FUND}();

    }

    function testCampaignFundedUpdateState() public asCreator addMilestoneTarget{
      
        campaign.fundCampaign{value: 2 ether}();

         assertEq(campaign.getTotalFunded(), 2 ether);
         assertEq(campaign.getContributors(USER), 2 ether);

    }

    function testCampaignFundWithInvalidCampaign() public asAttacker {
        Campaign fakeCampaign = new Campaign(ATTACKER, address(factory), VALID_GOAL, VALID_DURATION);

         vm.expectRevert(Campaign.Campaign__InValidCampaign.selector);

        fakeCampaign.fundCampaign{value: VALID_TARGET}();

    }

    function testCampaignMultipleFunders() public {
        vm.prank(USER);
        campaign.addMilestone(VALID_DESC, VALID_GOAL);

        vm.startPrank(ANOTHER_USER);
        campaign.fundCampaign{value: VALID_FUND}();
        vm.stopPrank(); 

        vm.startPrank(ATTACKER);
        campaign.fundCampaign{value: VALID_FUND}();
        vm.stopPrank(); 

        vm.startPrank(ATTACKER);
        campaign.fundCampaign{value: 1}();
        vm.stopPrank(); 

        assertEq(campaign.getTotalFunded(), 5);
        assertEq(campaign.getContributors(ANOTHER_USER), 2);
        assertEq(campaign.getContributors(ATTACKER), 3);

    }

    function testFundingEmitCorrectly() public asCreator addMilestoneTarget{
         vm.expectEmit(true, false, false, true);

        emit Campaign.CampaignFunded(USER, VALID_FUND);

        campaign.fundCampaign{value: VALID_FUND}();
    }

    function testCampaignOverFundingReturnExcess() public asCreator addMilestoneTarget{
        campaign.fundCampaign{value: 1 ether}();

        uint256 balanceBefore = USER.balance;
        campaign.fundCampaign{value: 7 ether}();

        uint256 balanceAfter = USER.balance;
      
        assertEq(balanceBefore - balanceAfter, 5 ether);
    }

    function testCampaignFundingMeetExactGoals() public asCreator addMilestoneTarget{
        campaign.fundCampaign{value: 6 ether}();

        assertEq(campaign.getTotalFunded(), VALID_GOAL *1e18);

    }

    function testCampaignBalanceMatchFunding()public asCreator addMilestoneTarget{
        campaign.fundCampaign{value: 6 ether}();

        assertEq(address(campaign).balance, VALID_GOAL *1e18);

    }

    



    

  
}
