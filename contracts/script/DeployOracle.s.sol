// // SPDX-License-Identifier: MIT
// pragma solidity ^0.8.21;

// import "forge-std/Script.sol";
// import {PythOracle} from "../src/lending-core/PythOracle.sol";

// contract DeployOracle is Script {
//     PythOracle oracle;
//     address sepolia_pyth_address = 0xDd24F84d36BF92C65F92307595335bdFab5Bbd21;
//     function run() external returns(address){
//         vm.startBroadcast();
        
//         oracle = new PythOracle{value : 0.1 ether}(sepolia_pyth_address);
//         // payable(address(oracle)).
    
//         vm.stopBroadcast();
        
//         console.log("Oracle deployed at : ", address(oracle));
//         return address(oracle);
//     }
// }