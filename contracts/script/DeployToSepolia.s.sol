// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {Credbook} from "../src/Credbook.sol";
import {Orderbook} from "../src/orderbook/Orderbook.sol";
import {LendingPool} from "../src/lending-core/LendingPool.sol";
import {LinearIRM} from "../src/lending-core/LinearIRM.sol";
import {KinkIRM} from "../src/lending-core/KinkIRM.sol";
import {console} from "forge-std/console.sol";

contract DeployToSepolia is Script {
    // Sepolia USDC and WETH addresses (or deploy mocks if testing)
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238; // Sepolia USDC
    address public constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14; // Sepolia WETH
    
    // If you want to use your own mock tokens instead:
    bool public constant USE_MOCK_TOKENS = false; // Set to true to deploy mock tokens
    
    struct DeploymentAddresses {
        address credbook;
        address orderbook;
        address usdc;
        address weth;
        address pool0;
        address pool1;
        address pool2;
        address pool3;
        address linearIRM1;
        address linearIRM2;
        address kinkIRM1;
        address kinkIRM2;
    }
    
    function run() external returns (DeploymentAddresses memory addresses) {
        uint256 deployerPrivateKey = vm.envUint("PVT_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        console.log("Deploying from:", deployer);
        console.log("Deployer balance:", deployer.balance);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // Determine which tokens to use
        if (USE_MOCK_TOKENS) {
            console.log("\n=== Deploying Mock Tokens ===");
            // Deploy mock tokens for testing
            // addresses.usdc = address(new MockUSDC());
            // addresses.weth = address(new MockWETH());
            // console.log("Mock USDC:", addresses.usdc);
            // console.log("Mock WETH:", addresses.weth);
        } else {
            addresses.usdc = SEPOLIA_USDC;
            addresses.weth = SEPOLIA_WETH;
            console.log("\n=== Using Existing Tokens ===");
            console.log("USDC:", addresses.usdc);
            console.log("WETH:", addresses.weth);
        }
        
        // Deploy Credbook (deploys everything internally)
        console.log("\n=== Deploying Credbook ===");
        Credbook credbook = new Credbook(addresses.usdc, addresses.weth);
        addresses.credbook = address(credbook);
        console.log("Credbook:", addresses.credbook);
        
        // Get orderbook address
        addresses.orderbook = credbook.getOrderbook();
        console.log("Orderbook:", addresses.orderbook);
        
        // Get pool addresses
        console.log("\n=== Pool Addresses ===");
        addresses.pool0 = credbook.getPool(0);
        addresses.pool1 = credbook.getPool(1);
        addresses.pool2 = credbook.getPool(2);
        addresses.pool3 = credbook.getPool(3);
        
        console.log("Pool 0 (LinearIRM1):", addresses.pool0);
        console.log("Pool 1 (LinearIRM2):", addresses.pool1);
        console.log("Pool 2 (KinkIRM1):", addresses.pool2);
        console.log("Pool 3 (KinkIRM2):", addresses.pool3);
        
        // Get IRM addresses
        console.log("\n=== IRM Addresses ===");
        addresses.linearIRM1 = address(credbook.linearIRM1());
        addresses.linearIRM2 = address(credbook.linearIRM2());
        addresses.kinkIRM1 = address(credbook.kinkIRM1());
        addresses.kinkIRM2 = address(credbook.kinkIRM2());
        
        console.log("LinearIRM1:", addresses.linearIRM1);
        console.log("LinearIRM2:", addresses.linearIRM2);
        console.log("KinkIRM1:", addresses.kinkIRM1);
        console.log("KinkIRM2:", addresses.kinkIRM2);
        
        vm.stopBroadcast();
        
        
        console.log("\n=== Deployment Complete ===");
        console.log("Save these addresses for the frontend!");
        
        return addresses;
    }
}