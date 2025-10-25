// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.21;

// import {Script} from "forge-std/Script.sol";
// import {Orderbook} from "../src/orderbook/Orderbook.sol";
// import {LendingPool} from "../src/lending-core/LendingPool.sol";
// import {LinearIRM} from "../src/lending-core/LinearIRM.sol";
// import {KinkIRM} from "../src/lending-core/KinkIRM.sol";
// import {console} from "forge-std/console.sol";

// contract DeployStage1 is Script {
//     // Sepolia token addresses
//     address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
//     address public constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
//     address public constant ORACLE = 0x0000000000000000000000000000000000000001;
//     uint256 public constant LLTV = 800000000000000000; // 80%
    
//     function run() external {
//         uint256 deployerPrivateKey = vm.envUint("PVT_KEY");
        
//         console.log("\n=== STAGE 1: Deploying Infrastructure & First 2 Pools ===");
        
//         vm.startBroadcast(deployerPrivateKey);
        
//         // Deploy Orderbook
//         Orderbook orderbook = new Orderbook();
//         console.log("Orderbook:", address(orderbook));
        
//         // Deploy IRMs
//         LinearIRM linearIRM1 = new LinearIRM();
//         LinearIRM linearIRM2 = new LinearIRM();
//         console.log("LinearIRM1:", address(linearIRM1));
//         console.log("LinearIRM2:", address(linearIRM2));
        
//         KinkIRM kinkIRM1 = new KinkIRM();
//         KinkIRM kinkIRM2 = new KinkIRM();
//         console.log("KinkIRM1:", address(kinkIRM1));
//         console.log("KinkIRM2:", address(kinkIRM2));
        
//         // Deploy Pool 0
//         LendingPool pool0 = new LendingPool();
//         pool0.createMarket(SEPOLIA_USDC, SEPOLIA_WETH, ORACLE, address(linearIRM1), LLTV, 1);
//         orderbook.registerPool(pool0, 1);
//         console.log("Pool 0:", address(pool0));
        
//         // Deploy Pool 1
//         LendingPool pool1 = new LendingPool();
//         pool1.createMarket(SEPOLIA_USDC, SEPOLIA_WETH, ORACLE, address(linearIRM2), LLTV, 2);
//         orderbook.registerPool(pool1, 2);
//         console.log("Pool 1:", address(pool1));
        
//         vm.stopBroadcast();
        
//         console.log("\n=== STAGE 1 COMPLETE ===");
//         console.log("\nCopy these for Stage 2:");
//         console.log("Orderbook:", address(orderbook));
//         console.log("KinkIRM1:", address(kinkIRM1));
//         console.log("KinkIRM2:", address(kinkIRM2));
//     }
// }

// contract DeployStage2 is Script {
//     address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
//     address public constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
//     address public constant ORACLE = 0x0000000000000000000000000000000000000001;
//     uint256 public constant LLTV = 800000000000000000;
    
//     function run(
//         address orderbookAddr,
//         address kinkIRM1Addr,
//         address kinkIRM2Addr
//     ) external {
//         uint256 deployerPrivateKey = vm.envUint("PVT_KEY");
        
//         console.log("\n=== STAGE 2: Deploying Pools 2 & 3 ===");
        
//         vm.startBroadcast(deployerPrivateKey);
        
//         Orderbook orderbook = Orderbook(orderbookAddr);
        
//         // Deploy Pool 2
//         LendingPool pool2 = new LendingPool(); 
//         pool2.createMarket(SEPOLIA_USDC, SEPOLIA_WETH, ORACLE, kinkIRM1Addr, LLTV, 3);
//         orderbook.registerPool(pool2, 3);
//         console.log("Pool 2:", address(pool2));
        
//         // Deploy Pool 3
//         LendingPool pool3 = new LendingPool();
//         pool3.createMarket(SEPOLIA_USDC, SEPOLIA_WETH, ORACLE, kinkIRM2Addr, LLTV, 4);
//         orderbook.registerPool(pool3, 4);
//         console.log("Pool 3:", address(pool3));
        
//         vm.stopBroadcast();
        
//         console.log("\n=== ALL DEPLOYMENTS COMPLETE ===");
//     }
// }
