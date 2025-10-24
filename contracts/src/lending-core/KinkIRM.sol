// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IIrm} from "../interfaces/IIrm.sol";
import {MarketParams, Market} from "../interfaces/IMorpho.sol";
import {MathLib} from "../libraries/MathLib.sol";

contract KinkIRM is IIrm {
    using MathLib for uint256;
    
    uint256 public immutable BASE_RATE; // Rate at 0% utilization
    uint256 public immutable KINK; // Utilization at kink point (scaled by WAD, e.g., 0.8e18 = 80%)
    uint256 public immutable SLOPE_1; // Slope before kink
    uint256 public immutable SLOPE_2; // Slope after kink
    
    constructor(uint256 baseRate, uint256 kink, uint256 slope1, uint256 slope2) {
        BASE_RATE = baseRate;
        KINK = kink;
        SLOPE_1 = slope1;
        SLOPE_2 = slope2;
    }
    
    function borrowRate(MarketParams memory marketParams, Market memory market) 
        external 
        view 
        returns (uint256) 
    {
        return _calculateRate(market);
    }
    
    function borrowRateView(MarketParams memory marketParams, Market memory market) 
        external 
        view 
        returns (uint256) 
    {
        return _calculateRate(market);
    }
    
    function _calculateRate(Market memory market) internal view returns (uint256) {
        if (market.totalSupplyAssets == 0) return BASE_RATE;
        
        uint256 utilization = uint256(market.totalBorrowAssets).wDivUp(market.totalSupplyAssets);
        
        if (utilization <= KINK) {
            // Before kink: rate = baseRate + slope1 * utilization
            return BASE_RATE + utilization.wMulDown(SLOPE_1);
        } else {
            // After kink: rate = baseRate + slope1 * kink + slope2 * (utilization - kink)
            uint256 rateAtKink = BASE_RATE + KINK.wMulDown(SLOPE_1);
            uint256 excessUtilization = utilization - KINK;
            return rateAtKink + excessUtilization.wMulDown(SLOPE_2);
        }
    }
}