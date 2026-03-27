// SPDX-License-Identifier: MIT
pragma solidity ^0.8.18;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

import {CrowdFundingFactory} from "../src/CrowdFundingFactory.sol";

contract DeployedCrowndFundingFactory is Script {
    function run() external returns (CrowdFundingFactory) {
        uint256 chainId = block.chainid;

        CrowdFundingFactory factory;
        vm.startBroadcast();
        if (chainId == 11155111) {
            //run on sepolia testnet
            factory = new CrowdFundingFactory();
        } else if (chainId == 1) {
            //run on etherum mainnet
            factory = new CrowdFundingFactory();
        } else if (chainId == 31337) {
            //run on anvil local testnet
            factory = new CrowdFundingFactory();
        } else {
            //  only fires if NO chain matched
            revert("Unsupported Network");
        }

        vm.stopBroadcast();

        return factory;
    }
}
