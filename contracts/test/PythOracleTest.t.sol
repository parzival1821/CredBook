// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {Test, console} from "forge-std/Test.sol";
import {PythOracle} from "../src/oracles/PythOracle.sol";
import {IPyth} from "@pythnetwork/pyth-sdk-solidity/IPyth.sol";
import {PythStructs} from "@pythnetwork/pyth-sdk-solidity/PythStructs.sol";

/**
 * @title PythOracleSepoliaTest
 * @notice Tests for deployed Pyth Oracle on Sepolia
 * @dev Set PYTH_ORACLE_ADDRESS in .env before running
 * 
 * Run with:
 * forge test --match-contract PythOracleSepolia --rpc-url $SEPOLIA_RPC_URL -vv
 */
contract PythOracleSepoliaTest is Test {
    PythOracle public oracle;
    address public oracleAddress;
    
    address public user = makeAddr("user");
    
    function setUp() public {
        // Use actual Sepolia, not a fork
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);
        
        // Get deployed oracle address
        oracleAddress = vm.envAddress("PYTH_ORACLE_ADDRESS");
        oracle = PythOracle(oracleAddress);
        
        console.log("=== Testing Deployed Oracle on Sepolia ===");
        console.log("Oracle Address:", oracleAddress);
        console.log("Block Number:", block.number);
    }
    
    function test_OracleExists() public view {
        // Verify oracle is deployed
        uint256 codeSize;
        assembly {
            codeSize := extcodesize(sload(oracleAddress.slot))
        }
        
        assertGt(codeSize, 0, "Oracle not deployed");
        console.log(" Oracle code size:", codeSize);
    }
    
    function test_OracleConfiguration() public view {
        console.log("\n=== Oracle Configuration ===");
        
        address pythContract = address(oracle.pyth());
        bytes32 priceId = oracle.priceId();
        uint256 decimals = oracle.baseDecimals();
        uint256 maxAge = oracle.MAX_AGE();
        
        console.log("Pyth Contract:", pythContract);
        console.log("Price Feed ID:", vm.toString(priceId));
        console.log("Decimals:", decimals);
        console.log("Max Age:", maxAge, "seconds");
        
        assertEq(pythContract, 0xDd24F84d36BF92C65F92307595335bdFab5Bbd21, "Wrong Pyth contract");
        assertEq(priceId, 0xff61491a931112ddf1bd8147cd1b641375f79f5825126d665480874634fd0ace, "Wrong price feed");
        assertEq(decimals, 36, "Wrong decimals");
        assertEq(maxAge, 60, "Wrong max age");
        
        console.log(" Configuration is correct");
    }
    
    function test_GetLatestPriceInfo() public view {
        console.log("\n=== Latest Price Info ===");
        
        try oracle.getLatestPrice() returns (int64 price, uint256 publishTime) {
            console.log("Price (raw):", uint256(uint64(price)));
            console.log("Publish Time:", publishTime);
            console.log("Current Time:", block.timestamp);
            
            uint256 age = block.timestamp - publishTime;
            console.log("Age:", age, "seconds");
            
            assertGt(price, 0, "Price should be positive");
            assertGt(publishTime, 0, "Publish time should be set");
            
            if (age <= 60) {
                console.log(" Price is FRESH (within MAX_AGE)");
            } else {
                console.log("Price is STALE - backend should update");
            }
        } catch Error(string memory reason) {
            console.log("getLatestPrice() failed:", reason);
            console.log("Price is too stale or backend hasn't updated");
        } catch {
            console.log("No price data available");
        }
    }
    
    function test_TryGetPrice() public view {
        console.log("\n=== Attempting to Get Price ===");
        
        try oracle.price() returns (uint256 currentPrice) {
            console.log("Price (36 decimals):", currentPrice);
            
            // Convert to USD
            uint256 priceUSD = currentPrice / 1e36;
            uint256 priceWithDecimals = (currentPrice / 1e34); // Show 2 decimal places
            
            console.log("Price in USD:", priceUSD);
            console.log("Price with decimals:", priceWithDecimals / 100, ".", priceWithDecimals % 100);
            
            // Price should be reasonable for ETH
            assertGt(priceUSD, 1000, "ETH price too low");
            assertLt(priceUSD, 10000, "ETH price too high");
            
            console.log(" Price is valid and fresh");
        } catch Error(string memory reason) {
            console.log("price() reverted:", reason);
            console.log("This means price is stale (> 60 seconds old)");
            console.log("Backend needs to call updatePrice()");
        } catch {
            console.log("price() reverted with no reason");
        }
    }
    
    function test_CheckPythContractWorks() public view {
        console.log("\n=== Testing Pyth Contract ===");
        
        IPyth pyth = oracle.pyth();
        bytes32 priceId = oracle.priceId();
        
        try pyth.getPriceNoOlderThan(priceId, 60) returns (PythStructs.Price memory pythPrice) {
            console.log("Pyth price (raw):", uint256(uint64(pythPrice.price)));
            console.log("Pyth expo:", int256(pythPrice.expo));
            console.log("Pyth conf:", pythPrice.conf);
            console.log("Pyth publish time:", pythPrice.publishTime);
            
            uint256 age = block.timestamp - pythPrice.publishTime;
            console.log("Age:", age, "seconds");
            
            console.log(" Pyth contract is working and price is fresh");
        } catch Error(string memory reason) {
            console.log("Pyth contract call failed:", reason);
            console.log("Price may be stale or feed not available");
        } catch {
            console.log("Pyth contract not returning data");
        }
    }
    
    function test_CalculateUpdateFee() public view {
        console.log("\n=== Update Fee Info ===");
        
        bytes[] memory mockData = new bytes[](1);
        mockData[0] = hex"";
        
        IPyth pyth = oracle.pyth();
        uint256 fee = pyth.getUpdateFee(mockData);
        
        console.log("Update fee:", fee, "wei");
        console.log("Update fee (ETH):", fee / 1e18);
        console.log("Update fee (gwei):", fee / 1e9);
        
        console.log(" Fee calculated successfully");
    }
    
    function test_UpdatePriceWithMockData() public {
        console.log("\n=== Testing Price Update Flow ===");
        
        bytes[] memory mockData = new bytes[](1);
        mockData[0] = hex"";
        
        vm.deal(user, 1 ether);
        uint256 balanceBefore = user.balance;
        
        console.log("User balance before:", balanceBefore);
        
        vm.prank(user);
        try oracle.updatePrice{value: 0.01 ether}(mockData) {
            console.log(" Update transaction succeeded");
            
            uint256 balanceAfter = user.balance;
            uint256 spent = balanceBefore - balanceAfter;
            console.log("Cost:", spent, "wei");
            
            // Try to get price
            try oracle.price() returns (uint256 newPrice) {
                console.log("New price:", newPrice / 1e36, "USD");
            } catch {
                console.log("Price still not available");
            }
        } catch Error(string memory reason) {
            console.log("Update failed:", reason);
            console.log("Expected with mock data - use real Pyth VAA data");
        } catch {
            console.log("Update failed");
            console.log("Mock data used - backend should use real Pyth API data");
        }
    }
}

/**
 * @title LiveMonitoringTest  
 * @notice Tests to monitor the deployed oracle's health
 */
contract LiveMonitoringTest is Test {
    PythOracle public oracle;
    
    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);
        
        address oracleAddress = vm.envAddress("PYTH_ORACLE_ADDRESS");
        oracle = PythOracle(oracleAddress);
    }
    
    function test_MonitorOracleHealth() public view {
        console.log("Oracle health check");
        console.log("");
        console.log("Timestamp:", block.timestamp);
        console.log("Block:", block.number);
        console.log("Oracle:", address(oracle));
        
        try oracle.getLatestPrice() returns (int64 price, uint256 publishTime) {
            uint256 age = block.timestamp - publishTime;
            uint256 priceUSD = uint256(uint64(price));
            
            console.log("\nCurrent Status:");
            console.log("  Price (raw):", priceUSD);
            console.log("  Published at:", publishTime);
            console.log("  Age:", age, "seconds");
            console.log("");
            
            // Status indicator
            if (age < 30) {
                console.log("  Status:  EXCELLENT");
                console.log("   Price is very fresh (< 30s)");
            } else if (age < 60) {
                console.log("  Status:  GOOD");
                console.log("   Price is fresh enough (< 60s)");
            } else if (age < 120) {
                console.log("  Status:  WARNING");
                console.log("   Price is getting stale (> 60s)");
                console.log("   Will revert on price() calls");
            } else {
                console.log("  Status:  CRITICAL");
                console.log("   Price is very stale (> 120s)");
                console.log("   Backend needs immediate attention!");
            }
            
            console.log("");
            
            // Check if price() would work
            try oracle.price() returns (uint256 currentPrice) {
                uint256 priceWithDecimals = currentPrice / 1e34;
                console.log(" price() is working");
                console.log("  Value(USD):", priceWithDecimals / 100, ".", priceWithDecimals % 100);
            } catch Error(string memory reason) {
                console.log("price() would revert");
                console.log("  Reason:", reason);
                console.log("   Price is older than MAX_AGE (60s)");
            } catch {
                console.log("price() would revert (unknown reason)");
            }
        } catch Error(string memory reason) {
            console.log("\nCRITICAL - Cannot get price");
            console.log("  Reason:", reason);
            console.log("   Backend has never updated OR");
            console.log("   Price is extremely stale");
        } catch {
            console.log("\nCRITICAL - No price data at all");
            console.log("   Backend initialization required");
        }
        
    }
    
    function test_BackendReadinessCheck() public view {
        console.log("\n=== Backend Readiness Check ===");
        
        bool canGetLatestPrice = false;
        bool canGetCurrentPrice = false;
        uint256 priceAge = type(uint256).max;
        
        // Test getLatestPrice
        try oracle.getLatestPrice() returns (int64, uint256 publishTime) {
            canGetLatestPrice = true;
            priceAge = block.timestamp - publishTime;
            console.log(" getLatestPrice() works");
            console.log("  Price age:", priceAge, "seconds");
        } catch {
            console.log("getLatestPrice() fails");
        }
        
        // Test price
        try oracle.price() returns (uint256) {
            canGetCurrentPrice = true;
            console.log(" price() works");
        } catch {
            console.log("price() fails");
        }
        
        console.log("\nSummary:");
        if (canGetLatestPrice && canGetCurrentPrice) {
            console.log("READY - Oracle is fully operational");
        } else if (canGetLatestPrice && !canGetCurrentPrice) {
            console.log("DEGRADED - Price exists but stale");
            console.log("   Backend should update more frequently");
        } else {
            console.log("NOT READY - Oracle needs initialization");
            console.log("   Start the backend to push first price");
        }
    }
    
    function test_CompareWithDirectPyth() public view {
        console.log("\n=== Comparing Oracle vs Direct Pyth ===");
        
        IPyth pyth = oracle.pyth();
        bytes32 priceId = oracle.priceId();
        
        console.log("Querying Pyth directly...");
        try pyth.getPriceNoOlderThan(priceId, 60) returns (PythStructs.Price memory pythPrice) {
            console.log("Direct Pyth:");
            console.log("  Price:", uint256(uint64(pythPrice.price))); // 398348008252 = 3983 * 1e8
            console.log("  Expo:", int256(pythPrice.expo));
            console.log("  Time:", pythPrice.publishTime);
        } catch {
            console.log("Direct Pyth query failed");
        }
        
        console.log("\nQuerying through our oracle...");
        try oracle.getLatestPrice() returns (int64 price, uint256 publishTime) {
            console.log("Our Oracle:");                                // 398348008252 = 3983 * 1e8
            console.log("  Price:", uint256(uint64(price)));
            console.log("  Time:", publishTime);
        } catch {
            console.log("Oracle query failed");
        }
        
        console.log("\nQuerying scaled price...");
        try oracle.price() returns (uint256 scaledPrice) {
            console.log("Scaled Price (36 decimals):");                // 3983480082520000000000000000000000000000 = 3983 * 1e36
            console.log("  Raw:", scaledPrice);
            console.log("  USD:", scaledPrice / 1e36);
        } catch {
            console.log("Scaled price not available (stale)");
        }
    }
}

/**
 * @title QuickHealthCheck
 * @notice Ultra-fast health check for monitoring scripts
 */
contract QuickHealthCheck is Test {
    function setUp() public {
        string memory rpcUrl = vm.envString("SEPOLIA_RPC_URL");
        vm.createSelectFork(rpcUrl);
    }
    
    function test_QuickCheck() public view {
        address oracleAddress = vm.envAddress("PYTH_ORACLE_ADDRESS");
        PythOracle oracle = PythOracle(oracleAddress);
        
        try oracle.getLatestPrice() returns (int64, uint256 publishTime) {
            uint256 age = block.timestamp - publishTime;
            
            if (age < 60) {
                console.log("OK - Age:", age, "s");
            } else {
                console.log("STALE - Age:", age, "s");
            }
        } catch {
            console.log("ERROR - No price");
        }
    }
}