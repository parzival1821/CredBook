// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {
    IMorphoStaticTyping,
    IMorphoBase,
    MarketParams,
    Position,
    Market,
    Authorization,
    Signature
} from "../interfaces/IMorpho.sol";
import {IIrm} from "../interfaces/IIrm.sol";
import {IOracle} from "../interfaces/IOracle.sol";

uint256 constant WAD = 1e18;
// uint256 constant INTEREST_RATE = 633620772; // actual APY taken from block explorer - for compound 
// uint256 constant INTEREST_RATE = 1; // 1% simple interest per year
uint256 constant SECONDS_PER_YEAR = 365 * 24 * 60 * 60;
uint256 constant ORACLE_PRICE_SCALE = 1e36;

import {MathLib} from "../libraries/MathLib.sol";
import {SharesMathLib} from "../libraries/SharesMathLib.sol";
import {MarketParamsLib} from "../libraries/MarketParamsLib.sol";
import {ErrorsLib} from "../libraries/ErrorsLib.sol";
import {UtilsLib} from "../libraries/UtilsLib.sol";

contract LendingPool{
    using SharesMathLib for uint256;
    using MathLib for uint256;
    using MathLib for uint128;
    using UtilsLib for uint256;
    
    // Events 
    event Supply(uint256 indexed id, address indexed caller, address indexed onBehalf, uint256 assets, uint256 shares);
    event Withdraw(uint256 indexed id,address caller,address indexed onBehalf,address indexed receiver,uint256 assets,uint256 shares);
    event SupplyCollateral(uint256 indexed id, address indexed supplier, address indexed onBehalf, uint256 assets);
    event WithdrawCollateral(uint256 indexed id, address indexed supplier, address indexed onBehalf, address receiver, uint256 assets);
    event Borrow(uint256 indexed id, address indexed borrower, address indexed onBehalf, address receiver, uint256 assets, uint256 shares);
    event Repay(uint256 indexed id, address indexed repayer, address indexed onBehalf, uint256 assets, uint256 shares);

    // Storage
    mapping(uint256 => MarketParams) public idToMarketParams;
    mapping(uint256 => Market) public market;
    mapping(uint256 => mapping(address => Position)) public position;
    
    // Mock market configuration 
    // Id public constant MARKET_ID = Id.wrap(0xe9a9bb9ed3cc53f4ee9da4eea0370c2c566873d5de807e16559a99907c9ae227);

    uint256 public marketId = 1;
    
    uint256 public lastUpdateTimestamp;
    uint256 lltv = 800000000000000000; // 80% ltv

    // ✅
    constructor() {}

    function createMarket(MarketParams memory marketParams, uint256 id) external {
        // Safe "unchecked" cast.
        market[id].lastUpdate = uint128(block.timestamp);
        idToMarketParams[id] = marketParams;
    }

    function supply(
        uint256 id,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata
    ) external returns (uint256, uint256) {
        MarketParams memory marketParams = idToMarketParams[id];
        require(market[id].lastUpdate != 0, "Market not created");

        _accrueInterest(marketParams, id);

        if (assets > 0) shares = assets.toSharesDown(market[id].totalSupplyAssets, market[id].totalSupplyShares);
        else assets = shares.toAssetsUp(market[id].totalSupplyAssets, market[id].totalSupplyShares);

        position[id][onBehalf].supplyShares += shares;
        market[id].totalSupplyShares += shares.toUint128();
        market[id].totalSupplyAssets += assets.toUint128();

        emit Supply(id, msg.sender, onBehalf, assets, shares);

        IERC20(marketParams.loanToken).transferFrom(msg.sender, address(this), assets);

        return (assets, shares);
    }

    function withdraw(
        uint256 id,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256, uint256) {
        MarketParams memory marketParams = idToMarketParams[id];
        require(market[id].lastUpdate != 0, "Market not created");

        _accrueInterest(marketParams, id);

        if (assets > 0) shares = assets.toSharesUp(market[id].totalSupplyAssets, market[id].totalSupplyShares);
        else assets = shares.toAssetsDown(market[id].totalSupplyAssets, market[id].totalSupplyShares);

        position[id][onBehalf].supplyShares -= shares;
        market[id].totalSupplyShares -= shares.toUint128();
        market[id].totalSupplyAssets -= assets.toUint128();

        require(market[id].totalBorrowAssets <= market[id].totalSupplyAssets, ErrorsLib.INSUFFICIENT_LIQUIDITY);

        emit Withdraw(id, msg.sender, onBehalf, receiver, assets, shares);

        IERC20(marketParams.loanToken).transfer(receiver, assets);

        return (assets, shares);
    }
    
    // ✅
    function supplyCollateral(
        uint256 id,
        uint256 assets,
        address onBehalf,
        bytes calldata
    ) external {
        MarketParams memory marketParams = idToMarketParams[id];
        require(market[id].lastUpdate != 0, "Market not created");

        // Transfer collateral tokens to this contract
        IERC20(marketParams.collateralToken).transferFrom(msg.sender, address(this), assets);
        
        // Update position
        position[id][onBehalf].collateral += uint128(assets);
        
        emit SupplyCollateral(id, msg.sender, onBehalf, assets); // 1:1 ratio for simplicity
    }

    // ✅
    function withdrawCollateral(
        uint256 id,
        uint256 assets,
        address onBehalf,
        address receiver
    ) external {
        MarketParams memory marketParams = idToMarketParams[id];
        require(market[id].lastUpdate != 0, "Market not created");
        
        // Update market state with interest
        _accrueInterest(marketParams,id);
        
        Position storage pos = position[id][onBehalf];
        require(pos.collateral >= assets, "Insufficient collateral");
        
        pos.collateral -= uint128(assets);
        require(isHealthy(marketParams, id, onBehalf), "Unhealthy position");

        // Transfer collateral tokens to receiver
        IERC20(marketParams.collateralToken).transfer(receiver, assets);
        
        emit WithdrawCollateral(id, msg.sender, onBehalf, receiver, assets);
    }
    
    // ✅
    function borrow(
        uint256 id,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        address receiver
    ) external returns (uint256 assetsBorrowed, uint256 sharesBorrowed) {
        MarketParams memory marketParams = idToMarketParams[id];
        require(market[id].lastUpdate != 0, "Market not created");
        
        // Update market state with interest
        _accrueInterest(marketParams,id);
        
        // Use assets if shares is 0, otherwise use shares
        if (shares == 0) {
            sharesBorrowed = assets.toSharesUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);
            assetsBorrowed = assets;
        } else {
            assetsBorrowed = shares.toAssetsDown(market[id].totalBorrowAssets, market[id].totalBorrowShares);
            sharesBorrowed = shares;
        }
        
        // Update position and market
        Position storage pos = position[id][onBehalf];
        pos.borrowShares += uint128(sharesBorrowed);
        market[id].totalBorrowAssets += uint128(assetsBorrowed);
        market[id].totalBorrowShares += uint128(sharesBorrowed);
        
        require(isHealthy(marketParams, id, onBehalf), "Unhealthy position");

        // Transfer loan tokens to receiver
        IERC20(marketParams.loanToken).transfer(receiver, assetsBorrowed);
        
        emit Borrow(id, msg.sender, onBehalf, receiver, assetsBorrowed, sharesBorrowed);
    }
    

    // ✅
    function repay(
        uint256 id,
        uint256 assets,
        uint256 shares,
        address onBehalf,
        bytes calldata
    ) external returns (uint256 assetsRepaid, uint256 sharesRepaid) {
        MarketParams memory marketParams = idToMarketParams[id];
        require(market[id].lastUpdate != 0, "Market not created");

        // Update market state with interest
        _accrueInterest(marketParams,id);
        
        Position storage pos = position[id][onBehalf];
        
        // Calculate actual repayment amounts
        if (shares == 0) {
            sharesRepaid = assets.toSharesDown(market[id].totalBorrowAssets, market[id].totalBorrowShares);
            assetsRepaid = assets;
        } else {
            assetsRepaid = shares.toAssetsUp(market[id].totalBorrowAssets, market[id].totalBorrowShares);
            sharesRepaid = shares;
        }
        
        // Cap at actual borrowed amount
        if (sharesRepaid > pos.borrowShares) {
            sharesRepaid = pos.borrowShares;
            assetsRepaid = SharesMathLib.toAssetsDown(sharesRepaid, market[id].totalBorrowAssets, market[id].totalBorrowShares);
        }
        
        // Transfer loan tokens from sender
        IERC20(marketParams.loanToken).transferFrom(msg.sender, address(this), assetsRepaid);
        
        // Update position and market
        pos.borrowShares -= uint128(sharesRepaid);
        market[id].totalBorrowAssets -= uint128(assetsRepaid);
        market[id].totalBorrowShares -= uint128(sharesRepaid);
        
        
        emit Repay(id, msg.sender, onBehalf, assetsRepaid, sharesRepaid);
    }

    function accrueInterest(uint256 id) external{
        MarketParams memory marketParams = idToMarketParams[id];
        _accrueInterest(marketParams,id);
    }

    /// @dev Accrues interest for the given market `marketParams`.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function _accrueInterest(MarketParams memory marketParams, uint256 id) internal {
        uint256 elapsed = block.timestamp - market[id].lastUpdate;
        if (elapsed == 0) return;

        if (marketParams.irm != address(0)) {
            uint256 borrowRate = IIrm(marketParams.irm).borrowRate(marketParams, market[id]);
            uint256 interest = market[id].totalBorrowAssets.wMulDown(borrowRate.wTaylorCompounded(elapsed));
            market[id].totalBorrowAssets += interest.toUint128();
            market[id].totalSupplyAssets += interest.toUint128();
        }

        // Safe "unchecked" cast.
        market[id].lastUpdate = uint128(block.timestamp);
    }
    
    // View functions

    // ✅
    function borrowShares(uint256 id, address user) external view returns (uint256) {
        return position[id][user].borrowShares;
    }
    

    // ✅
    function collateral(uint256 id, address user) external view returns (uint256) {
        return position[id][user].collateral;
    }
    
    
    /* HEALTH CHECK */

    /// @dev Returns whether the position of `borrower` in the given market `marketParams` is healthy.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    function isHealthy(MarketParams memory marketParams, uint256 id, address borrower) public view returns (bool) {
        if (position[id][borrower].borrowShares == 0) return true;

        uint256 collateralPrice = 0;

        if(marketParams.oracle == address(1)){
            collateralPrice = 4000 * 1e24;
        } else {
            collateralPrice = IOracle(marketParams.oracle).price();
        }

        return _isHealthy(marketParams, id, borrower, collateralPrice);
    }

    /// @dev Returns whether the position of `borrower` in the given market `marketParams` with the given
    /// `collateralPrice` is healthy.
    /// @dev Assumes that the inputs `marketParams` and `id` match.
    /// @dev Rounds in favor of the protocol, so one might not be able to borrow exactly `maxBorrow` but one unit less.
    function _isHealthy(MarketParams memory marketParams, uint256 id, address borrower, uint256 collateralPrice)
        internal
        view
        returns (bool)
    {
        uint256 borrowed = uint256(position[id][borrower].borrowShares).toAssetsUp(
            market[id].totalBorrowAssets, market[id].totalBorrowShares
        );
        uint256 maxBorrow = uint256(position[id][borrower].collateral).mulDivDown(collateralPrice, ORACLE_PRICE_SCALE)
            .wMulDown(marketParams.lltv);

        return maxBorrow >= borrowed;
    }
    
    // ✅
    function setMarketLltv(uint256 id, uint256 newLltv) external {
        idToMarketParams[id].lltv = newLltv;
    }

    function setPosition(uint256 id,address user,uint256 _supplyShares, uint128 _borrowShares,uint128 _collateral) public {
        Position memory pos;
        pos.supplyShares = _supplyShares;
        pos.borrowShares = _borrowShares;
        pos.collateral = _collateral;
        position[id][user] = pos;
    }

    function setMarket(
        uint256 id,
        uint128 totalSupplyAssets,
        uint128 totalSupplyShares,
        uint128 totalBorrowAssets,
        uint128 totalBorrowShares,
        uint128 lastUpdate,
        uint128 fee
    ) public {
        market[id] = Market({
            totalSupplyAssets: totalSupplyAssets,
            totalSupplyShares: totalSupplyShares,
            totalBorrowAssets: totalBorrowAssets,
            totalBorrowShares: totalBorrowShares,
            lastUpdate: lastUpdate,
            fee: fee
        });
    }

    function getMarketParams(uint256 id) public view returns (MarketParams memory) {
    // (
    //     address loanToken,
    //     address collateralToken,
    //     address oracle,
    //     address irm,
    //     uint256 lltv
    // ) = idToMarketParams[id];
    
    // return MarketParams({
    //     loanToken: loanToken,
    //     collateralToken: collateralToken,
    //     oracle: oracle,
    //     irm: irm,
    //     lltv: lltv
    // });
        return idToMarketParams[id];
    }

    function getMarket(uint256 id) public view returns (Market memory){
        return market[id];
    }
}