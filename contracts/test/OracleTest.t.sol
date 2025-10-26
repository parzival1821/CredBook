// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.21;

// import {Test} from "forge-std/Test.sol";
// import {console} from "forge-std/console.sol";
// import {PythOracle} from "../src/lending-core/PythOracle.sol";
// import {DeployOracle} from "../script/DeployOracle.s.sol";

// contract OracleTest is Test{
//     PythOracle oracle;

//     function setUp() public{
//         DeployOracle deployer = new DeployOracle();
//         oracle = PythOracle(deployer.run());
//     }

//     function testDeploymentWorks() public{
//         console.log(address(oracle));
//     }

//     function testPriceWorks() public{
//         console.log(oracle.price());
//     }
// }