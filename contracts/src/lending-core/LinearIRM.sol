// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {IIrm} from "../interfaces/IIrm.sol";
import {MarketParams, Market} from "../interfaces/IMorpho.sol";
import {MathLib} from "../libraries/MathLib.sol";

contract LinearIRM is IIrm {
    using MathLib for uint256;
    
    uint256 public immutable BASE_RATE; // Rate at 0% utilization (scaled by WAD)
    uint256 public immutable SLOPE; // Rate increase per utilization (scaled by WAD)
    
    constructor(uint256 baseRate, uint256 slope) {
        BASE_RATE = baseRate;
        SLOPE = slope;
    }
    
    function borrowRate(MarketParams memory, Market memory market) 
        external 
        view 
        returns (uint256) 
    {
        return _calculateRate(market);
    }
    
    function borrowRateView(MarketParams memory, Market memory market) 
        external 
        view 
        returns (uint256) 
    {
        return _calculateRate(market);
    }
    
    function _calculateRate(Market memory market) internal view returns (uint256) {
        if (market.totalSupplyAssets == 0) return BASE_RATE;
        
        // utilization = totalBorrowAssets / totalSupplyAssets (in WAD)
        uint256 utilization = uint256(market.totalBorrowAssets).wDivUp(market.totalSupplyAssets);
        
        // rate = baseRate + slope * utilization
        uint256 rate = BASE_RATE + utilization.wMulDown(SLOPE);
        
        return rate;
    }
}