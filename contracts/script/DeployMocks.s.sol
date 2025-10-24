// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Script.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockWETH.sol";

contract DeployTokens is Script {
    function run() external {
        vm.startBroadcast();
        
        MockUSDC usdc = new MockUSDC();
        MockWETH weth = new MockWETH();
        
        vm.stopBroadcast();
        
        console.log("USDC deployed at:", address(usdc));
        console.log("WETH deployed at:", address(weth));
    }
}