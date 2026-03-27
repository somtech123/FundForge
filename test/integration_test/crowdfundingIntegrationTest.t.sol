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
}
