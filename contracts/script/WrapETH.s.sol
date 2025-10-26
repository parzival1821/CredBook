// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";

interface IWETH {
    function deposit() external payable;
    function withdraw(uint256) external;
    function balanceOf(address) external view returns (uint256);
}

contract WrapETH is Script {
    address public constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    
    function run() external {
        uint256 privateKey = vm.envUint("PVT_KEY");
        address user = vm.addr(privateKey);
        
        // Amount to wrap (default 0.1 ETH, change as needed)
        uint256 amountToWrap = 0.1 ether;
        
        IWETH weth = IWETH(SEPOLIA_WETH);
        
        console.log("=== Wrapping ETH to WETH ===");
        console.log("User:", user);
        console.log("ETH Balance:", user.balance / 1e18, "ETH");
        console.log("WETH Balance before:", weth.balanceOf(user) / 1e18, "WETH");
        console.log("Amount to wrap:", amountToWrap / 1e18, "ETH");
        
        require(user.balance >= amountToWrap, "Insufficient ETH balance");
        
        vm.startBroadcast(privateKey);
        
        // Wrap ETH to WETH
        weth.deposit{value: amountToWrap}();
        
        vm.stopBroadcast();
        
        console.log("\n=== Success ===");
        console.log("WETH Balance after:", weth.balanceOf(user) / 1e18, "WETH");
    }
}