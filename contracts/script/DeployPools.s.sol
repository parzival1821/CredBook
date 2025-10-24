// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Script} from "forge-std/Script.sol";
import {LendingPool} from "../src/lending-core/LendingPool.sol";
import {LinearIRM} from "../src/lending-core/LinearIRM.sol";
import {KinkIRM} from "../src/lending-core/KinkIRM.sol";
import {MarketParams} from "../src/interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract DeployPools is Script {
    uint256 constant WAD = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    address public USDC;
    address public WETH;
    address public deployer;
    
    LendingPool public pool1;
    LendingPool public pool2;
    LendingPool public pool3;
    LendingPool public pool4;
    
    LinearIRM public linearIRM1;
    LinearIRM public linearIRM2;
    KinkIRM public kinkIRM1;
    KinkIRM public kinkIRM2;
    
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PVT_KEY");
        deployer = vm.addr(deployerPrivateKey);
        
        USDC = vm.envAddress("USDC_ADDR");
        WETH = vm.envAddress("WETH_ADDR");
        
        vm.startBroadcast(deployerPrivateKey);
        
        deployIRMs();
        deployPools();
        createMarkets();
        addLiquidity();
        
        vm.stopBroadcast();
        
        logAddresses();
    }
    
    function deployIRMs() internal {
        // Linear IRM 1: 2% → 15% APY
        linearIRM1 = new LinearIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (13 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        // Linear IRM 2: 5% → 30% APY
        linearIRM2 = new LinearIRM(
            (5 * WAD / 100) / SECONDS_PER_YEAR,
            (25 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        // Kink IRM 1: 1% → 10% @ 80%, then 10% → 80% @ 100%
        kinkIRM1 = new KinkIRM(
            (1 * WAD / 100) / SECONDS_PER_YEAR,
            (80 * WAD) / 100,
            (1125 * WAD / 10000) / SECONDS_PER_YEAR,
            (350 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        // Kink IRM 2: 2% → 12% @ 90%, then 12% → 150% @ 100%
        kinkIRM2 = new KinkIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (90 * WAD) / 100,
            (1111 * WAD / 10000) / SECONDS_PER_YEAR,
            (1380 * WAD / 100) / SECONDS_PER_YEAR
        );
    }
    
    function deployPools() internal {
        pool1 = new LendingPool();
        pool2 = new LendingPool();
        pool3 = new LendingPool();
        pool4 = new LendingPool();
    }
    
    function createMarkets() internal {
        MarketParams memory params1 = _createMarketParams(address(linearIRM1));
        pool1.createMarket(params1, 1);
        
        MarketParams memory params2 = _createMarketParams(address(linearIRM2));
        pool2.createMarket(params2, 2);
        
        MarketParams memory params3 = _createMarketParams(address(kinkIRM1));
        pool3.createMarket(params3, 3);
        
        MarketParams memory params4 = _createMarketParams(address(kinkIRM2));
        pool4.createMarket(params4, 4);
    }
    
    function _createMarketParams(address irm) internal view returns (MarketParams memory) {
        return MarketParams({
            loanToken: USDC,
            collateralToken: WETH,
            oracle: address(1),
            irm: irm,
            lltv: 800000000000000000
        });
    }
    
    function addLiquidity() internal {
        uint256 liquidityAmount = 100_000 * 1e6; // USDC has 6 decimals
        
        _supplyToPool(pool1, 1, liquidityAmount);
        _supplyToPool(pool2, 2, liquidityAmount);
        _supplyToPool(pool3, 3, liquidityAmount);
        _supplyToPool(pool4, 4, liquidityAmount);
    }
    
    function _supplyToPool(LendingPool pool, uint256 id, uint256 amount) internal {
        IERC20(USDC).approve(address(pool), amount);
        pool.supply(id, amount, 0, deployer, "");
    }
    
    function logAddresses() internal view {
        console.log("LinearIRM1:", address(linearIRM1));
        console.log("LinearIRM2:", address(linearIRM2));
        console.log("KinkIRM1:", address(kinkIRM1));
        console.log("KinkIRM2:", address(kinkIRM2));
        console.log("Pool1:", address(pool1));
        console.log("Pool2:", address(pool2));
        console.log("Pool3:", address(pool3));
        console.log("Pool4:", address(pool4));
    }
}