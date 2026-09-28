// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script, console} from "forge-std/Script.sol";
import {IVRFSubscriptionV2Plus} from "@chainlink/src/v0.8/vrf/dev/interfaces/IVRFSubscriptionV2Plus.sol";

contract AddConsumer is Script {
    function addConsumer(address contractToAddToVrf, address vrfCoordinator, uint256 subId, address account) internal {
        console.log("Adding consumer contract: ", contractToAddToVrf);
        console.log("Using vrfCoordinator: ", vrfCoordinator);
        console.log("On ChainID: ", block.chainid);
        vm.startBroadcast(account);
        IVRFSubscriptionV2Plus(vrfCoordinator).addConsumer(subId, contractToAddToVrf);
        vm.stopBroadcast();
    }
}

