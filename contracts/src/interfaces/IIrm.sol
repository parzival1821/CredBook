// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import {MarketParams, Market} from "./IMorpho.sol";

interface IIrm {
    /// @notice Returns the borrow rate per second (scaled by WAD) of the market `marketParams`.
    /// @dev Assumes that `market` corresponds to `marketParams`.
    function borrowRate(MarketParams memory marketParams, Market memory market) external returns (uint256);

    /// @notice Returns the borrow rate per second (scaled by WAD) of the market `marketParams` without modifying any
    /// storage.
    /// @dev Assumes that `market` corresponds to `marketParams`.
    function borrowRateView(MarketParams memory marketParams, Market memory market) external view returns (uint256);
}