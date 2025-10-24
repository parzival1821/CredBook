// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import {LendingPool, WAD, SECONDS_PER_YEAR} from "../src/lending-core/LendingPool.sol";
import "../src/lending-core/LinearIRM.sol";
import "../src/lending-core/KinkIRM.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockWETH.sol";
import {MarketParams, Market} from "../src/interfaces/IMorpho.sol";
import {console} from "forge-std/console.sol";

contract LendingPoolTest is Test {
    LendingPool public pool1;
    LendingPool public pool2;
    LendingPool public pool3;
    LendingPool public pool4;
    
    LinearIRM public linearIRM1;
    LinearIRM public linearIRM2;
    KinkIRM public kinkIRM1;
    KinkIRM public kinkIRM2;
    
    MockUSDC public usdc;
    MockWETH public weth;
    
    address public lender = address(0x1);
    address public borrower = address(0x2);
    
    function setUp() public {
        // Deploy tokens
        usdc = new MockUSDC();
        weth = new MockWETH();
        
        // Deploy IRMs
        deployIRMs();
        
        // Deploy pools
        pool1 = new LendingPool();
        pool2 = new LendingPool();
        pool3 = new LendingPool();
        pool4 = new LendingPool();
        
        // Create markets
        createMarkets();
        
        // Setup test accounts
        usdc.mint(lender, 500_000 * 1e6); // 500k USDC to lender 
        weth.mint(borrower, 100 * 1e18); // 100 WETH to borrower
        
        // Add initial liquidity
        vm.startPrank(lender);
        usdc.approve(address(pool1), type(uint256).max);
        usdc.approve(address(pool2), type(uint256).max);
        usdc.approve(address(pool3), type(uint256).max);
        usdc.approve(address(pool4), type(uint256).max);
        
        pool1.supply(1, 100_000 * 1e6, 0, lender, "");
        pool2.supply(2, 100_000 * 1e6, 0, lender, "");
        pool3.supply(3, 100_000 * 1e6, 0, lender, "");
        pool4.supply(4, 100_000 * 1e6, 0, lender, "");
        vm.stopPrank();
    }
    
    function deployIRMs() internal {
        linearIRM1 = new LinearIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (13 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        linearIRM2 = new LinearIRM(
            (5 * WAD / 100) / SECONDS_PER_YEAR,
            (25 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        kinkIRM1 = new KinkIRM(
            (1 * WAD / 100) / SECONDS_PER_YEAR,
            (80 * WAD) / 100,
            (1125 * WAD / 10000) / SECONDS_PER_YEAR,
            (350 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        kinkIRM2 = new KinkIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (90 * WAD) / 100,
            (1111 * WAD / 10000) / SECONDS_PER_YEAR,
            (1380 * WAD / 100) / SECONDS_PER_YEAR
        );
    }
    
    function createMarkets() internal {
        MarketParams memory params1 = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(weth),
            oracle: address(1), // mock oracle
            irm: address(linearIRM1),
            lltv: 800000000000000000
        });
        pool1.createMarket(params1, 1);
        
        MarketParams memory params2 = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(weth),
            oracle: address(1),
            irm: address(linearIRM2),
            lltv: 800000000000000000
        });
        pool2.createMarket(params2, 2);
        
        MarketParams memory params3 = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(weth),
            oracle: address(1),
            irm: address(kinkIRM1),
            lltv: 800000000000000000
        });
        pool3.createMarket(params3, 3);
        
        MarketParams memory params4 = MarketParams({
            loanToken: address(usdc),
            collateralToken: address(weth),
            oracle: address(1),
            irm: address(kinkIRM2),
            lltv: 800000000000000000
        });
        pool4.createMarket(params4, 4);
    }
    
    // ============ POOL SETUP TESTS ============
    
    function test_PoolsDeployed() public view {
        assertTrue(address(pool1) != address(0));
        assertTrue(address(pool2) != address(0));
        assertTrue(address(pool3) != address(0));
        assertTrue(address(pool4) != address(0));
    }
    
    function test_MarketsCreated() public view {
        (uint128 totalSupply1,,,,,) = pool1.market(1);
        (uint128 totalSupply2,,,,,) = pool2.market(2);
        (uint128 totalSupply3,,,,,) = pool3.market(3);
        (uint128 totalSupply4,,,,,) = pool4.market(4);
        
        assertEq(totalSupply1, 100_000 * 1e6);
        assertEq(totalSupply2, 100_000 * 1e6);
        assertEq(totalSupply3, 100_000 * 1e6);
        assertEq(totalSupply4, 100_000 * 1e6);
    }
    
    // ============ LINEAR IRM TESTS ============
    
    function test_LinearIRM1_RateAtZeroUtilization() public view{
        MarketParams memory params = pool1.getMarketParams(1);
        Market memory market = pool1.getMarket(1);
        
        uint256 rate = linearIRM1.borrowRateView(params, market);
        
        // Should be ~2% APY = 2% / SECONDS_PER_YEAR 
        uint256 expectedRate = (2 * WAD / 100) / SECONDS_PER_YEAR;
        assertApproxEqRel(rate, expectedRate, 0.01e18); // 1% tolerance
    }
    
    function test_LinearIRM1_RateIncreasesWithUtilization() public {
        // First get rate at 0% utilization
        MarketParams memory params = pool1.getMarketParams(1);
        Market memory marketBefore = pool1.getMarket(1);
        uint256 rateBefore = linearIRM1.borrowRateView(params, marketBefore);
        
        // Borrow to increase utilization 
        vm.startPrank(borrower);
        weth.approve(address(pool1), type(uint256).max);
        pool1.supplyCollateral(1, 10 * 1e18, borrower, "");
        pool1.borrow(1, 20_000 * 1e6, 0, borrower, borrower);
        vm.stopPrank();
        
        // Get rate at ~20% utilization 
        Market memory marketAfter = pool1.getMarket(1);
        uint256 rateAfter = linearIRM1.borrowRateView(params, marketAfter);
        
        assertGt(rateAfter, rateBefore, "Rate should increase with utilization");

        // rate after = 2% base + (13% * 20%) = 2 + 13/5 == 4.6
        assertApproxEqRel(rateAfter, (46 * WAD/1000)/SECONDS_PER_YEAR, 10000000000);
    }
    
    function test_LinearIRM2_HigherBaseRate() public view{
        MarketParams memory params1 = pool1.getMarketParams(1);
        MarketParams memory params2 = pool2.getMarketParams(2);
        Market memory market1 = pool1.getMarket(1);
        Market memory market2 = pool2.getMarket(2);
        
        uint256 rate1 = linearIRM1.borrowRateView(params1, market1);
        uint256 rate2 = linearIRM2.borrowRateView(params2, market2);
        
        assertGt(rate2, rate1, "LinearIRM2 should have higher base rate");
    }
    
    // ============ KINK IRM TESTS ============
    
    function test_KinkIRM_RateBeforeKink() public {
        MarketParams memory params = pool3.getMarketParams(3);
        
        // Borrow 50% to stay before kink (80%)
        vm.startPrank(borrower);
        weth.approve(address(pool3), type(uint256).max);
        pool3.supplyCollateral(3, 20 * 1e18, borrower, "");
        pool3.borrow(3, 50_000 * 1e6, 0, borrower, borrower);
        vm.stopPrank();
        
        Market memory market = pool3.getMarket(3);
        uint256 rate = kinkIRM1.borrowRateView(params, market);
        
        // Should follow gentle slope
        assertTrue(rate < (15 * WAD / 100) / SECONDS_PER_YEAR, "Rate should be moderate before kink");
    }
    
    function test_KinkIRM_RateAfterKink() public {
        MarketParams memory params = pool3.getMarketParams(3);
        
        // Get rate before kink
        vm.startPrank(borrower);
        weth.approve(address(pool3), type(uint256).max);
        pool3.supplyCollateral(3, 30 * 1e18, borrower, "");
        pool3.borrow(3, 70_000 * 1e6, 0, borrower, borrower); // 70% utilization (before kink)
        vm.stopPrank();
        
        Market memory marketBefore = pool3.getMarket(3);
        uint256 rateBefore = kinkIRM1.borrowRateView(params, marketBefore);
        
        // Borrow more to go past kink (85% utilization)
        vm.startPrank(borrower);
        pool3.borrow(3, 15_000 * 1e6, 0, borrower, borrower);
        vm.stopPrank();
        
        Market memory marketAfter = pool3.getMarket(3);
        uint256 rateAfter = kinkIRM1.borrowRateView(params, marketAfter);
        
        // Rate should jump significantly after kink
        assertGt(rateAfter, rateBefore * 2, "Rate should jump significantly after kink");
    }

    
    // ============ BORROW/REPAY TESTS ============
    
    function test_BorrowWithCollateral() public {
        vm.startPrank(borrower);
        weth.approve(address(pool1), type(uint256).max);
        
        // Supply collateral
        pool1.supplyCollateral(1, 5 * 1e18, borrower, "");
        
        // Borrow 
        // max amount to borrow :-
        uint256 borrowAmount = 16_000 * 1e6;
        uint256 balanceBefore = usdc.balanceOf(borrower);
        pool1.borrow(1, borrowAmount, 0, borrower, borrower);
        uint256 balanceAfter = usdc.balanceOf(borrower);
        
        assertEq(balanceAfter - balanceBefore, borrowAmount);
        vm.stopPrank();
    }
    
    function test_RepayReducesUtilization() public {
        // Borrow first
        vm.startPrank(borrower);
        weth.approve(address(pool1), type(uint256).max);
        usdc.approve(address(pool1), type(uint256).max);
        
        pool1.supplyCollateral(1, 10 * 1e18, borrower, "");
        pool1.borrow(1, 30_000 * 1e6, 0, borrower, borrower);
        
        // Give borrower USDC to repay
        // usdc.mint(borrower, 30_000 * 1e6);
        
        Market memory marketBefore = pool1.getMarket(1);
        uint256 utilizationBefore = (uint256(marketBefore.totalBorrowAssets) * WAD) / marketBefore.totalSupplyAssets;
        
        // Repay
        pool1.repay(1, 15_000 * 1e6, 0, borrower, "");
        
        Market memory marketAfter = pool1.getMarket(1);
        uint256 utilizationAfter = (uint256(marketAfter.totalBorrowAssets) * WAD) / marketAfter.totalSupplyAssets;
        
        assertLt(utilizationAfter, utilizationBefore, "Utilization should decrease after repay");
        console.log("utilizationAfter : ", utilizationAfter); // 150000000000000000 = 0.15 * 1e18 == 15%
        console.log("utilizationBefore : ", utilizationBefore);
        vm.stopPrank();
    }
    
    // ============ INTEREST ACCRUAL TESTS ============
    
    function test_InterestAccrues() public {
        // Borrow
        vm.startPrank(borrower);
        weth.approve(address(pool1), type(uint256).max);
        pool1.supplyCollateral(1, 10 * 1e18, borrower, "");
        pool1.borrow(1, 20_000 * 1e6, 0, borrower, borrower);
        vm.stopPrank();
        
        Market memory marketBefore = pool1.getMarket(1);
        uint128 borrowBefore = marketBefore.totalBorrowAssets;
        
        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Trigger interest accrual
        pool1.accrueInterest(1);
        
        Market memory marketAfter = pool1.getMarket(1);
        uint128 borrowAfter = marketAfter.totalBorrowAssets;
        
        assertGt(borrowAfter, borrowBefore, "Borrow amount should increase due to interest");
        console.log("borrowBefore : ", borrowBefore); // 20000000000 = 20,000 * 1e6
        console.log("borrowAfter : ", borrowAfter);   // 20941484452 = 20,941 * 1e6 
        // reason :  since after borrowing, utilization became 20%, hence borrow rate became 4.6%(2% base + 13% slope * 20% util). so 4.6% compounded over a year on 20,000 is 20941 (== 20,000 * e^0.046)
    }
    
    // ============ COMPARATIVE TESTS ============
    
    function test_AllPoolsHaveDifferentRates() public view{
        MarketParams memory params1 = pool1.getMarketParams(1);
        MarketParams memory params2 = pool2.getMarketParams(2);
        MarketParams memory params3 = pool3.getMarketParams(3);
        MarketParams memory params4 = pool4.getMarketParams(4);
        
        Market memory market1 = pool1.getMarket(1);
        Market memory market2 = pool2.getMarket(2);
        Market memory market3 = pool3.getMarket(3);
        Market memory market4 = pool4.getMarket(4);
        
        uint256 rate1 = linearIRM1.borrowRateView(params1, market1);
        uint256 rate2 = linearIRM2.borrowRateView(params2, market2);
        uint256 rate3 = kinkIRM1.borrowRateView(params3, market3);
        uint256 rate4 = kinkIRM2.borrowRateView(params4, market4);
        
        // All rates should be different at 0% utilization
        assertTrue(rate1 != rate2);
        assertTrue(rate1 != rate3);
        // assertTrue(rate1 != rate4); // will be same - both are 2% in starting
        assertTrue(rate2 != rate3);

        // console.log("rate1 : ", rate1); // 634195839
        // console.log("rate2 : ", rate2); // 1585489599
        // console.log("rate3 : ", rate3); // 317097919
        // console.log("rate4 : ", rate4); // 634195839 


        // // console.log("\nDirect IRM checks:");
        // // console.log("kinkIRM1.BASE_RATE:", kinkIRM1.BASE_RATE());
        // // console.log("kinkIRM2.BASE_RATE:", kinkIRM2.BASE_RATE());
        
        // // console.log("\nPool 3 IRM address:", params3.irm);
        // // console.log("Pool 4 IRM address:", params4.irm);
        // // console.log("kinkIRM1 address:", address(kinkIRM1));
        // // console.log("kinkIRM2 address:", address(kinkIRM2));

        // console.log("market4.totalSupplyAssets : ", market4.totalSupplyAssets);
        // console.log("market4.totalBorrowAssets : ", market4.totalBorrowAssets);

        // if (market4.totalSupplyAssets > 0) {
        // uint256 util4 = (uint256(market4.totalBorrowAssets) * WAD) / market4.totalSupplyAssets;
        // console.log("Pool4 utilization (WAD):", util4);
        // }

        // console.log(kinkIRM2.BASE_RATE());
        // console.log(kinkIRM2.borrowRateView(params4, market4));
    }
    
    function test_LowestRatePoolAtZeroUtil() public view{
        MarketParams memory params1 = pool1.getMarketParams(1);
        MarketParams memory params2 = pool2.getMarketParams(2);
        MarketParams memory params3 = pool3.getMarketParams(3);
        MarketParams memory params4 = pool4.getMarketParams(4);
        
        Market memory market1 = pool1.getMarket(1);
        Market memory market2 = pool2.getMarket(2);
        Market memory market3 = pool3.getMarket(3);
        Market memory market4 = pool4.getMarket(4);
        
        uint256 rate1 = linearIRM1.borrowRateView(params1, market1);
        uint256 rate2 = linearIRM2.borrowRateView(params2, market2);
        uint256 rate3 = kinkIRM1.borrowRateView(params3, market3);
        uint256 rate4 = kinkIRM2.borrowRateView(params4, market4);
        
        // KinkIRM1 should have lowest rate at 0% util (1% base)
        assertTrue(rate3 < rate1, "KinkIRM1 should be lower than LinearIRM1");
        assertTrue(rate3 < rate2, "KinkIRM1 should be lower than LinearIRM2");
        assertTrue(rate3 < rate4, "KinkIRM1 should be lower than KinkIRM2");
    }
}