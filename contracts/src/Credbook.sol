// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {LendingPool} from "./lending-core/LendingPool.sol";
import {Orderbook} from "./orderbook/Orderbook.sol";
import {LinearIRM} from "./lending-core/LinearIRM.sol";
import {KinkIRM} from "./lending-core/KinkIRM.sol";
import {MarketParams} from "./interfaces/IMorpho.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title LendingHub
/// @notice Single entry point for the entire lending protocol
/// @dev Deploys pools, orderbook, and provides user-facing functions
contract Credbook {
    // Core contracts
    Orderbook public orderbook;
    
    // Pools
    LendingPool[] public pools;
    
    // IRMs
    LinearIRM public linearIRM1;
    LinearIRM public linearIRM2;
    KinkIRM public kinkIRM1;
    KinkIRM public kinkIRM2;
    
    // Tokens
    address public immutable USDC;
    address public immutable WETH;
    
    // Constants
    uint256 constant WAD = 1e18;
    uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
    
    // Events
    event HubDeployed(address orderbook, uint256 numPools);
    event PoolCreated(uint256 indexed poolIndex, address poolAddress, address irm);
    event LiquidityAdded(uint256 indexed poolIndex, address lender, uint256 amount);
    event BorrowExecuted(address indexed borrower, uint256 amount, uint256 avgRate);
    
    constructor(address _usdc, address _weth) {
        USDC = _usdc;
        WETH = _weth;
        
        // Deploy orderbook
        orderbook = new Orderbook(_usdc, _weth);
        
        // Deploy IRMs
        _deployIRMs();
        
        // Deploy pools
        _deployPools();
        
        emit HubDeployed(address(orderbook), pools.length);
    }
    
    // ============ INTERNAL SETUP ============
    
    function _deployIRMs() internal {
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
        
        // Kink IRM 1: 1% → 10% @ 80%, then → 80% @ 100%
        kinkIRM1 = new KinkIRM(
            (1 * WAD / 100) / SECONDS_PER_YEAR,
            (80 * WAD) / 100,
            (1125 * WAD / 10000) / SECONDS_PER_YEAR,
            (350 * WAD / 100) / SECONDS_PER_YEAR
        );
        
        // Kink IRM 2: 2% → 12% @ 90%, then → 150% @ 100%
        kinkIRM2 = new KinkIRM(
            (2 * WAD / 100) / SECONDS_PER_YEAR,
            (90 * WAD) / 100,
            (1111 * WAD / 10000) / SECONDS_PER_YEAR,
            (1380 * WAD / 100) / SECONDS_PER_YEAR
        );
    }
    
    function _deployPools() internal {
        address[4] memory irms = [
            address(linearIRM1),
            address(linearIRM2),
            address(kinkIRM1),
            address(kinkIRM2)
        ];
        
        for (uint256 i = 0; i < 4; i++) {
            LendingPool pool = new LendingPool();
            
            MarketParams memory params = MarketParams({
                loanToken: USDC,
                collateralToken: WETH,
                oracle: address(1), // Mock oracle
                irm: irms[i],
                lltv: 800000000000000000 // 80% LTV
            });
            
            uint256 marketId = i + 1;
            pool.createMarket(params, marketId);
            
            pools.push(pool);
            
            // Register pool with orderbook
            orderbook.registerPool(address(pool), marketId);
            
            emit PoolCreated(i, address(pool), irms[i]);

            
        }
    }
    
    // ============ LENDER FUNCTIONS ============
    
    /// @notice Supply liquidity to a specific pool
    /// @param poolIndex Index of the pool (0-3)
    /// @param amount Amount of USDC to supply
    function supplyLiquidity(uint256 poolIndex, uint256 amount) external {
        require(poolIndex < pools.length, "Invalid pool index");
        
        LendingPool pool = pools[poolIndex];
        uint256 marketId = poolIndex + 1;
        
        // Transfer USDC from lender
        IERC20(USDC).transferFrom(msg.sender, address(this), amount);
        
        // Approve pool
        IERC20(USDC).approve(address(pool), amount);
        
        // Supply to pool
        pool.supply(marketId, amount, 0, msg.sender, "");
        
        // Refresh orderbook
        orderbook.refreshOrderbook();
        
        emit LiquidityAdded(poolIndex, msg.sender, amount);
    }
    
    /// @notice Withdraw liquidity from a specific pool
    /// @param poolIndex Index of the pool (0-3)
    /// @param amount Amount to withdraw
    function withdrawLiquidity(uint256 poolIndex, uint256 amount) external {
        require(poolIndex < pools.length, "Invalid pool index");
        
        LendingPool pool = pools[poolIndex];
        uint256 marketId = poolIndex + 1;
        
        // Withdraw from pool (pool will send USDC directly to msg.sender)
        pool.withdraw(marketId, amount, 0, msg.sender, msg.sender);
        
        // Refresh orderbook
        orderbook.refreshOrderbook();
    }
    
    // ============ BORROWER FUNCTIONS ============
    
    /// @notice Borrow USDC using WETH as collateral
    /// @param amount Amount of USDC to borrow
    /// @param collateralAmount Amount of WETH to provide as collateral
    /// @param maxRate Maximum interest rate willing to pay (per second, WAD)
    function borrow(
        uint256 amount,
        uint256 collateralAmount,
        uint256 maxRate
    ) external {
        // Execute borrow through orderbook
        orderbook.matchBorrowOrder(msg.sender, amount, maxRate, collateralAmount);
        
        emit BorrowExecuted(msg.sender, amount, orderbook.getBestRate());
    }
    
    /// @notice Repay borrowed USDC across all pools (replaces old repay)
    /// @param amount Amount to repay
    function repay(uint256 amount) external {
        // Execute repay through orderbook
        orderbook.fulfillRepay(msg.sender, amount);
    }
    
    /// @notice Withdraw collateral from a specific pool
    /// @param poolIndex Index of the pool
    /// @param amount Amount of collateral to withdraw
    function withdrawCollateral(uint256 poolIndex, uint256 amount) external {
        require(poolIndex < pools.length, "Invalid pool index");
        
        LendingPool pool = pools[poolIndex];
        uint256 marketId = poolIndex + 1;
        
        pool.withdrawCollateral(marketId, amount, msg.sender, msg.sender);
    }
    
    // ============ VIEW FUNCTIONS ============
    
    function getPoolCount() external view returns (uint256) {
        return pools.length;
    }
    
    function getPool(uint256 index) external view returns (address) {
        return address(pools[index]);
    }
    
    function getAllPools() external view returns (address[] memory) {
        address[] memory poolAddresses = new address[](pools.length);
        for (uint256 i = 0; i < pools.length; i++) {
            poolAddresses[i] = address(pools[i]);
        }
        return poolAddresses;
    }
    
    function getOrderbook() external view returns (address) {
        return address(orderbook);
    }
    
    /// @notice Get current best rate available
    function getBestRate() external view returns (uint256) {
        return orderbook.getBestRate();
    }
    
    /// @notice Get all orders on the orderbook
    function getOrders() external view returns (Orderbook.Order[] memory) {
        return orderbook.getAllOrders();
    }
    
    /// @notice Refresh the orderbook manually
    function refreshOrderbook() external {
        orderbook.refreshOrderbook();
    }
    
    /// @notice Get pool statistics
    function getPoolStats(uint256 poolIndex) external view returns (
        uint256 totalSupply,
        uint256 totalBorrow,
        uint256 utilization,
        uint256 currentRate
    ) {
        require(poolIndex < pools.length, "Invalid pool index");
        
        LendingPool pool = pools[poolIndex];
        uint256 marketId = poolIndex + 1;
        
        (
            uint128 totalSupplyAssets,
            ,
            uint128 totalBorrowAssets,
            ,
            ,
        ) = pool.market(marketId);
        
        totalSupply = totalSupplyAssets;
        totalBorrow = totalBorrowAssets;
        
        if (totalSupply > 0) {
            utilization = (totalBorrow * WAD) / totalSupply;
        }
        
        // Get current rate from orderbook
        if (orderbook.getOrderbookSize() > 0) {
            currentRate = orderbook.getBestRate();
        }
    }
}