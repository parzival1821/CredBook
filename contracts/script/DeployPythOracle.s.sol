// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {PythOracle} from "../src/oracles/PythOracle.sol";
import {console} from "forge-std/console.sol";

contract DeployPythOracle is Script {
    // Pyth contract on Sepolia
    address public constant PYTH_SEPOLIA = 0xDd24F84d36BF92C65F92307595335bdFab5Bbd21;
    
    // ETH/USD price feed ID
    bytes32 public constant ETH_USD_PRICE_ID = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    
    function run() external returns (address) {
        uint256 deployerPrivateKey = vm.envUint("PVT_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("=== Deploying Pyth Oracle ===");
        console.log("Deployer:", deployer);
        console.log("Balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        PythOracle oracle = new PythOracle{value : 0.1 ether}(
            PYTH_SEPOLIA,
            ETH_USD_PRICE_ID,
            24 // 36 decimals for our protocol
        );
        
        vm.stopBroadcast();
        
        console.log("\n=== Deployment Complete ===");
        console.log("Pyth Oracle:", address(oracle));
        console.log("Price Feed ID:", vm.toString(ETH_USD_PRICE_ID));
        console.log("Decimals: 36");
        
        return address(oracle);
    }
    
}