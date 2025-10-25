// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "forge-std/Test.sol";
import "../src/Credbook.sol";
import "../src/orderbook/Orderbook.sol";
import "../src/mocks/MockUSDC.sol";
import "../src/mocks/MockWETH.sol";
import {LendingPool} from "../src/lending-core/LendingPool.sol";
import {MarketParams, Market} from "../src/interfaces/IMorpho.sol";

contract CredbookTest is Test {
    Credbook public credbook;
    Orderbook public orderbook;
    
    MockUSDC public usdc;
    MockWETH public weth;
    
    address public lender1 = address(0x1);
    address public lender2 = address(0x2);
    address public borrower1 = address(0x3);
    address public borrower2 = address(0x4);
    
    uint256 constant WAD = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    function setUp() public {
        // Deploy tokens
        usdc = new MockUSDC();
        weth = new MockWETH();
        
        // Deploy Credbook (deploys everything)
        credbook = new Credbook(address(usdc), address(weth));
        orderbook = Orderbook(credbook.getOrderbook());
        
        // Setup lenders
        usdc.mint(lender1, 500_000 * 1e6);
        usdc.mint(lender2, 500_000 * 1e6);
        
        // Setup borrowers
        weth.mint(borrower1, 500 * 1e18);
        weth.mint(borrower2, 500 * 1e18);
        
        // Lenders supply liquidity to all pools
        vm.startPrank(lender1);
        usdc.approve(address(credbook), type(uint256).max);
        credbook.supplyLiquidity(0, 100_000 * 1e6); // Pool 0
        credbook.supplyLiquidity(1, 100_000 * 1e6); // Pool 1
        vm.stopPrank();
        
        vm.startPrank(lender2);
        usdc.approve(address(credbook), type(uint256).max);
        credbook.supplyLiquidity(2, 100_000 * 1e6); // Pool 2
        credbook.supplyLiquidity(3, 100_000 * 1e6); // Pool 3
        vm.stopPrank();
    }
    
    // ============ DEPLOYMENT TESTS ============
    
    function test_CredbookDeployed() public view {
        assertTrue(address(credbook) != address(0));
        assertTrue(address(orderbook) != address(0));
    }
    
    function test_PoolsCreated() public view {
        assertEq(credbook.getPoolCount(), 4);
        
        address pool0 = credbook.getPool(0);
        address pool1 = credbook.getPool(1);
        address pool2 = credbook.getPool(2);
        address pool3 = credbook.getPool(3);
        
        assertTrue(pool0 != address(0));
        assertTrue(pool1 != address(0));
        assertTrue(pool2 != address(0));
        assertTrue(pool3 != address(0));
    }
    
    function test_PoolsRegisteredInOrderbook() public view {
        address pool0 = credbook.getPool(0);
        assertTrue(orderbook.isPoolRegistered(pool0));
    }
    
    // ============ LIQUIDITY TESTS ============
    
    function test_SupplyLiquidity() public {
        address pool0 = credbook.getPool(0);
        LendingPool lendingPool = LendingPool(pool0);
        
        (uint128 totalSupplyBefore,,,,,) = lendingPool.market(1);
        
        vm.startPrank(lender1);
        usdc.approve(address(credbook), 10_000 * 1e6);
        credbook.supplyLiquidity(0, 10_000 * 1e6);
        vm.stopPrank();
        
        (uint128 totalSupplyAfter,,,,,) = lendingPool.market(1);
        
        assertGt(totalSupplyAfter, totalSupplyBefore);
        assertEq(totalSupplyAfter - totalSupplyBefore, 10_000 * 1e6);
    }
    
    function test_WithdrawLiquidity() public {
        uint256 balanceBefore = usdc.balanceOf(lender1);
        
        vm.startPrank(lender1);
        credbook.withdrawLiquidity(0, 10_000 * 1e6);
        vm.stopPrank();
        
        uint256 balanceAfter = usdc.balanceOf(lender1);
        
        assertEq(balanceAfter - balanceBefore, 10_000 * 1e6);
    }
    
    // ============ ORDERBOOK TESTS ============
    
    function test_OrderbookHasOrders() public {
        credbook.refreshOrderbook();
        
        uint256 orderCount = orderbook.getOrderbookSize();
        assertTrue(orderCount > 0);
        console.log("Total orders:", orderCount);
    }
    
    // great test to visualise rates in all the orders
    function test_OrdersSortedByRate() public {
        credbook.refreshOrderbook();
        
        Orderbook.Order[] memory orders = orderbook.getAllOrders();
        
        // Check orders are sorted (rate should be increasing)
        for (uint256 i = 1; i < orders.length; i++) {
            assertGe(orders[i].rate, orders[i-1].rate, "Orders not sorted by rate");
            console.log("Rate : ", orders[i].rate);
        }
    }
    
    function test_BestRateIsLowest() public {
        credbook.refreshOrderbook();
        
        uint256 bestRate = credbook.getBestRate();
        Orderbook.Order[] memory orders = orderbook.getAllOrders();
        
        if (orders.length > 0) {
            assertEq(bestRate, orders[0].rate);
        }
    }
    
    // ============ BORROW TESTS ============
    
    function test_BorrowBasic() public {
        uint256 borrowAmount = 5_000 * 1e6;
        uint256 collateralAmount = 2 * 1e18;
        
        uint256 usdcBalanceBefore = usdc.balanceOf(borrower1);
        
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        
        uint256 maxRate = type(uint256).max; // Accept any rate 
        credbook.borrow(borrowAmount, collateralAmount, maxRate);
        vm.stopPrank();
        
        uint256 usdcBalanceAfter = usdc.balanceOf(borrower1);

        console.log("usdcBalanceBefore : ", usdcBalanceBefore);
        console.log("usdcBalanceAfter : ", usdcBalanceAfter);

        console.log("usdc balance of credbook : ", usdc.balanceOf(address(credbook)));
        
        assertEq(usdcBalanceAfter - usdcBalanceBefore, borrowAmount);
    }

    function test_BorrowDirectlyFromPool() public{
        address pool0 = credbook.getPool(0);
        uint256 borrowAmount = 5_000 * 1e6;
        uint256 collateralAmount = 2 * 1e18;
        
        uint256 usdcBalanceBefore = usdc.balanceOf(borrower1);
        vm.startPrank(borrower1);
        weth.approve(pool0, collateralAmount);
        LendingPool(pool0).supplyCollateral(1,collateralAmount,borrower1,"");
        LendingPool(pool0).borrow(1,borrowAmount,0,borrower1,borrower1);
        vm.stopPrank();

        uint256 usdcBalanceAfter = usdc.balanceOf(borrower1);

        console.log("usdcBalanceBefore : ", usdcBalanceBefore);
        console.log("usdcBalanceAfter : ", usdcBalanceAfter);   // 5000000000 == 5_000 * 1e6
    }
    
    function test_BorrowCreatesPositions() public {
        uint256 borrowAmount = 5_000 * 1e6;
        uint256 collateralAmount = 2 * 1e18;
        
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        vm.stopPrank();
        
        uint256 positionCount = orderbook.getActivePositionCount(borrower1);
        assertTrue(positionCount > 0);
        
        uint256 totalBorrowed = orderbook.getTotalBorrowed(borrower1);
        assertEq(totalBorrowed, borrowAmount);
    }
    
    function test_BorrowMatchesCheapestPools() public {
        credbook.refreshOrderbook();
        
        // Orderbook.Order[] memory ordersBefore = orderbook.getAllOrders();
        // uint256 lowestRate = ordersBefore[0].rate;
        
        uint256 borrowAmount = 1_500 * 1e6; // Borrow less than one order 
        uint256 collateralAmount = 1 * 1e18;
        
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        vm.stopPrank();
        
        // Check that borrower got matched with lowest rate pool
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        assertTrue(positions.length > 0);
    }
    
    function test_LargeBorrowSpansMultiplePools() public {
        uint256 borrowAmount = 15_000 * 1e6; // More than ORDER_SIZE (1000 USDC)
        uint256 collateralAmount = 10 * 1e18;
        
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        vm.stopPrank();
        
        uint256 positionCount = orderbook.getActivePositionCount(borrower1);
        
        // Should have borrowed from multiple orders
        assertTrue(positionCount >= 1);
        
        uint256 totalBorrowed = orderbook.getTotalBorrowed(borrower1);
        assertEq(totalBorrowed, borrowAmount);
    }
    
    function test_BorrowFailsIfRateTooHigh() public {
        uint256 borrowAmount = 1_000 * 1e6;
        uint256 collateralAmount = 1 * 1e18;
        uint256 maxRate = 1; // Extremely low max rate
        
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        
        vm.expectRevert("No orders within max rate");
        credbook.borrow(borrowAmount, collateralAmount, maxRate);
        vm.stopPrank();
    }
    
    // ============ REPAY TESTS ============
    
    function test_RepayBasic() public {
        // First borrow
        uint256 borrowAmount = 5_000 * 1e6;
        uint256 collateralAmount = 3 * 1e18;
        
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        uint256 totalBorrowedBefore = orderbook.getTotalBorrowed(borrower1);
        
        // Give borrower USDC to repay
        usdc.mint(borrower1, borrowAmount);
        
        // Repay (no interest accrued in such a short time)
        usdc.approve(address(orderbook), borrowAmount);
        credbook.repay(borrowAmount);
        vm.stopPrank();
        
        uint256 totalBorrowedAfter = orderbook.getTotalBorrowed(borrower1);
        
        assertLt(totalBorrowedAfter, totalBorrowedBefore);
    }
    
    function test_PartialRepay() public {
        // Borrow
        uint256 borrowAmount = 10_000 * 1e6;
        uint256 collateralAmount = 5 * 1e18;
        
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        uint256 totalBorrowedBefore = orderbook.getTotalBorrowed(borrower1);
        
        // Partial repay
        uint256 repayAmount = 3_000 * 1e6;
        usdc.mint(borrower1, repayAmount);
        usdc.approve(address(orderbook), repayAmount);
        credbook.repay(repayAmount);
        vm.stopPrank();
        
        uint256 totalBorrowedAfter = orderbook.getTotalBorrowed(borrower1);
        
        assertEq(totalBorrowedBefore - totalBorrowedAfter, repayAmount);
    }
    
    function test_FullRepay() public {
        // Borrow
        uint256 borrowAmount = 5_000 * 1e6;
        uint256 collateralAmount = 3 * 1e18;
        
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        // Full repay
        usdc.mint(borrower1, borrowAmount);
        usdc.approve(address(orderbook), borrowAmount);
        credbook.repay(borrowAmount);
        vm.stopPrank();
        
        uint256 totalBorrowedAfter = orderbook.getTotalBorrowed(borrower1);
        assertEq(totalBorrowedAfter, 0);
    }
    
    // ============ POOL STATS TESTS ============
    
    function test_GetPoolStats() public view {
        (
            uint256 totalSupply,
            ,
            uint256 utilization,
            
        ) = credbook.getPoolStats(0);
        
        assertGt(totalSupply, 0);
        assertTrue(utilization <= WAD); // Utilization should be <= 100%
    }
    
    // ============ MULTI-USER TESTS ============
    
    function test_MultipleBorrowers() public {
        uint256 borrowAmount = 5_000 * 1e6;
        uint256 collateralAmount = 3 * 1e18;
        
        // Borrower 1 borrows
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        vm.stopPrank();
        
        // Borrower 2 borrows
        vm.startPrank(borrower2);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        vm.stopPrank();
        
        uint256 borrowed1 = orderbook.getTotalBorrowed(borrower1);
        uint256 borrowed2 = orderbook.getTotalBorrowed(borrower2);
        
        assertEq(borrowed1, borrowAmount);
        assertEq(borrowed2, borrowAmount);
    }
    
    function test_OrderbookRefreshesAfterBorrow() public {
        credbook.refreshOrderbook();
        // uint256 orderCountBefore = orderbook.getOrderbookSize();
        
        // Borrow (which should refresh orderbook)
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), 3 * 1e18);
        credbook.borrow(5_000 * 1e6, 3 * 1e18, type(uint256).max);
        vm.stopPrank();
        
        uint256 orderCountAfter = orderbook.getOrderbookSize();
        
        // Order count might change due to utilization changes
        assertTrue(orderCountAfter > 0);
    }
    
    // ============ EDGE CASES ============
    
    function test_CannotBorrowWithoutCollateral() public {
        vm.startPrank(borrower1);
        
        vm.expectRevert();
        credbook.borrow(1_000 * 1e6, 0, type(uint256).max);
        vm.stopPrank();
    }
    
    function test_CannotRepayWithoutBorrowing() public {
        vm.startPrank(borrower1);
        usdc.mint(borrower1, 1_000 * 1e6);
        usdc.approve(address(orderbook), 1_000 * 1e6);
        
        vm.expectRevert("No active borrows");
        credbook.repay(1_000 * 1e6);
        vm.stopPrank();
    }


    // ============ INTEREST ACCRUAL TESTS ============

    // ✅
    function test_InterestAccruesOverTime() public {
        uint256 borrowAmount = 10_000 * 1e6;
        uint256 collateralAmount = 5 * 1e18;
        
        // Borrow
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        vm.stopPrank();
        
        // Get the positions to know which pools were used
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        require(positions.length > 0, "Should have borrow positions");
        
        // Track total borrow across all positions
        uint256 totalBorrowBefore = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            (,, uint128 totalBorrow,,,) = pool.market(positions[i].poolId);
            totalBorrowBefore += totalBorrow;
        }
        
        console.log("Total borrow before time warp:", totalBorrowBefore); // 38000000000
        
        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Accrue interest on all pools that were used
        uint256 totalBorrowAfter = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
            
            (,, uint128 totalBorrow,,,) = pool.market(positions[i].poolId);
            totalBorrowAfter += totalBorrow;
        }
        
        console.log("Total borrow after 1 year:", totalBorrowAfter);            // 38697587846
        console.log("Interest accrued:", totalBorrowAfter - totalBorrowBefore); // 697587846 => effective 1.83% of initial amount
        
        assertGt(totalBorrowAfter, totalBorrowBefore, "Interest should accrue");
        
        // Check that interest is roughly in expected range (should be > 1% of principal)
        uint256 minExpectedInterest = borrowAmount / 100; // At least 1%
        assertTrue(totalBorrowAfter - totalBorrowBefore > minExpectedInterest);
    }

    function test_InterestAccrualAffectsRepaymentAmount() public {
        uint256 borrowAmount = 10_000 * 1e6;
        uint256 collateralAmount = 5 * 1e18;
        
        // Borrow
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        uint256 borrowedAmount = orderbook.getTotalBorrowed(borrower1);
        console.log("Initially borrowed (tracked):", borrowedAmount); // 10000000000 = 10_000 * 1e6
        
        // Get actual debt from pools
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        uint256 actualDebtBefore = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
            
            // Calculate actual debt from shares
            uint256 positionDebt = (borrowShares * totalBorrowAssets) / totalBorrowShares;
            actualDebtBefore += positionDebt;
        }
        
        console.log("Actual debt before time:", actualDebtBefore); // 10000000000 = 10_000 * 1e6  
        
        // Advance time by 6 months
        vm.warp(block.timestamp + 182 days);
        
        // Accrue interest on all used pools
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
        }
        
        // Calculate actual debt after accrual
        uint256 actualDebtAfter = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
            
            uint256 positionDebt = (borrowShares * totalBorrowAssets) / totalBorrowShares;
            actualDebtAfter += positionDebt;
        }
        
        console.log("Actual debt after 6 months:", actualDebtAfter);
        
        vm.stopPrank();
        
        // Actual debt should be higher than initial borrow
        assertGt(actualDebtAfter, borrowAmount, "Debt should increase with interest");
    }

    function test_MultipleAccrualsCompoundInterest() public {
        uint256 borrowAmount = 5_000 * 1e6;
        uint256 collateralAmount = 3 * 1e18;
        
        // Borrow
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        vm.stopPrank();
        
        // Get positions
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        
        // Track debt over time
        uint256[] memory debtSnapshots = new uint256[](4);
        
        // Initial debt 
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            (,, uint128 totalBorrow,,,) = pool.market(positions[i].poolId);
            debtSnapshots[0] += totalBorrow;
        }
        console.log("Initial debt:", debtSnapshots[0]);
        
        // Accrue 3 times over 1 year
        for (uint256 period = 0; period < 3; period++) {
            vm.warp(block.timestamp + 121 days); // ~4 months each
            
            uint256 currentDebt = 0;
            for (uint256 i = 0; i < positions.length; i++) {
                LendingPool pool = LendingPool(positions[i].pool);
                pool.accrueInterest(positions[i].poolId);
                
                (,, uint128 totalBorrow,,,) = pool.market(positions[i].poolId);
                currentDebt += totalBorrow;
            }
            
            debtSnapshots[period + 1] = currentDebt;
            console.log("After period", period + 1, "debt:", currentDebt);
        }
        
        // Each period should have more debt than the last (compounding)
        assertGt(debtSnapshots[1], debtSnapshots[0]);
        assertGt(debtSnapshots[2], debtSnapshots[1]);
        assertGt(debtSnapshots[3], debtSnapshots[2]);
    }

    // ============ ORDERBOOK REFRESH & DYNAMICS TESTS ============

    function test_OrderbookRefreshShowsDifferentRates() public {
        credbook.refreshOrderbook();
        
        Orderbook.Order[] memory ordersBefore = orderbook.getAllOrders();
        uint256 firstRateBefore = ordersBefore[0].rate;
        
        console.log("Best rate before borrow:", firstRateBefore);
        console.log("Total orders before:", ordersBefore.length);
        
        // Borrow to change utilization
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), 10 * 1e18);
        credbook.borrow(20_000 * 1e6, 10 * 1e18, type(uint256).max);
        vm.stopPrank();
        
        // Orderbook should have refreshed automatically
        Orderbook.Order[] memory ordersAfter = orderbook.getAllOrders();
        
        console.log("Total orders after:", ordersAfter.length);
        
        if (ordersAfter.length > 0) {
            uint256 firstRateAfter = ordersAfter[0].rate;
            console.log("Best rate after borrow:", firstRateAfter);
            
            if (firstRateBefore > 0) {
                console.log("Rate increase:", firstRateAfter - firstRateBefore);
            }
            
            // Rates should be higher due to increased utilization
            assertGt(firstRateAfter, firstRateBefore, "Rates should increase with utilization");
        }
    }

    function test_OrderbookShowsUtilizationChanges() public {
        credbook.refreshOrderbook();
        
        Orderbook.Order[] memory ordersBefore = orderbook.getAllOrders();
        
        console.log("=== Before Borrow (first 5 orders) ===");
        for (uint256 i = 0; i < 5 && i < ordersBefore.length; i++) {
            // console.log("Order", i, "- Rate:", ordersBefore[i].rate, "Util:", ordersBefore[i].utilization);
            console.log("Order number : ", i);
            console.log("Rate : ", ordersBefore[i].rate);
            console.log("Utilization : ", ordersBefore[i].utilization);
        }
        
        // note that loanAmount cannot be greater than 20k since at once only 20 quotes are present
        uint256 collatAmount = 5 * 1e18;
        uint256 loanAmount = 12_000 * 1e6;
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collatAmount);
        credbook.borrow(loanAmount, collatAmount, type(uint256).max);
        vm.stopPrank();
        
        Orderbook.Order[] memory ordersAfter = orderbook.getAllOrders();
        
        console.log("\n=== After Borrow (first 5 orders) ===");
        for (uint256 i = 0; i < 5 && i < ordersAfter.length; i++) {
            // console.log("Order", i, "- Rate:", ordersAfter[i].rate, "Util:", ordersAfter[i].utilization);
            console.log("Order number : ", i);
            console.log("Rate : ", ordersAfter[i].rate);
            console.log("Utilization : ", ordersAfter[i].utilization);
        }
        
        // At least some orders should show higher utilization
        if (ordersAfter.length > 0 && ordersBefore.length > 0) {
            // Average utilization should be higher
            uint256 avgUtilBefore = 0;
            uint256 avgUtilAfter = 0;
            
            uint256 checkCount = 5;
            if (ordersBefore.length < checkCount) checkCount = ordersBefore.length;
            
            for (uint256 i = 0; i < checkCount; i++) {
                avgUtilBefore += ordersBefore[i].utilization;
                avgUtilAfter += ordersAfter[i].utilization;
            }
            
            assertGt(avgUtilAfter, avgUtilBefore, "Average utilization should increase");
        }
    }

    function test_RepayRestoresOrderbookLiquidity() public {

        uint256 collatAmount = 10 * 1e18;
        uint256 loanAmount = 20_000 * 1e6;

        // First, borrow heavily
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collatAmount);
        credbook.borrow(loanAmount, collatAmount, type(uint256).max);
        vm.stopPrank();
        
        credbook.refreshOrderbook();
        uint256 orderCountAfterBorrow = orderbook.getOrderbookSize();
        
        console.log("Orders after borrow:", orderCountAfterBorrow);
        
        // Repay
        vm.startPrank(borrower1);
        usdc.mint(borrower1, loanAmount);
        usdc.approve(address(orderbook), loanAmount);
        credbook.repay(loanAmount);
        vm.stopPrank();
        
        uint256 orderCountAfterRepay = orderbook.getOrderbookSize();
        
        console.log("Orders after repay:", orderCountAfterRepay);
        
        // Should have more orders available again
        assertGe(orderCountAfterRepay, orderCountAfterBorrow, "Liquidity should be restored");
    }

    function test_DifferentPoolsQuoteDifferentRates() public {
        credbook.refreshOrderbook();
        
        Orderbook.Order[] memory orders = orderbook.getAllOrders();
        
        console.log("=== Rates by Pool ===");
        for (uint256 i = 0; i < orders.length && i < 10; i++) {
            // console.log("Order", i, "- Pool:", orders[i].pool, "Rate:", orders[i].rate);
            console.log("Order number : ", i);
            console.log("Rate : ", orders[i].rate);
            console.log("Utilization : ", orders[i].utilization);
        }
        
        // Check that we have orders from multiple pools
        address firstPool = orders[0].pool;
        bool foundDifferentPool = false;
        
        for (uint256 i = 1; i < orders.length; i++) {
            if (orders[i].pool != firstPool) {
                foundDifferentPool = true;
                break;
            }
        }
        
        assertTrue(foundDifferentPool, "Should have orders from multiple pools");
    }

    function test_OrderbookSortingMaintainedAfterRefresh() public {
        // Borrow to change utilization
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), 10 * 1e18);
        credbook.borrow(20_000 * 1e6, 10 * 1e18, type(uint256).max);
        vm.stopPrank();
        
        credbook.refreshOrderbook();
        
        Orderbook.Order[] memory orders = orderbook.getAllOrders();
        
        // Verify sorting is maintained
        for (uint256 i = 1; i < orders.length; i++) {
            assertGe(orders[i].rate, orders[i-1].rate, "Orders must remain sorted after refresh");
        }
        
        console.log("Verified", orders.length, "orders are properly sorted");
    }

    function test_SimulatedUtilizationInOrdersIsAccurate() public {
        credbook.refreshOrderbook();
        
        Orderbook.Order[] memory orders = orderbook.getAllOrders();
        
        // Group orders by pool and check utilization progression
        console.log("=== Simulated utilization by pool ===");
        
        address currentPool = orders[0].pool;
        uint256 orderCountForPool = 0;
        uint256 firstUtilForPool = orders[0].utilization;
        
        for (uint256 i = 0; i < orders.length; i++) {
            if (orders[i].pool == currentPool) {
                // console.log("Pool", currentPool, "Order", orderCountForPool, "Util:", orders[i].utilization);
                console.log("Pool: ", currentPool);
                console.log("Order : ", orderCountForPool);
                console.log("Utilization : ", orders[i].utilization);
                orderCountForPool++;
            } else {
                // New pool
                currentPool = orders[i].pool;
                orderCountForPool = 0;
                firstUtilForPool = orders[i].utilization;
            }
        }
        
        // Just verify orders exist with valid utilization
        assertTrue(orders.length > 0, "Should have orders");
        assertTrue(orders[0].utilization <= WAD, "Utilization should be <= 100%");
    }


    // ============ REPAY WITH INTEREST TESTS ============

    function test_RepayWithAccruedInterest_FullAmount() public {
        uint256 borrowAmount = 10_000 * 1e6;
        uint256 collateralAmount = 5 * 1e18;
        
        // Borrow
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        uint256 borrowedTracked = orderbook.getTotalBorrowed(borrower1);
        console.log("Borrowed (tracked):", borrowedTracked);
        
        // Advance time by 1 year 
        vm.warp(block.timestamp + 365 days);
        
        // Accrue interest on all pools
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        uint256 actualDebtWithInterest = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
            
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
            
            uint256 positionDebt = (borrowShares * totalBorrowAssets) / totalBorrowShares;
            actualDebtWithInterest += positionDebt;
        }
        
        console.log("Actual debt with interest:", actualDebtWithInterest);
        uint256 interestAccrued = actualDebtWithInterest - borrowAmount;
        console.log("Interest accrued:", interestAccrued);
        
        // Try to repay only the principal (should fail or leave debt)
        // usdc.mint(borrower1, borrowAmount);
        usdc.approve(address(orderbook), borrowAmount);
        
        // This will repay the tracked amount, but not cover the full debt with interest
        credbook.repay(borrowAmount);
        
        // Check remaining debt
        uint256 remainingDebt = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            
            if (borrowShares > 0) {
                (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
                remainingDebt += (borrowShares * totalBorrowAssets) / totalBorrowShares;
            }
        }
        
        console.log("Remaining debt after repaying principal:", remainingDebt);
        
        vm.stopPrank();
        
        // Should still have debt equal to the interest
        assertGt(remainingDebt, 0, "Should have remaining debt from unpaid interest");
        assertApproxEqAbs(remainingDebt, interestAccrued, 1000, "Remaining should be ~interest amount");
    }

    function test_RepayWithAccruedInterest_PayFullDebt() public {
        uint256 borrowAmount = 10_000 * 1e6;
        uint256 collateralAmount = 5 * 1e18;
        
        // Borrow
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        // Advance time by 6 months
        vm.warp(block.timestamp + 182 days);
        
        // Calculate actual debt with interest
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        uint256 actualDebtWithInterest = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
            
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
            
            uint256 positionDebt = (borrowShares * totalBorrowAssets) / totalBorrowShares;
            actualDebtWithInterest += positionDebt;
        }
        
        console.log("Principal:", borrowAmount);
        console.log("Debt with interest:", actualDebtWithInterest);
        console.log("Interest:", actualDebtWithInterest - borrowAmount);
        assertEq(actualDebtWithInterest, orderbook.getActualDebt(borrower1));
        
        // Repay the full amount including interest
        usdc.mint(borrower1, actualDebtWithInterest - borrowAmount); // mint the extra money that borrower must pay
        usdc.approve(address(orderbook), actualDebtWithInterest);
        credbook.repay(actualDebtWithInterest);
        
        // Verify all debt is cleared
        uint256 remainingDebt = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            remainingDebt += borrowShares;
        }
        
        vm.stopPrank();

        Orderbook.BorrowPosition[] memory positionsAfterRepay = orderbook.getBorrowerPositions(borrower1);
        assertEq(positionsAfterRepay.length, 0);
        
        assertEq(remainingDebt, 0, "All debt should be repaid");
        assertEq(orderbook.getActivePositionCount(borrower1), 0, "No active positions should remain");
        assertEq(orderbook.getTotalBorrowed(borrower1), 0);
    }

    function test_PartialRepayWithAccruedInterest() public {
        uint256 borrowAmount = 20_000 * 1e6;
        uint256 collateralAmount = 10 * 1e18;
        
        // Borrow 
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        // Advance time by 1 year
        vm.warp(block.timestamp + 365 days);
        
        // Calculate debt before repayment
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        uint256 debtBefore = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
            
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
            
            debtBefore += (borrowShares * totalBorrowAssets) / totalBorrowShares;
        }
        
        console.log("Debt with interest:", debtBefore);
        console.log("Number of Borrow positions ", positions.length);
        
        // Repay 50% of principal
        uint256 repayAmount = 10_000 * 1e6;
        usdc.mint(borrower1, repayAmount);
        usdc.approve(address(orderbook), repayAmount);
        credbook.repay(repayAmount);
        Orderbook.BorrowPosition[] memory positionsAfterRepay = orderbook.getBorrowerPositions(borrower1);
        
        // Calculate debt after repayment
        uint256 debtAfter = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
            
            if (borrowShares > 0) {
                debtAfter += (borrowShares * totalBorrowAssets) / totalBorrowShares;
            }
        }
        
        console.log("Debt after partial repay:", debtAfter);
        console.log("Amount reduced:", debtBefore - debtAfter);
        console.log("positionsAfterRepay : ", positionsAfterRepay.length);
        
        vm.stopPrank();
        
        assertLt(debtAfter, debtBefore, "Debt should decrease");
        assertGt(debtAfter, 0, "Should still have remaining debt");
    }

    function test_MultipleRepaysWithContinuingInterest() public {
        uint256 borrowAmount = 10_000 * 1e6;
        uint256 collateralAmount = 5 * 1e18;
        
        // Borrow
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        console.log("=== Initial Borrow ===");
        console.log("Borrowed:", borrowAmount);
        
        // Wait 6 months, accrue interest, repay some
        vm.warp(block.timestamp + 182 days);
        
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        
        // Accrue and check
        uint256 debt1 = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
            
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
            debt1 += (borrowShares * totalBorrowAssets) / totalBorrowShares;
        }
        
        console.log("\n=== After 6 Months ===");
        console.log("Debt with interest:", debt1);
        
        // First repayment
        uint256 repay1 = 3_000 * 1e6;
        usdc.mint(borrower1, repay1);
        usdc.approve(address(orderbook), repay1);
        credbook.repay(repay1);
        
        console.log("Repaid:", repay1);
        
        // Wait another 6 months
        vm.warp(block.timestamp + 182 days);
        
        uint256 debt2 = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
            
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            if (borrowShares > 0) {
                (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
                debt2 += (borrowShares * totalBorrowAssets) / totalBorrowShares;
            }
        }
        
        console.log("\n=== After Another 6 Months ===");
        console.log("Debt with more interest:", debt2);
        
        // Second repayment
        uint256 repay2 = 3_000 * 1e6;
        usdc.mint(borrower1, repay2);
        usdc.approve(address(orderbook), repay2);
        credbook.repay(repay2);
        
        console.log("Repaid:", repay2);
        
        // Final debt check
        uint256 debtFinal = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            if (borrowShares > 0) {
                (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
                debtFinal += (borrowShares * totalBorrowAssets) / totalBorrowShares;
            }
        }
        
        console.log("\n=== Final Debt ===");
        console.log("Remaining:", debtFinal);
        console.log("Total repaid:", repay1 + repay2);
        
        vm.stopPrank();
        
        // Should still have debt since interest kept accruing
        assertGt(debtFinal, 0, "Should have remaining debt");
        assertLt(debtFinal, debt1, "Final debt should be less than debt after first period");
    }

    function test_InterestAccruesOnRemainingDebtAfterPartialRepay() public {
        uint256 borrowAmount = 10_000 * 1e6;
        uint256 collateralAmount = 5 * 1e18;
        
        // Borrow
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        // Wait 6 months and repay half
        vm.warp(block.timestamp + 182 days);
        
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool(positions[i].pool).accrueInterest(positions[i].poolId);
        }
        
        uint256 repayAmount = 5_000 * 1e6;
        usdc.mint(borrower1, repayAmount);
        usdc.approve(address(orderbook), repayAmount);
        credbook.repay(repayAmount);
        
        // Get debt immediately after repayment
        uint256 debtAfterRepay = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            if (borrowShares > 0) {
                (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
                debtAfterRepay += (borrowShares * totalBorrowAssets) / totalBorrowShares;
            }
        }
        
        console.log("Debt after repaying 5000:", debtAfterRepay);
        
        // Wait another 6 months - interest should accrue on REMAINING debt
        vm.warp(block.timestamp + 182 days);
        
        uint256 debtAfterMoreTime = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
            
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            if (borrowShares > 0) {
                (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
                debtAfterMoreTime += (borrowShares * totalBorrowAssets) / totalBorrowShares;
            }
        }
        
        console.log("Debt after 6 more months:", debtAfterMoreTime);
        console.log("Additional interest accrued:", debtAfterMoreTime - debtAfterRepay);
        
        vm.stopPrank();
        
        // Interest should continue accruing on remaining balance
        assertGt(debtAfterMoreTime, debtAfterRepay, "Interest should accrue on remaining debt");
    }

    function test_CannotFullyRepayWithOnlyPrincipalAfterLongTime() public {
        uint256 borrowAmount = 10_000 * 1e6;
        uint256 collateralAmount = 5 * 1e18;
        
        // Borrow
        vm.startPrank(borrower1);
        weth.approve(address(orderbook), collateralAmount);
        credbook.borrow(borrowAmount, collateralAmount, type(uint256).max);
        
        // Wait 2 years
        vm.warp(block.timestamp + 730 days);
        
        // Accrue interest
        Orderbook.BorrowPosition[] memory positions = orderbook.getBorrowerPositions(borrower1);
        uint256 actualDebt = 0;
        
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            pool.accrueInterest(positions[i].poolId);
            
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
            actualDebt += (borrowShares * totalBorrowAssets) / totalBorrowShares;
        }
        
        console.log("Original borrow:", borrowAmount);
        console.log("Debt after 2 years:", actualDebt);
        console.log("Interest as % of principal(x100):", ((actualDebt - borrowAmount) * 10000) / borrowAmount);
        
        // Try to repay only principal
        // usdc.mint(borrower1, borrowAmount);
        usdc.approve(address(orderbook), borrowAmount);
        credbook.repay(borrowAmount);
        
        // Check if debt remains
        uint256 remainingDebt = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            LendingPool pool = LendingPool(positions[i].pool);
            uint256 borrowShares = pool.borrowShares(positions[i].poolId, borrower1);
            if (borrowShares > 0) {
                (,, uint128 totalBorrowAssets, uint128 totalBorrowShares,,) = pool.market(positions[i].poolId);
                remainingDebt += (borrowShares * totalBorrowAssets) / totalBorrowShares;
            }
        }
        
        console.log("Remaining debt:", remainingDebt);
        
        vm.stopPrank();
    }
}
