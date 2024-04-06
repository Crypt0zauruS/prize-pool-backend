// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import "forge-std/Script.sol";
import {Pool} from "../src/Pool.sol";

// This is a script that deploys a Pool contract
// First we launch the anvil test blockchain with `anvil`
// Then we copy paste a private key from the output to the .env file

contract MyScript is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        vm.startBroadcast(deployerPrivateKey);
        // elements for the constructor
        uint256 end = 4 weeks;
        uint256 goal = 10 ether;
        Pool pool = new Pool(end, goal);
        vm.stopBroadcast();
    }
}

// Command to deploy the contract to anvil:
// forge script script/Deploy.s.sol:MyScript --fork-url http://localhost:8545 --broadcast
