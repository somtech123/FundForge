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
        vm.prank(USER);
        _;
        
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

  
}
