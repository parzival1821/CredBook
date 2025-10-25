// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {LendingPool} from "../lending-core/LendingPool.sol";
import {IIrm} from "../interfaces/IIrm.sol";
import {MarketParams, Market} from "../interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {console} from "forge-std/console.sol";

contract Orderbook {
    struct Order {
        address pool;           // Address of the lending pool
        uint256 poolId;         // Market ID in that pool
        uint256 amount;         // Amount of liquidity available (e.g., $1000)
        uint256 rate;           // Interest rate (per second, WAD format)
        uint256 utilization;    // Current utilization of the pool
    }
    
    struct BorrowOrder {
        address borrower;
        uint256 amount;         // Amount to borrow
        uint256 maxRate;        // Maximum rate willing to pay (per second, WAD)
        address collateralToken;
        uint256 collateralAmount;
    }

    struct BorrowPosition {
        address pool;
        uint256 poolId;
        uint256 amount;
        uint256 timestamp;
    }
    
    // Array of all orders on the book (sorted by rate, lowest first)
    Order[] public orders;

    mapping(address => BorrowPosition[]) public borrowerPositions;

    // Registered pools
    address[] public registeredPools;
    mapping(address => bool) public isPoolRegistered;
    mapping(address => uint256) public poolToMarketId;
    
    // Constants
    uint256 public constant ORDER_SIZE = 1000 * 1e6; // $1000 USDC per order
    uint256 public constant ORDERS_PER_POOL = 5;
    uint256 public constant WAD = 1e18;
    
    address public immutable USDC;
    address public immutable WETH;
    
    event PoolRegistered(address indexed pool, uint256 marketId);
    event OrderbookUpdated(uint256 totalOrders);
    event OrderMatched(address indexed borrower, address indexed pool, uint256 amount, uint256 rate);
    event RepayExecuted(address indexed borrower, address indexed pool, uint256 amount);
    
    constructor(address _usdc, address _weth) {
        USDC = _usdc;
        WETH = _weth;
    }
    
    // ============ POOL REGISTRATION ============
    
    function registerPool(address pool, uint256 marketId) external {
        require(!isPoolRegistered[pool], "Pool already registered");
        
        registeredPools.push(pool);
        isPoolRegistered[pool] = true;
        poolToMarketId[pool] = marketId;

        IERC20(WETH).approve(address(pool), type(uint256).max);
        
        emit PoolRegistered(pool, marketId);
    }
    
    // ============ ORDERBOOK MANAGEMENT ============
    
    /// @notice Refresh all orders from all pools
    function refreshOrderbook() public {
        delete orders; // Clear existing orders
        
        // Collect orders from each pool
        for (uint256 i = 0; i < registeredPools.length; i++) {
            address pool = registeredPools[i];
            uint256 marketId = poolToMarketId[pool];
            
            _collectOrdersFromPool(pool, marketId);
        }
        
        // Sort orders by rate (insertion sort)
        _sortOrders();
        
        emit OrderbookUpdated(orders.length);
    }
    
    /// @notice Collect 5 orders from a single pool
    function _collectOrdersFromPool(address poolAddr, uint256 marketId) internal {
        LendingPool pool = LendingPool(poolAddr);
        
        // Get market data
        Market memory market = _getMarket(pool, marketId);
        MarketParams memory params = _getMarketParams(pool, marketId);
        
        // Check if pool has liquidity
        if (market.totalSupplyAssets == 0) return;
        
        uint256 availableLiquidity = market.totalSupplyAssets - market.totalBorrowAssets;
        if (availableLiquidity == 0) return;
        
        // Calculate current utilization
        // uint256 utilization = (uint256(market.totalBorrowAssets) * WAD) / market.totalSupplyAssets;
        
        // Generate 5 orders at increasing utilization levels
        for (uint256 i = 0; i < ORDERS_PER_POOL; i++) {
            if (availableLiquidity < ORDER_SIZE) break;
            
            // Simulate utilization as if this order was filled
            uint256 simulatedBorrow = market.totalBorrowAssets + (ORDER_SIZE * (i + 1));
            uint256 simulatedUtil = (simulatedBorrow * WAD) / market.totalSupplyAssets;
            
            // Get rate at this utilization
            Market memory simulatedMarket = Market({
                totalSupplyAssets: market.totalSupplyAssets,
                totalSupplyShares: market.totalSupplyShares,
                totalBorrowAssets: uint128(simulatedBorrow),
                totalBorrowShares: market.totalBorrowShares,
                lastUpdate: market.lastUpdate,
                fee: market.fee
            });
            
            uint256 rate = IIrm(params.irm).borrowRateView(params, simulatedMarket);
            
            orders.push(Order({
                pool: poolAddr,
                poolId: marketId,
                amount: ORDER_SIZE,
                rate: rate,
                utilization: simulatedUtil
            }));
            
            availableLiquidity -= ORDER_SIZE;
        }
    }
    
    /// @notice Sort orders by rate using insertion sort: O(n^2)
    function _sortOrders() internal {
        uint256 length = orders.length;
        
        for (uint256 i = 1; i < length; i++) {
            Order memory key = orders[i];
            uint256 j = i;
            
            while (j > 0 && orders[j - 1].rate > key.rate) {
                orders[j] = orders[j - 1];
                j--;
            }
            
            orders[j] = key;
        }
    }
    
    // ============ MATCHING ENGINE ============
    
    struct PoolBorrow {
        address pool;
        uint256 poolId;
        uint256 totalAmount;
        uint256 totalCollateral;
    }


    /// @notice Match a borrow order with the best available liquidity
    function matchBorrowOrder(
        address borrower,
        uint256 amount,
        uint256 maxRate,
        uint256 collateralAmount
    ) external {
        require(amount > 0, "Amount must be > 0");
        
        refreshOrderbook();
        
        uint256 remainingAmount = amount;
        uint256 currentOrderIndex = 0;
        
        // Transfer collateral from borrower
        IERC20(WETH).transferFrom(borrower, address(this), collateralAmount);
        
        // Track borrows per unique pool
        
        PoolBorrow[] memory poolBorrows = new PoolBorrow[](registeredPools.length);
        uint256 uniquePoolCount = 0;
        
        // First pass: aggregate orders by pool 
        while (remainingAmount > 0 && currentOrderIndex < orders.length) {
            Order memory order = orders[currentOrderIndex];
            
            require(order.rate <= maxRate, "No orders within max rate");
            
            uint256 fillAmount = remainingAmount > order.amount ? order.amount : remainingAmount;
            uint256 collatForThisOrder = (fillAmount * collateralAmount) / amount;
            
            // Find or create pool entry
            bool found = false;
            for (uint256 i = 0; i < uniquePoolCount; i++) {
                if (poolBorrows[i].pool == order.pool) {
                    poolBorrows[i].totalAmount += fillAmount;
                    poolBorrows[i].totalCollateral += collatForThisOrder;
                    found = true;
                    break;
                }
            }
            
            if (!found) {
                poolBorrows[uniquePoolCount] = PoolBorrow({
                    pool: order.pool,
                    poolId: order.poolId,
                    totalAmount: fillAmount,
                    totalCollateral: collatForThisOrder
                });
                uniquePoolCount++;
            }
            
            emit OrderMatched(borrower, order.pool, fillAmount, order.rate);
            
            remainingAmount -= fillAmount;
            currentOrderIndex++;
        }
        
        console.log("Remaining amount : ", remainingAmount); // 100000000000 = 100_000 * 1e6
        require(remainingAmount == 0, "Could not fill entire order");
        
        // Second pass: execute one borrow per pool
        for (uint256 i = 0; i < uniquePoolCount; i++) {
            _executeBorrow(
                poolBorrows[i].pool,
                poolBorrows[i].poolId,
                poolBorrows[i].totalAmount,
                poolBorrows[i].totalCollateral,
                borrower
            );
        }
        
        refreshOrderbook();
    }
    
    function _executeBorrow(
        address poolAddr,
        uint256 marketId,
        uint256 amount,
        uint256 collateral,
        address borrower
    ) internal {
        LendingPool pool = LendingPool(poolAddr);
        
        // Approve and supply collateral to pool
        IERC20(WETH).approve(poolAddr, collateral);
        pool.supplyCollateral(marketId, collateral, borrower, "");
        
        // Execute borrow
        pool.borrow(marketId, amount, 0, borrower, borrower);

        // Track the borrow position
        borrowerPositions[borrower].push(BorrowPosition({
            pool: poolAddr,
            poolId: marketId,
            amount: amount,
            timestamp: block.timestamp
        }));
    }

    /// @notice Repay borrows across multiple pools proportionally
    /// @param amount Total amount to repay
    function fulfillRepay(address borrower, uint256 amount) external {
        BorrowPosition[] storage positions = borrowerPositions[borrower];
        require(positions.length > 0, "No active borrows");
        
        // Transfer total repay amount from borrower
        IERC20(USDC).transferFrom(borrower, address(this), amount);
        
        uint256 remainingAmount = amount;
        
        // Repay each position proportionally or in order
        for (uint256 i = 0; i < positions.length && remainingAmount > 0; i++) {
            BorrowPosition storage pos = positions[i];
            
            if (pos.amount == 0) continue; // Already fully repaid
            
            uint256 repayAmount = remainingAmount > pos.amount ? pos.amount : remainingAmount;
            
            // Execute repay on the pool
            LendingPool pool = LendingPool(pos.pool);
            IERC20(USDC).approve(pos.pool, repayAmount);
            pool.repay(pos.poolId, repayAmount, 0, borrower, "");
            
            emit RepayExecuted(borrower, pos.pool, repayAmount);
            
            // Update position
            pos.amount -= repayAmount;
            remainingAmount -= repayAmount;
        }
        
        require(remainingAmount == 0, "Could not repay full amount");
        
        // Clean up fully repaid positions
        _cleanupPositions(borrower);
        
        // Refresh orderbook after repayments
        refreshOrderbook();
    }


    /// @notice Remove fully repaid positions
    function _cleanupPositions(address borrower) internal {
        BorrowPosition[] storage positions = borrowerPositions[borrower];
        
        uint256 writeIndex = 0;
        for (uint256 i = 0; i < positions.length; i++) {
            if (positions[i].amount > 0) {
                if (writeIndex != i) {
                    positions[writeIndex] = positions[i];
                }
                writeIndex++;
            }
        }
        
        // Remove empty positions from the end
        while (positions.length > writeIndex) {
            positions.pop();
        }
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getOrderbookSize() external view returns (uint256) {
        return orders.length;
    }
    
    function getOrder(uint256 index) external view returns (Order memory) {
        return orders[index];
    }
    
    function getAllOrders() external view returns (Order[] memory) {
        return orders;
    }
    
    function getBestRate() external view returns (uint256) {
        if (orders.length == 0) return 0;
        return orders[0].rate;
    }

    /// @notice Get all borrow positions for a borrower
    function getBorrowerPositions(address borrower) external view returns (BorrowPosition[] memory) {
        return borrowerPositions[borrower];
    }

    /// @notice Get total borrowed amount for a borrower
    function getTotalBorrowed(address borrower) external view returns (uint256 total) {
        BorrowPosition[] memory positions = borrowerPositions[borrower];
        for (uint256 i = 0; i < positions.length; i++) {
            total += positions[i].amount;
        }
    }

    /// @notice Get number of active positions for a borrower
    function getActivePositionCount(address borrower) external view returns (uint256) {
        return borrowerPositions[borrower].length;
    }
    
    // ============ HELPERS ============
    
    function _getMarket(LendingPool pool, uint256 id) internal view returns (Market memory) {
        (
            uint128 totalSupplyAssets,
            uint128 totalSupplyShares,
            uint128 totalBorrowAssets,
            uint128 totalBorrowShares,
            uint128 lastUpdate,
            uint128 fee
        ) = pool.market(id);
        
        return Market({
            totalSupplyAssets: totalSupplyAssets,
            totalSupplyShares: totalSupplyShares,
            totalBorrowAssets: totalBorrowAssets,
            totalBorrowShares: totalBorrowShares,
            lastUpdate: lastUpdate,
            fee: fee
        });
    }
    
    function _getMarketParams(LendingPool pool, uint256 id) internal view returns (MarketParams memory) {
        (
            address loanToken,
            address collateralToken,
            address oracle,
            address irm,
            uint256 lltv
        ) = pool.idToMarketParams(id);
        
        return MarketParams({
            loanToken: loanToken,
            collateralToken: collateralToken,
            oracle: oracle,
            irm: irm,
            lltv: lltv
        });
    }
}