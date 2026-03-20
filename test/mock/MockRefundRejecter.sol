// SPDX-License-Identifier: MIT

pragma solidity ^0.8.24;

import {CrowdFundingFactory} from "../../src/CrowdFundingFactory.sol";

contract MockRefundRejecter {
    bool public rejectEth;

    receive() external payable {
        if (rejectEth) revert("I reject ETH");
    }

    function attack(
        CrowdFundingFactory factory,
        uint256 goal,
        uint256 days_,
        uint256 fee
    ) external {
        rejectEth = true;
        factory.createCampaign{value: fee}(goal, days_);
    }
}
