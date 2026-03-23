// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

import {Test} from "forge-std/Test.sol";
import {CrowdFundingFactory} from "../../src/CrowdFundingFactory.sol";
import {MockRefundRejecter} from "../mock/MockRefundRejecter.sol";
import {CrowdFundingFactoryLibary} from  "../../src/libary/CrowdFundingLiary.sol";

contract CrowdFundingFactoryTest is Test {
    CrowdFundingFactory factory;
    address USER = makeAddr("user");

    uint256 constant MIN_FEE = 1000000000000000;
    uint256 constant STARTING_BALANCE = 10 ether;
    uint256 private  MINIMUM_USD = 2;

    uint256 private constant VALID_GOAL = 6 ;
    uint256 private constant VALID_DURATION = 55;

    function setUp() public {
        factory = new CrowdFundingFactory();

        vm.deal(USER, STARTING_BALANCE);
    }

    modifier asUser() {
        vm.prank(USER);
        _;
    }

    //=======================================================
    //        Invalid path
    //========================================================

    // Test — goal is zero
    function testCreateCampaignInvalidGoal() public asUser {
        // vm.prank(USER);

        vm.expectRevert(
            CrowdFundingFactory.CrowdFundingFactory__InvalidGoal.selector
        );

        factory.createCampaign{value: MIN_FEE}(0 ether, 30);
    }

    // Test — goal below minimum
    function testCreateCampaignWithLessThanMinimuGoal() public asUser {
        // vm.prank(USER);

        vm.expectRevert(
            CrowdFundingFactory
                .CrowdFundingFactory__LessThanMinimumGoal
                .selector
        );

        factory.createCampaign{value: MIN_FEE}(1, 30);
    }
    // Test — goal below minimum duration
    function testCreateCampaignForInvalidDeadline() public asUser {
        vm.expectRevert(
            CrowdFundingFactory.CrowdFundingFactory__InvalidDeadLine.selector
        );

        factory.createCampaign{value: MIN_FEE}(MINIMUM_USD, 0);
    }

    // Test — goal below deadline too close
    function testCreateCampaignForDeadLineTooClose() public asUser {
        vm.expectRevert(
            CrowdFundingFactory.CrowdFundingFactory__DeadLineTooClose.selector
        );

        factory.createCampaign{value: MIN_FEE}(MINIMUM_USD, 1);
    }

    // Test — goal deadline too far

    function testCreateCampaignForDeadLineTooFar() public asUser {
        vm.expectRevert(
            CrowdFundingFactory.CrowdFundingFactory__DeadLineToFar.selector
        );

        factory.createCampaign{value: MIN_FEE}(MINIMUM_USD, 366);
    }
    // Test — goal createCampaign with invalid fee

    function testCreateCampaignWithInsuffcientFees() public asUser {
        vm.expectRevert(
            CrowdFundingFactory.CrowdFundingFactory__InsufficientFee.selector
        );

        factory.createCampaign{value: 0.0001 ether}(MINIMUM_USD, 30);
    }

    //=======================================================
    //        Success path
    //========================================================

    // Test — goal createCampaign successfully

    function testCampaignCreatedSuccessfully() public asUser {
        factory.createCampaign{value: MIN_FEE}(VALID_GOAL, VALID_DURATION);

        assertEq(factory.getCampaignCount(), 1);

        address campaignAddress = factory.getCampaign(0);
        assertTrue(campaignAddress != address(0));
        assertTrue(factory.isValidCampaign(campaignAddress));
    }

    function testCreateCampaignStoresCorrectInfo() public asUser {
        factory.createCampaign{value: MIN_FEE}(VALID_GOAL, VALID_DURATION);

        CrowdFundingFactoryLibary.CampaignInfo memory info = factory.getCampaignInfo(
            0
        );

        assertEq(info.creator, USER);
        assertEq(info.goal, VALID_GOAL * 1e18);

        assertTrue(info.campaignAddress != address(0));
        assertTrue(info.createdAt > 0);
    }

    function testCreateCampaignRefundsExcessFee() public asUser {
        uint256 excessFee = 0.05 ether;
        uint256 initialBalance = USER.balance;

        factory.createCampaign{value: MIN_FEE + excessFee}(
            VALID_GOAL,
            VALID_DURATION
        );

        uint256 balanceAfter = USER.balance;

        assertEq(initialBalance - balanceAfter, MIN_FEE);
    }

    function testCreateCampaignEmitsEvent() public asUser {
        vm.expectEmit(true, false, false, true);

        emit CrowdFundingFactory.CampaignCreated(USER, MIN_FEE, 1);

        factory.createCampaign{value: MIN_FEE}(VALID_GOAL, VALID_DURATION);
    }

    function testCreateMulipleCampaigns() public {
        uint256 numberOfCampaigns = 3;
        vm.startPrank(USER);

        for (uint256 i = 0; i < numberOfCampaigns; i++) {
            factory.createCampaign{value: MIN_FEE}(VALID_GOAL, VALID_DURATION);
        }
        vm.stopPrank();

        assertEq(factory.getCampaignCount(), numberOfCampaigns);
        assertEq(factory.getCampaign(0) != factory.getCampaign(1), true);
    }

    function testRefundFailsWhenCallerCannotReceiveEth() public {
        MockRefundRejecter rejecter = new MockRefundRejecter();

        vm.deal(address(rejecter), 10 ether);

        vm.prank(address(rejecter));
        vm.expectRevert("Refund Failed");

        rejecter.attack(
            factory,
            VALID_GOAL,
            VALID_DURATION,
            MIN_FEE + 0.05 ether
        );
    }

    //=======================================================
    //        Test View Functions
    //========================================================

    function testGetCampaignInfo() public asUser {
        factory.createCampaign{value: MIN_FEE}(VALID_GOAL, VALID_DURATION);

        CrowdFundingFactoryLibary.CampaignInfo memory info = factory.getCampaignInfo(
            0
        );

        assertEq(info.creator, USER);
        assertGt(info.goal, 0);
    }

    function testGetAllCampaigns() public asUser {
        factory.createCampaign{value: MIN_FEE}(VALID_GOAL, VALID_DURATION);
        factory.createCampaign{value: MIN_FEE}(VALID_GOAL, VALID_DURATION);

        address[] memory campaigns = factory.getAllCampaigns();

        assertEq(campaigns.length, 2);
    }

    function testIsValidCampaign() public asUser {
        factory.createCampaign{value: MIN_FEE}(VALID_GOAL, VALID_DURATION);

        address campaignAddress = factory.getCampaign(0);

        assertTrue(factory.isValidCampaign(campaignAddress));
        assertFalse(factory.isValidCampaign(address(0)));
    }
}
