// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Test, console2, console} from "forge-std/Test.sol";
import {DeployRaffle} from "../script/DeployRaffleChainlinkVrf.s.sol";
import {Raffle} from "../src/RaffleChainlinkVrf.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {HelperConfig} from "../script/HelperConfig.s.sol";
import {Vm} from "forge-std/Vm.sol";

contract RaffleTest is Test {
    DeployRaffle deployer;
    Raffle raffle;
    HelperConfig helperConfig;
    

    uint256 raffleEntranceFee = 0.01 ether;
    uint256 startingBalance = 1 ether;
    address Bob = makeAddr("bob");
    address Alice = makeAddr("alice");

    function setUp() public {
        deployer = new DeployRaffle();
        (raffle,helperConfig) = deployer.run();
      
        vm.deal(Bob, startingBalance);
        vm.deal(Alice, startingBalance);


    }

    function _triggerAndFulfillVrf() internal returns (bytes32 requestId) {
    vm.recordLogs();
    raffle.performUpkeep("");
    Vm.Log[] memory entries = vm.getRecordedLogs();

    bool found = false;
    for (uint256 i = 0; i < entries.length; i++) {
        if (entries[i].topics[0] == keccak256("RandomWordsRequested(uint256)")) {
            requestId = entries[i].topics[1];
            found = true;
            break;
        }
    }
    require(found, "RandomWordsRequested event not found");

    HelperConfig.NetworkConfig memory config = helperConfig.getConfig();
    VRFCoordinatorV2_5Mock(config.vrfCoordinatorV2).fulfillRandomWords(uint256(requestId), address(raffle));
}

    function testRaffleBalanceStartsAtZero() public view{
    assertEq(address(raffle).balance, 0);
    }

    function testRaffleStartInOpenState() public view {
        assertEq(uint256(raffle.getRaffleState()),0);
    }

    function testIntervalIsSetCorrectly() public view {
        assertEq(raffle.getInterval(), 30);
    }

    function testEntranceFeeIsSetCorrectly() public view {
        assertEq(raffle.getEntranceFee(), 0.01 ether);
    }
     
    function  testCheckUpkeepReturnsFalseIfNoPlayers() public {
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
         }
         
    function testCheckUpkeepReturnsTrueWhenConditionsAreMet() public {
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertTrue(upkeepNeeded);
        

    }

    function testRaffleStateChngesToCalculatingWhenUpkeepNeeded() public {
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        raffle.performUpkeep("");
        assertEq(uint256(raffle.getRaffleState()), 1);
    }

    function testCheckUpkeepReturnsFalseWhenNotEnoughTimeHasPassed() public {
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
         
    }

    function testPlayerCanEnterRaffle() public {
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        assertEq(raffle.getPlayer(0), Bob);
    }

    function testMultiplePlayers() public {
        // Arrange
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();

        vm.prank(Alice);
        raffle.enterRaffle{value: raffleEntranceFee}();

        assertEq(raffle.getPlayer(0), Bob);
        assertEq(raffle.getPlayer(1), Alice);
        assertEq(raffle.getLengthOfPlayers(), 2);
    }

    function testEntryFeeValidation() public {
        vm.prank(Bob);
        vm.expectRevert(Raffle.Raffle__ValueMustBeEqualToEntranceFee.selector);
        raffle.enterRaffle{value: 0.001 ether}();
    }

    function testRaffleZeroEthReverts() public {
        vm.prank(Bob);
        vm.expectRevert(Raffle.Raffle__ValueMustBeEqualToEntranceFee.selector);
        raffle.enterRaffle{value: 0}();
    }

    function testMoreThanEntranceFeeReverts() public {
        vm.prank(Bob);
        vm.expectRevert(Raffle.Raffle__ValueMustBeEqualToEntranceFee.selector);
        raffle.enterRaffle{value: 0.5 ether}();
    }


    function testRaffleEnteredEventsContainsCorrectPlayer() public {
        
        vm.prank(Bob);
        vm.expectEmit(true, false, false, false);
        emit Raffle.RaffleEntered(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
    }

    function testDirectEthTransferReverts() public {
        vm.prank(Bob);
        vm.expectRevert();
        address(raffle).call{value: raffleEntranceFee}("");
    }

    function testCannotEnterWhenRaffleIsCalculating() public {
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        raffle.performUpkeep("");

        vm.prank(Bob);
        vm.expectRevert(Raffle.Raffle__RaffleIsNotOpen.selector);
        raffle.enterRaffle{value: raffleEntranceFee}();

    }

    function testCheckUpkeepReturnsFalseWhenRaffleIsCalculating()public {
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        raffle.performUpkeep("");

        (bool upkeepNeeded,) = raffle.checkUpkeep("");
        assertFalse(upkeepNeeded);
    }

    function testPerformUpkeepRevertsWhenUpkeepIsNotNeeded() public {
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector,address(raffle).balance, raffle.getLengthOfPlayers(), uint256(raffle.getRaffleState())));
        raffle.performUpkeep("");
    }

    function testPerformUpkeepEmitsRandomWordsRequested() public {
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        
        vm.recordLogs();
        raffle.performUpkeep("");
        Vm.Log[] memory entries = vm.getRecordedLogs();


        bytes32 requestId ;
        bool found = false;

        for (uint256 i = 0; i < entries.length; i++) {
            if (entries[i].topics[0] == keccak256("RandomWordsRequested(uint256)")) {
                requestId = entries[i].topics[1];
                found = true;
                break;
            }
        }

        require(found, "RandomWordsRequested event not found");
        console2.logBytes32(requestId);

        assertGt(uint256(requestId), 0);
        
         
    }

    function testFulfillRandomWordsPicksAWinnerResetsAndSendsMoney() public {
        address expectedWinner = address(3);

        
        uint256 additionalEntrances = 3;
        uint256 startingIndex = 1; 

        for (uint256 i = startingIndex; i < startingIndex + additionalEntrances; i++) {
            address player = address(uint160(i));
            hoax(player, 1 ether); // deal 1 eth to the player
            raffle.enterRaffle{value: raffleEntranceFee}();
        }
        vm.warp(block.timestamp + raffle.getInterval() + 1);

        uint256 winnerStartingBalance = expectedWinner.balance;

        _triggerAndFulfillVrf();
        
        address recentWinner = raffle.getRecentWinner();
        Raffle.RaffleState raffleState = raffle.getRaffleState();
        uint256 winnerBalance = recentWinner.balance;
        
        uint256 prize = raffleEntranceFee * additionalEntrances ;
       
        assertEq(recentWinner, expectedWinner);
        assertEq(uint256(raffleState) , 0);
        assertEq(winnerBalance , winnerStartingBalance + prize);
        assertEq(raffle.getLengthOfPlayers(), 0);
        assertEq(address(raffle).balance, 0);
        
    }

    function testRaffleCanRunMultipleRounds() public{
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        
        _triggerAndFulfillVrf();

        assertEq(uint256(raffle.getRaffleState()),0);
        assertEq(raffle.getRecentWinner(), Bob);

/////////////////////////ROUND 2////////////////////////////

        vm.prank(Alice);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        
       _triggerAndFulfillVrf();

        assertEq(uint256(raffle.getRaffleState()),0);
        assertEq(raffle.getRecentWinner(), Alice);


    }

    function testCannotPerformUpkeepTwiceWhileCalculating() public {
        vm.prank(Bob);
        raffle.enterRaffle{value: raffleEntranceFee}();
        vm.warp(block.timestamp + raffle.getInterval() + 1);
        raffle.performUpkeep("");
        assertEq(uint256(raffle.getRaffleState()),1);
        vm.expectRevert(abi.encodeWithSelector(Raffle.Raffle__UpkeepNotNeeded.selector,address(raffle).balance, raffle.getLengthOfPlayers(), uint256(raffle.getRaffleState())));
        raffle.performUpkeep("");


    }
}