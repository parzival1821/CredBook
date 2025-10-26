// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {Orderbook} from "../src/orderbook/Orderbook.sol";
import {LendingPool} from "../src/lending-core/LendingPool.sol";
import {LinearIRM} from "../src/lending-core/LinearIRM.sol";
import {KinkIRM} from "../src/lending-core/KinkIRM.sol";
import {PythOracle} from "../src/oracles/PythOracle.sol";
import {MarketParams} from "../src/interfaces/IMorpho.sol";
import {console} from "forge-std/console.sol";

contract DeployExcludingCredbook is Script {
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant PYTH_SEPOLIA = 0xDd24F84d36BF92C65F92307595335bdFab5Bbd21;
    bytes32 public constant ETH_USD_PRICE_ID = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    
    uint256 constant WAD = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    struct Deployments {
        PythOracle oracle;
        Orderbook orderbook;
        LendingPool pool0;
        LendingPool pool1;
        LendingPool pool2;
        LendingPool pool3;
    }
    
    function run() external {
        uint256 key = vm.envUint("PVT_KEY");
        
        Deployments memory d;
        
        d.oracle = _deployOracle(key);
        d.orderbook = _deployOrderbook(key);
        
        (LinearIRM irm1, LinearIRM irm2, KinkIRM kirm1, KinkIRM kirm2) = _deployIRMs(key);
        
        d = _deployPools(key, d);
        
        _createMarkets(key, d, irm1, irm2, kirm1, kirm2);
        
        _registerPools(key, d);
        
        _logAddresses(d);
    }
    
    function _deployOracle(uint256 key) internal returns (PythOracle) {
        console.log("Deploying Pyth Oracle");
        vm.broadcast(key);
        PythOracle oracle = new PythOracle(PYTH_SEPOLIA, ETH_USD_PRICE_ID, 36);
        console.log("Oracle:", address(oracle));
        return oracle;
    }
    
    function _deployOrderbook(uint256 key) internal returns (Orderbook) {
        console.log("\nDeploying Orderbook");
        vm.broadcast(key);
        Orderbook ob = new Orderbook(SEPOLIA_USDC, SEPOLIA_WETH);
        console.log("Orderbook:", address(ob));
        return ob;
    }
    
    function _deployIRMs(uint256 key) internal returns (
        LinearIRM irm1,
        LinearIRM irm2,
        KinkIRM kirm1,
        KinkIRM kirm2
    ) {
        console.log("\nDeploying IRMs");
        
        vm.broadcast(key);
        irm1 = new LinearIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (13 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        vm.broadcast(key);
        irm2 = new LinearIRM(
            (5 * WAD / 100) / SECONDS_PER_YEAR,
            (25 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        vm.broadcast(key);
        kirm1 = new KinkIRM(
            (1 * WAD / 100) / SECONDS_PER_YEAR,
            (80 * WAD) / 100,
            (1125 * WAD / 10000) / SECONDS_PER_YEAR,
            (350 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        vm.broadcast(key);
        kirm2 = new KinkIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (90 * WAD) / 100,
            (1111 * WAD / 10000) / SECONDS_PER_YEAR,
            (1380 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        console.log("IRMs deployed");
    }
    
    function _deployPools(uint256 key, Deployments memory d) internal returns (Deployments memory) {
        console.log("\nDeploying Pools");
        
        vm.broadcast(key);
        d.pool0 = new LendingPool();
        
        vm.broadcast(key);
        d.pool1 = new LendingPool();
        
        vm.broadcast(key);
        d.pool2 = new LendingPool();
        
        vm.broadcast(key);
        d.pool3 = new LendingPool();
        
        console.log("Pools deployed");
        return d;
    }
    
    function _createMarkets(
        uint256 key,
        Deployments memory d,
        LinearIRM irm1,
        LinearIRM irm2,
        KinkIRM kirm1,
        KinkIRM kirm2
    ) internal {
        console.log("\nCreating Markets");
        
        vm.broadcast(key);
        d.pool0.createMarket(_params(address(d.oracle), address(irm1)), 1);
        
        vm.broadcast(key);
        d.pool1.createMarket(_params(address(d.oracle), address(irm2)), 2);
        
        vm.broadcast(key);
        d.pool2.createMarket(_params(address(d.oracle), address(kirm1)), 3);
        
        vm.broadcast(key);
        d.pool3.createMarket(_params(address(d.oracle), address(kirm2)), 4);
        
        console.log("Markets created");
    }
    
    function _registerPools(uint256 key, Deployments memory d) internal {
        console.log("\nRegistering Pools");
        
        vm.broadcast(key);
        d.orderbook.registerPool(address(d.pool0), 1);
        
        vm.broadcast(key);
        d.orderbook.registerPool(address(d.pool1), 2);
        
        vm.broadcast(key);
        d.orderbook.registerPool(address(d.pool2), 3);
        
        vm.broadcast(key);
        d.orderbook.registerPool(address(d.pool3), 4);
        
        console.log("Pools registered");
    }
    
    function _params(address oracle, address irm) internal pure returns (MarketParams memory) {
        return MarketParams({
            loanToken: SEPOLIA_USDC,
            collateralToken: SEPOLIA_WETH,
            oracle: oracle,
            irm: irm,
            lltv: 800000000000000000
        });
    }
    
    function _logAddresses(Deployments memory d) internal view {
        console.log("\n=== Deployment Complete ===");
        console.log("Pyth Oracle:", address(d.oracle));
        console.log("Orderbook:", address(d.orderbook));
        console.log("Pool 0:", address(d.pool0));
        console.log("Pool 1:", address(d.pool1));
        console.log("Pool 2:", address(d.pool2));
        console.log("Pool 3:", address(d.pool3));
    }
}