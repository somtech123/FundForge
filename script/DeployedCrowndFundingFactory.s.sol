// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";

import {CrowdFundingFactory} from "../src/CrowdFundingFactory.sol";

contract DeployedCrowndFundingFactory is Script {
    function run() external returns (CrowdFundingFactory) {
        vm.startBroadcast();

        CrowdFundingFactory factory = new CrowdFundingFactory();

        vm.stopBroadcast();

        return factory;
    }
}
