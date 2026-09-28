// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {Raffle} from "../src/RaffleChainlinkVrf.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {AddConsumer} from "../script/Interaction.s.sol";

contract DeployRaffle is Script, AddConsumer {
    uint256 entranceFee = 0.01 ether;
    uint256 public constant LOCAL_CHAIN_ID = 31337;

    function run() public returns (Raffle, HelperConfig) {
        HelperConfig helperConfig = new HelperConfig();
        HelperConfig.NetworkConfig memory config = helperConfig.getConfig();

        helperConfig.setConfig(block.chainid, config);
        vm.startBroadcast(config._account);

        Raffle raffle = new Raffle(
            config._interval,
            config._entranceFee,
            config._keyHash,
            config._subId,
            config._callbackGasLimit,
            config.vrfCoordinatorV2
        );

        vm.stopBroadcast();

        addConsumer(address(raffle), config.vrfCoordinatorV2, config._subId, config._account);

        return (raffle, helperConfig);
    }
}
