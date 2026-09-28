// SPDX-License-Identifier: MIT
pragma solidity ^0.8.30;

import {Script} from "forge-std/Script.sol";
import {VRFCoordinatorV2_5Mock} from "@chainlink/src/v0.8/vrf/mocks/VRFCoordinatorV2_5Mock.sol";
import {LinkToken} from "@chainlink/src/v0.8/shared/token/ERC677/LinkToken.sol";

abstract contract CodeConstants {
    uint96 public constant MOCK_BASE_FEE = 0.25 ether;
    uint96 public constant MOCK_GAS_PRICE = 1 gwei;
    int256 public constant MOCK_WEI_PER_UNIT_LINK = 0.004 ether;
    uint96 public constant FUND_AMOUNT = 140 ether;
   
    address public constant FOUNDRY_DEFAULT_SENDER = 0x1804c8AB1F12E6bbf3894d4083f33e07309d1f38;
    uint256 public constant ETH_SEPOLIA_CHAIN_ID = 11155111;
    uint256 public constant ETH_MAINNET_CHAIN_ID = 1;
    uint256 public constant LOCAL_CHAIN_ID = 31337;
}


contract HelperConfig is Script, CodeConstants {

    error HelperConfig__InvalidChainId();


    struct NetworkConfig {
        uint256 _interval;
        uint256 _entranceFee;
        bytes32 _keyHash; 
        uint256 _subId; 
        uint32 _callbackGasLimit;
        address vrfCoordinatorV2;
        address _account;
        address _link;
    }

    NetworkConfig public localNetworkConfig;
    mapping(uint256 chainId => NetworkConfig) public networkConfigs;

    constructor(){
        networkConfigs[ETH_SEPOLIA_CHAIN_ID] = getSepoliaEthConfig();
        networkConfigs[ETH_MAINNET_CHAIN_ID] = getMainnetEthConfig();
        
    }

    function getConfig() public returns (NetworkConfig memory){
        return getConfigByChainId(block.chainid);
    }

    function setConfig(
        uint256 chainId,
        NetworkConfig memory networkConfig
    ) public {
        networkConfigs[chainId] = networkConfig;
    }

    function getConfigByChainId(uint256 chainId) public returns(NetworkConfig memory) {
        if(networkConfigs[chainId].vrfCoordinatorV2 != address(0)){
            return networkConfigs[chainId];
        } else if (chainId == LOCAL_CHAIN_ID){
            return getOrCreateAnvilEthConfig() ;
        }else{
            revert HelperConfig__InvalidChainId();
        }

    }

    function getMainnetEthConfig() public pure returns(NetworkConfig memory mainnetNetworkConfig){
        mainnetNetworkConfig = NetworkConfig({
            _interval: 30,
            _entranceFee: 0.01 ether,
            _keyHash: 0x8077df514608a09f83e4e8d300645594e5d7234665448ba83f51a50f842bd3d9, 
            _subId: 0, 
            _callbackGasLimit: 2500000,
            vrfCoordinatorV2: 0xD7f86b4b8Cae7D942340FF628F82735b7a20893a,
            _account: 0xf600E18682435dAD6a82E8c2E1524B1a3e26866f,
            _link:0x514910771AF9Ca656af840dff83E8264EcF986CA
            
        });
    }

    function getSepoliaEthConfig() public pure returns(NetworkConfig memory sepoliaNetworkConfig){
        sepoliaNetworkConfig = NetworkConfig({
            _interval: 30,
            _entranceFee: 0.01 ether,
            _keyHash: 0x787d74caea10b2b357790d5b5247c2f63d1d91572a9846f780606e4d953677ae, 
            _subId: 88930392720750601002082206221895273120545137434455338599355747171524466466432, 
            _callbackGasLimit: 40000,
            vrfCoordinatorV2: 0x9DdfaCa8183c41ad55329BdeeD9F6A8d53168B1B,
            _account: 0xf600E18682435dAD6a82E8c2E1524B1a3e26866f,//nothing for now
            _link:0x779877A7B0D9E8603169DdbD7836e478b4624789//nothing for now
        });
    }

    function getOrCreateAnvilEthConfig() public returns (NetworkConfig memory) {
        

        


         if (localNetworkConfig.vrfCoordinatorV2 != address(0)) {
            return localNetworkConfig;
        }

        
        vm.startBroadcast();
        VRFCoordinatorV2_5Mock vrfCoordinatorV2_5Mock = new VRFCoordinatorV2_5Mock(
                MOCK_BASE_FEE,
                MOCK_GAS_PRICE,
                MOCK_WEI_PER_UNIT_LINK
            );

        uint256 subId = vrfCoordinatorV2_5Mock.createSubscription();
        LinkToken linkToken = new LinkToken();
        vrfCoordinatorV2_5Mock.fundSubscription(subId, FUND_AMOUNT);

        vm.stopBroadcast();


        
        localNetworkConfig = NetworkConfig({
            _interval: 30,
            _entranceFee: 0.01 ether,
            _keyHash: 0x0000000000000000000000000000000000000000000000000000000000000000, 
            _subId: subId, 
            _callbackGasLimit: 500000,
            vrfCoordinatorV2: address(vrfCoordinatorV2_5Mock),
            _account:FOUNDRY_DEFAULT_SENDER,
            _link:address(linkToken)
            

        });

        vm.deal(localNetworkConfig._account, 100 ether);
        return localNetworkConfig;
    }
}