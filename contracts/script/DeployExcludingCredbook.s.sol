// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {Orderbook} from "../src/orderbook/Orderbook.sol";
import {LendingPool} from "../src/lending-core/LendingPool.sol";
import {LinearIRM} from "../src/lending-core/LinearIRM.sol";
import {KinkIRM} from "../src/lending-core/KinkIRM.sol";
import {MarketParams} from "../src/interfaces/IMorpho.sol";
import {console} from "forge-std/console.sol";

contract DeployExcludingCredbook is Script {
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    
    uint256 constant WAD = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PVT_KEY");
        
        console.log("=== STEP 1: Deploy Orderbook ===");
        vm.broadcast(deployerPrivateKey);
        Orderbook orderbook = new Orderbook(SEPOLIA_USDC, SEPOLIA_WETH);
        console.log("Orderbook:", address(orderbook));
        
        console.log("\n=== STEP 2: Deploy IRMs ===");
        vm.broadcast(deployerPrivateKey);
        LinearIRM linearIRM1 = new LinearIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (13 * WAD / 100) / SECONDS_PER_YEAR
        );
        console.log("LinearIRM1:", address(linearIRM1));
        
        vm.broadcast(deployerPrivateKey);
        LinearIRM linearIRM2 = new LinearIRM(
            (5 * WAD / 100) / SECONDS_PER_YEAR,
            (25 * WAD / 100) / SECONDS_PER_YEAR
        );
        console.log("LinearIRM2:", address(linearIRM2));
        
        vm.broadcast(deployerPrivateKey);
        KinkIRM kinkIRM1 = new KinkIRM(
            (1 * WAD / 100) / SECONDS_PER_YEAR,
            (80 * WAD) / 100,
            (1125 * WAD / 10000) / SECONDS_PER_YEAR,
            (350 * WAD / 100) / SECONDS_PER_YEAR
        );
        console.log("KinkIRM1:", address(kinkIRM1));
        
        vm.broadcast(deployerPrivateKey);
        KinkIRM kinkIRM2 = new KinkIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (90 * WAD) / 100,
            (1111 * WAD / 10000) / SECONDS_PER_YEAR,
            (1380 * WAD / 100) / SECONDS_PER_YEAR
        );
        console.log("KinkIRM2:", address(kinkIRM2));
        
        console.log("\n=== STEP 3: Deploy Pools ===");
        vm.broadcast(deployerPrivateKey);
        LendingPool pool0 = new LendingPool();
        console.log("Pool 0:", address(pool0));
        
        vm.broadcast(deployerPrivateKey);
        LendingPool pool1 = new LendingPool();
        console.log("Pool 1:", address(pool1));
        
        vm.broadcast(deployerPrivateKey);
        LendingPool pool2 = new LendingPool();
        console.log("Pool 2:", address(pool2));
        
        vm.broadcast(deployerPrivateKey);
        LendingPool pool3 = new LendingPool();
        console.log("Pool 3:", address(pool3));
        
        console.log("\n=== STEP 4: Create Markets ===");
        
        MarketParams memory params0 = MarketParams({
            loanToken: SEPOLIA_USDC,
            collateralToken: SEPOLIA_WETH,
            oracle: address(1),
            irm: address(linearIRM1),
            lltv: 800000000000000000
        });
        vm.broadcast(deployerPrivateKey);
        pool0.createMarket(params0, 1);
        
        MarketParams memory params1 = MarketParams({
            loanToken: SEPOLIA_USDC,
            collateralToken: SEPOLIA_WETH,
            oracle: address(1),
            irm: address(linearIRM2),
            lltv: 800000000000000000
        });
        vm.broadcast(deployerPrivateKey);
        pool1.createMarket(params1, 2);
        
        MarketParams memory params2 = MarketParams({
            loanToken: SEPOLIA_USDC,
            collateralToken: SEPOLIA_WETH,
            oracle: address(1),
            irm: address(kinkIRM1),
            lltv: 800000000000000000
        });
        vm.broadcast(deployerPrivateKey);
        pool2.createMarket(params2, 3);
        
        MarketParams memory params3 = MarketParams({
            loanToken: SEPOLIA_USDC,
            collateralToken: SEPOLIA_WETH,
            oracle: address(1),
            irm: address(kinkIRM2),
            lltv: 800000000000000000
        });
        vm.broadcast(deployerPrivateKey);
        pool3.createMarket(params3, 4);
        
        console.log("\n=== STEP 5: Register Pools with Orderbook ===");
        vm.broadcast(deployerPrivateKey);
        orderbook.registerPool(address(pool0), 1);
        
        vm.broadcast(deployerPrivateKey);
        orderbook.registerPool(address(pool1), 2);
        
        vm.broadcast(deployerPrivateKey);
        orderbook.registerPool(address(pool2), 3);
        
        vm.broadcast(deployerPrivateKey);
        orderbook.registerPool(address(pool3), 4);
        
        console.log("\n===  Deployment Complete ===");
        console.log("\n ADDRESSES FOR FRONTEND:");
        console.log("Orderbook:  ", address(orderbook));
        console.log("USDC:       ", SEPOLIA_USDC);
        console.log("WETH:       ", SEPOLIA_WETH);
        console.log("Pool 0:     ", address(pool0), " (LinearIRM1)");
        console.log("Pool 1:     ", address(pool1), " (LinearIRM2)");
        console.log("Pool 2:     ", address(pool2), " (KinkIRM1)");
        console.log("Pool 3:     ", address(pool3), " (KinkIRM2)");
    }

}