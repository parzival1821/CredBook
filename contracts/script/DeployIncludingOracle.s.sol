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

contract DeployToSepolia is Script {
    address public constant SEPOLIA_USDC = 0x1c7D4B196Cb0C7B01d743Fbc6116a902379C7238;
    address public constant SEPOLIA_WETH = 0xfFf9976782d46CC05630D1f6eBAb18b2324d6B14;
    address public constant PYTH_SEPOLIA = 0xDd24F84d36BF92C65F92307595335bdFab5Bbd21;
    bytes32 public constant ETH_USD_PRICE_ID = 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace;
    
    uint256 constant WAD = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    struct Contracts {
        PythOracle pythOracle;
        Orderbook orderbook;
        LinearIRM linearIRM1;
        LinearIRM linearIRM2;
        KinkIRM kinkIRM1;
        KinkIRM kinkIRM2;
        LendingPool pool0;
        LendingPool pool1;
        LendingPool pool2;
        LendingPool pool3;
    }
    
    function run() external {
        uint256 key = vm.envUint("PVT_KEY");
        
        Contracts memory c;
        
        // Deploy core contracts
        c = _deployCore(key);
        
        // Create markets
        _createMarkets(key, c);
        
        // Register pools
        _registerPools(key, c);
        
    }
    
    function _deployCore(uint256 key) internal returns (Contracts memory c) {
        console.log("=== Deploying Core Contracts ===");
        
        vm.broadcast(key);
        c.pythOracle = new PythOracle(PYTH_SEPOLIA, ETH_USD_PRICE_ID, 36);
        console.log("Pyth Oracle:", address(c.pythOracle));
        
        vm.broadcast(key);
        c.orderbook = new Orderbook(SEPOLIA_USDC, SEPOLIA_WETH);
        console.log("Orderbook:", address(c.orderbook));
        
        vm.broadcast(key);
        c.linearIRM1 = new LinearIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (13 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        vm.broadcast(key);
        c.linearIRM2 = new LinearIRM(
            (5 * WAD / 100) / SECONDS_PER_YEAR,
            (25 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        vm.broadcast(key);
        c.kinkIRM1 = new KinkIRM(
            (1 * WAD / 100) / SECONDS_PER_YEAR,
            (80 * WAD) / 100,
            (1125 * WAD / 10000) / SECONDS_PER_YEAR,
            (350 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        vm.broadcast(key);
        c.kinkIRM2 = new KinkIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (90 * WAD) / 100,
            (1111 * WAD / 10000) / SECONDS_PER_YEAR,
            (1380 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        vm.broadcast(key);
        c.pool0 = new LendingPool();
        
        vm.broadcast(key);
        c.pool1 = new LendingPool();
        
        vm.broadcast(key);
        c.pool2 = new LendingPool();
        
        vm.broadcast(key);
        c.pool3 = new LendingPool();
        
        console.log("IRMs and Pools deployed");
    }
    
    function _createMarkets(uint256 key, Contracts memory c) internal {
        console.log("\n=== Creating Markets ===");
        
        vm.broadcast(key);
        c.pool0.createMarket(_getMarketParams(c.pythOracle, address(c.linearIRM1)), 1);
        
        vm.broadcast(key);
        c.pool1.createMarket(_getMarketParams(c.pythOracle, address(c.linearIRM2)), 2);
        
        vm.broadcast(key);
        c.pool2.createMarket(_getMarketParams(c.pythOracle, address(c.kinkIRM1)), 3);
        
        vm.broadcast(key);
        c.pool3.createMarket(_getMarketParams(c.pythOracle, address(c.kinkIRM2)), 4);
        
        console.log("Markets created");
    }
    
    function _registerPools(uint256 key, Contracts memory c) internal {
        console.log("\n=== Registering Pools ===");
        
        vm.broadcast(key);
        c.orderbook.registerPool(address(c.pool0), 1);
        
        vm.broadcast(key);
        c.orderbook.registerPool(address(c.pool1), 2);
        
        vm.broadcast(key);
        c.orderbook.registerPool(address(c.pool2), 3);
        
        vm.broadcast(key);
        c.orderbook.registerPool(address(c.pool3), 4);
        
        console.log("Pools registered");
    }
    
    function _getMarketParams(
        PythOracle oracle,
        address irm
    ) internal view returns (MarketParams memory) {
        return MarketParams({
            loanToken: SEPOLIA_USDC,
            collateralToken: SEPOLIA_WETH,
            oracle: address(oracle),
            irm: irm,
            lltv: 800000000000000000
        });
    }
    
    function _logAndSave(Contracts memory c) internal {
        console.log("\n=== Deployment Complete ===");
        console.log("Pyth Oracle:", address(c.pythOracle));
        console.log("Orderbook:", address(c.orderbook));
        console.log("Pool 0:", address(c.pool0));
        console.log("Pool 1:", address(c.pool1));
        console.log("Pool 2:", address(c.pool2));
        console.log("Pool 3:", address(c.pool3));
        
        string memory json = string(abi.encodePacked(
            '{"pythOracle":"', _addr(address(c.pythOracle)),
            '","orderbook":"', _addr(address(c.orderbook)),
            '","usdc":"', _addr(SEPOLIA_USDC),
            '","weth":"', _addr(SEPOLIA_WETH),
            '","pool0":"', _addr(address(c.pool0)),
            '","pool1":"', _addr(address(c.pool1)),
            '","pool2":"', _addr(address(c.pool2)),
            '","pool3":"', _addr(address(c.pool3)), '"}'
        ));
        
        vm.writeFile("deployments/sepolia.json", json);
    }
    
    function _addr(address a) internal pure returns (string memory) {
        bytes memory s = new bytes(40);
        for (uint i = 0; i < 20; i++) {
            bytes1 b = bytes1(uint8(uint(uint160(a)) / (2**(8*(19-i)))));
            bytes1 hi = bytes1(uint8(b) / 16);
            bytes1 lo = bytes1(uint8(b) - 16 * uint8(hi));
            s[2*i] = _char(hi);
            s[2*i+1] = _char(lo);
        }
        return string(abi.encodePacked("0x", string(s)));
    }
    
    function _char(bytes1 b) internal pure returns (bytes1 c) {
        if (uint8(b) < 10) return bytes1(uint8(b) + 0x30);
        else return bytes1(uint8(b) + 0x57);
    }
}