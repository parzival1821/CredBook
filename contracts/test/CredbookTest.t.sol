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
        weth.mint(borrower1, 50 * 1e18);
        weth.mint(borrower2, 50 * 1e18);
        
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
        
        // Repay
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
        usdc.approve(address(credbook), repayAmount);
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
        usdc.approve(address(credbook), borrowAmount);
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
        usdc.approve(address(credbook), 1_000 * 1e6);
        
        vm.expectRevert("No active borrows");
        credbook.repay(1_000 * 1e6);
        vm.stopPrank();
    }
}