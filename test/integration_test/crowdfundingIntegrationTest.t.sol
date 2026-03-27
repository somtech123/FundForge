// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;
import {Test} from "forge-std/Test.sol";
import {console} from "forge-std/console.sol";
import {Campaign} from "../../src/Campaign.sol";
import {CrowdFundingFactory} from "../../src/CrowdFundingFactory.sol";

contract CrowdFundingIntegrationTest is Test {
    Campaign campaign;
    CrowdFundingFactory factory;

    address USER = makeAddr("user");
    address ANOTHER_USER = makeAddr("another_user");
    address ATTACKER = makeAddr("attacker");

    uint256 constant MIN_FEE = 1000000000000000;
    uint256 constant STARTING_BALANCE = 10 ether;

    uint256 private constant VALID_GOAL = 6;
    uint256 private constant VALID_DURATION = 55;

    uint256 private constant VALID_FUND = 2;
    string private constant VALID_DESC = "phase 1";

    uint256 private constant VALID_FUND_2 = 4;
    string private constant VALID_DESC_2 = "phase 2";

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

    function testMultipleCampaignCreation() public {
        Campaign campaign_1;
        Campaign campaign_2;

        vm.prank(USER);
        address campaignAddress_1 = factory.createCampaign{value: MIN_FEE}(
            VALID_GOAL,
            VALID_DURATION
        );

        campaign_1 = Campaign(campaignAddress_1);

        vm.prank(ANOTHER_USER);
        address campaignAddress_2 = factory.createCampaign{value: MIN_FEE}(
            VALID_GOAL,
            VALID_DURATION
        );

        campaign_2 = Campaign(campaignAddress_2);

        assertEq(factory.getCampaign(0) != factory.getCampaign(1), true);
        assertTrue(factory.isValidCampaign(campaignAddress_1));
        assertTrue(factory.isValidCampaign(campaignAddress_2));
    }

    // test campaign full flow creation->addmilestone->fund->withdraw

    function testFullCampaignFlow() public {
        vm.startPrank(USER);

        campaign.addMilestone(VALID_DESC, VALID_FUND);
        campaign.addMilestone(VALID_DESC_2, VALID_FUND_2);
        vm.stopPrank();

        vm.prank(ANOTHER_USER);
        campaign.fundCampaign{value: VALID_FUND}();

        vm.prank(ATTACKER);
        campaign.fundCampaign{value: 1 ether}();

        vm.prank(ANOTHER_USER);
        campaign.fundCampaign{value: 2 ether}();

        vm.prank(ANOTHER_USER);
        campaign.fundCampaign{value: 1 ether}();

        vm.startPrank(USER);
        campaign.submitMilestone(0);

        assertEq(address(campaign).balance, campaign.getTotalFunded());

        campaign.withdraw(0);
        vm.stopPrank();
    }

    function testCampaignRefundFlow() public {
        uint256 initialBalance = ANOTHER_USER.balance;
        uint256 valueSent = 2 ether;

        vm.startPrank(USER);

        campaign.addMilestone(VALID_DESC, VALID_FUND);
        campaign.addMilestone(VALID_DESC_2, VALID_FUND_2);

        campaign.fundCampaign{value: 1 ether}();
        vm.stopPrank();

        vm.prank(ANOTHER_USER);
        campaign.fundCampaign{value: valueSent}();
        uint256 newBalance = ANOTHER_USER.balance;

        vm.warp(block.timestamp + VALID_DURATION * 10 days + 1);

        vm.prank(ANOTHER_USER);
        campaign.refundContributors();

        assertEq(campaign.getamountContributed(ANOTHER_USER), 0);
        assertEq(initialBalance, newBalance + valueSent);
    }

    //withdraw without submitting milestone throws error then submit milestone and succed
    function testWithdrawalFailThenSucceed() public {
        vm.startPrank(USER);

        campaign.addMilestone(VALID_DESC, VALID_FUND);
        campaign.addMilestone(VALID_DESC_2, VALID_FUND_2);

        campaign.fundCampaign{value: 1 ether}();
        vm.stopPrank();

        vm.prank(ANOTHER_USER);
        campaign.fundCampaign{value: 5 ether}();

        vm.startPrank(USER);

        vm.expectRevert(Campaign.Campaign__MilestoneNotCompleted.selector);
        campaign.withdraw(0);

        campaign.submitMilestone(0);

        Campaign.Milestone memory _milestone = campaign.getMilestone(0);

        vm.expectEmit(true, false, false, true);

        emit Campaign.WithdrawMilestoneAmount(USER, _milestone.amount);

        campaign.withdraw(0);

        vm.stopPrank();
    }
}
