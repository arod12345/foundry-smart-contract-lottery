// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import {Script, console} from "forge-std/Script.sol";
import {HelperConfig, CodeConstants} from "script/HelperConfig.s.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/contracts/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "test/mocks/LinkToken.sol";
import {DevOpsTools} from "lib/foundry-devops/src/DevOpsTools.sol";

contract CreateSubscription is Script {
    function CreateSubscriptionUsingConfig() public returns (uint256, address) {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator; 
        address account = helperConfig.getConfig().account;
        (uint256 subId,) = createSubscription(vrfCoordinator,account);
        return (subId, vrfCoordinator);
    }

    function createSubscription(address vrfCoordinator,address account) public returns (uint256, address) {
        console.log("Creating subscription on Chain ID: ", block.chainid);

        vm.startBroadcast(account);
        uint256 subId = VRFCoordinatorV2_5Mock(vrfCoordinator).createSubscription();
        vm.stopBroadcast();
        console.log("Your Subscription Id is: ", subId);
        console.log("Please update the subscription Id in your HelperConfig.s.sol");
        return (subId, vrfCoordinator);
    }

    function run() public {
        CreateSubscriptionUsingConfig();
    }
}

contract FundSubscription is Script, CodeConstants {
    uint256 public constant FUND_AMOUNT = 3 ether; //3 Link

    function fundSubscriptionUsingConfig() public {
        HelperConfig helperConfig = new HelperConfig();
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        uint256 subscriptionID = helperConfig.getConfig().subscriptionID;
        address linkToken = helperConfig.getConfig().link;
        address account = helperConfig.getConfig().account;
        fundSubscription(vrfCoordinator, subscriptionID, linkToken,account);
    }

    function fundSubscription(address vrfCoordinator, uint256 subscriptionId, address linkToken,address account) public {
        console.log("Funding the subscription: ", subscriptionId);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainId :", block.chainid);

        if (block.chainid == LOCAL_CHAIN_ID) {
            vm.startBroadcast();
            VRFCoordinatorV2_5Mock(vrfCoordinator).fundSubscription(subscriptionId, FUND_AMOUNT * 100);
            vm.stopBroadcast();
        } else {
            vm.startBroadcast(account);
            LinkToken(linkToken).transferAndCall(vrfCoordinator, FUND_AMOUNT, abi.encode(subscriptionId));
            vm.stopBroadcast();
        }
    }

    function run() public {
        fundSubscriptionUsingConfig();
    }
}

contract AddConsumer is Script {
    function addConsumerUsingConfig(address mostRecentlyDeployed) public {
        HelperConfig helperConfig = new HelperConfig();
        uint256 subID = helperConfig.getConfig().subscriptionID;
        address vrfCoordinator = helperConfig.getConfig().vrfCoordinator;
        address account= helperConfig.getConfig().account; 
        addConsumer(mostRecentlyDeployed, vrfCoordinator, subID,account);
    }

    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subID,address account) public {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Adding consumer to VRF Coordinator:", vrfCoordinator);
        console.log("on Chain ID :", block.chainid);

        vm.startBroadcast(account);
        VRFCoordinatorV2_5Mock(vrfCoordinator).addConsumer(subID, contractToAddToVrf);
        vm.stopBroadcast();
    }

    function run() external {
        address mostRecentlyDeployed = DevOpsTools.get_most_recent_deployment("Raffle", block.chainid);
        addConsumerUsingConfig(mostRecentlyDeployed);
    }
}
