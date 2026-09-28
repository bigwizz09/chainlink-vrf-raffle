# Chainlink VRF Raffle

A decentralized raffle built with **Solidity and Foundry**, upgraded from a basic pseudo-random raffle to use **Chainlink VRF** for verifiable randomness and **Chainlink Automation** for automated winner selection.

The project demonstrates how a smart contract can manage a recurring raffle where players enter with ETH, Chainlink Automation determines when a round is ready, and Chainlink VRF supplies the randomness used to select the winner.

## Overview

The raffle follows this lifecycle:

```text
Player enters
     ↓
ETH is added to raffle balance
     ↓
Time interval passes
     ↓
Chainlink Automation checks upkeep
     ↓
performUpkeep()
     ↓
Raffle enters CALCULATING state
     ↓
Chainlink VRF request
     ↓
VRF Coordinator fulfills request
     ↓
fulfillRandomWords()
     ↓
Winner selected
     ↓
Winner receives entire raffle balance
     ↓
Players array is cleared
     ↓
Raffle returns to OPEN
```

## Features

* Players enter by paying a fixed entrance fee.
* Players cannot enter while a winner is being calculated.
* Direct ETH transfers to the raffle are rejected.
* Chainlink Automation determines when a raffle round is ready.
* Chainlink VRF provides the random number used to select the winner.
* The raffle enters a `CALCULATING` state while waiting for VRF.
* The winner receives the entire raffle balance.
* The player list is reset after every round.
* The same player can participate in multiple rounds.
* Custom errors are used for gas-efficient reverts.
* Local development uses Chainlink VRF mocks.
* Deployment configuration supports local Anvil and Ethereum networks.

## Technologies

* **Solidity `^0.8.30`**
* **Foundry**
* **Chainlink VRF V2.5**
* **Chainlink Automation**
* **OpenZeppelin**
* **Anvil**

## Project Structure

```text
ChainLink-VRF-Raffle/
│
├── src/
│   └── RaffleChainlinkVrf.sol
│
├── script/
│   ├── DeployRaffleChainlinkVrf.s.sol
│   ├── HelperConfig.s.sol
│   └── Interaction.s.sol
│
├── test/
│   └── RaffleChainlinkVrfTest.t.sol
│
├── lib/
│   ├── chainlink-evm/
│   ├── forge-std/
│   └── openzeppelin-contracts/
│
├── foundry.toml
├──  Makefile
└── README.md
```

## Raffle Contract

The main contract is:

```text
src/RaffleChainlinkVrf.sol
```

The contract inherits from:

```solidity
VRFConsumerBaseV2Plus
AutomationCompatibleInterface
```

This allows the raffle to interact with Chainlink VRF and Chainlink Automation.

### Raffle States

The raffle has two states:

```solidity
enum RaffleState {
    OPEN,
    CALCULATING
}
```

### OPEN

Players can enter the raffle by sending exactly the configured entrance fee.

### CALCULATING

The raffle is waiting for Chainlink VRF to provide a random number. New players cannot enter during this state.

Once the VRF callback is completed, the raffle returns to `OPEN`.

## Chainlink VRF

The contract requests randomness through the Chainlink VRF Coordinator.

The request contains configuration such as:

* VRF key hash
* Subscription ID
* Number of confirmations
* Callback gas limit
* Number of random words
* Native LINK payment configuration

The returned random word is used to select the winner:

```solidity
uint256 winnerIndex = randomWords[0] % s_players.length;
```

This separates the winner-selection randomness from block timestamp or block prevrandao-based randomness used in the original raffle.

## Chainlink Automation

The `checkUpkeep()` function determines whether the raffle is ready for another round.

Upkeep is required when:

* The raffle is `OPEN`
* The configured time interval has passed
* At least one player has entered
* The raffle has a balance

Conceptually:

```text
OPEN
+ enough time passed
+ players exist
+ balance exists
        ↓
   upkeepNeeded = true
```

When upkeep is performed:

```solidity
performUpkeep("")
```

the raffle changes to:

```text
CALCULATING
```

and requests randomness from Chainlink VRF.

## VRF Fulfillment

After the VRF Coordinator fulfills the request, Chainlink calls:

```solidity
fulfillRandomWords()
```

The function:

1. Uses the random word to determine the winner.
2. Changes the raffle back to `OPEN`.
3. Clears the player array.
4. Updates the recent winner.
5. Sends the raffle balance to the winner.
6. Emits the `WinnerPicked` event.

## Local Development

The project uses `VRFCoordinatorV2_5Mock` for local testing.

The local configuration automatically creates:

* A mock VRF Coordinator
* A mock LINK token
* A VRF subscription
* Funding for the subscription

This allows the entire VRF flow to be tested locally without interacting with the real Chainlink network.

## Testing

Run the complete test suite with:

```bash
forge test
```

The test suite covers the core raffle and Chainlink integration, including:

* Initial raffle balance
* Initial raffle state
* Entrance fee configuration
* Raffle interval configuration
* Player entry
* Multiple players
* Invalid entrance fees
* Raffle entry events
* Direct ETH transfer rejection
* Entry while raffle is calculating
* `checkUpkeep()` conditions
* `performUpkeep()` validation
* Transition from `OPEN` to `CALCULATING`
* VRF request generation
* `RandomWordsRequested` event
* VRF fulfillment
* Winner selection
* Winner payment
* Raffle balance reset
* Player list reset
* Transition from `CALCULATING` back to `OPEN`
* Multiple raffle rounds
* Prevention of multiple upkeep calls while calculating

### Example Test Flow

The helper function used by the tests demonstrates the complete local VRF lifecycle:

```text
performUpkeep()
      ↓
RandomWordsRequested
      ↓
requestId
      ↓
VRFCoordinatorV2_5Mock
      ↓
fulfillRandomWords()
      ↓
Raffle.fulfillRandomWords()
```

## Deployment

The deployment script is:

```text
script/DeployRaffleChainlinkVrf.s.sol
```

It:

1. Creates the `HelperConfig`.
2. Retrieves the configuration for the current chain.
3. Deploys the raffle.
4. Adds the raffle as a consumer of the VRF subscription.

The deployment script uses the network configuration supplied by `HelperConfig`.

## Network Configuration

`HelperConfig.s.sol` contains configuration for different environments.

The project distinguishes between:

```text
Local Anvil
Ethereum Sepolia
Ethereum Mainnet
```

For local development, the configuration creates the required Chainlink VRF mock infrastructure automatically.

For live networks, the configuration supplies the appropriate:

* VRF Coordinator
* Key hash
* Subscription ID
* Callback gas limit
* LINK token
* Deployment account

Sensitive credentials should not be committed to the repository.

## Interaction Script

The interaction logic for adding the raffle as a VRF consumer is contained in:

```text
script/Interaction.s.sol
```

The deployment process calls:

```solidity
addConsumer(
    address(raffle),
    config.vrfCoordinatorV2,
    config._subId,
    config._account
);
```

This allows the deployed raffle contract to receive VRF callbacks from the subscription.

## Custom Errors

The raffle uses custom errors including:

```solidity
Raffle__ValueMustBeEqualToEntranceFee()
Raffle__NotEnoughPlayers()
Raffle__EthTransferFailed()
Raffle__RaffleIsNotOpen()
Raffle__UpkeepNotNeeded(...)
```

These provide explicit failure conditions while avoiding the additional gas cost associated with long revert strings.

## Events

The contract emits events for important raffle activity:

```solidity
event RaffleEntered(address indexed _player);
event WinnerPicked(address indexed _winner);
event RandomWordsRequested(uint256 indexed requestId);
```

These events make it possible for external applications and monitoring systems to track raffle activity.

## Learning Objectives

This project was built to understand and practice:

* Solidity smart-contract development
* Foundry project structure
* Foundry unit testing
* Foundry cheatcodes
* Contract deployment scripts
* Network configuration
* Chainlink VRF V2.5
* Chainlink Automation
* VRF subscriptions
* VRF Coordinator mocks
* Events and indexed parameters
* Custom errors
* Contract state machines
* ETH transfers
* Multi-round contract design
* Testing asynchronous VRF workflows

## Development Notes

This project is intended as a learning and portfolio project demonstrating the integration of Chainlink services with a Solidity smart contract.

The randomness and automation architecture is designed around Chainlink VRF and Chainlink Automation rather than relying on block properties as the source of randomness.

## License

This project is licensed under the MIT License.
