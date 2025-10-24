// SPDX-License-Identifier: MIT
pragma solidity ^0.8.21;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MockWETH is ERC20 {
    constructor() ERC20("Wrapped Ether", "WETH") {
        _mint(msg.sender, 1000 * 10**18); // 1000 WETH (18 decimals)
    }
    
    function mint(address to, uint256 amount) external {
        _mint(to, amount);
    }
}