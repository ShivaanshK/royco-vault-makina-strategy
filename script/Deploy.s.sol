// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "lib/forge-std/src/Script.sol";
import {console2} from "lib/forge-std/src/console2.sol";

contract DeployScript is Script {
    function run() external virtual {
        // Read deployer private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Read market name from config
        string memory strategyName = vm.envString("STRATEGY_NAME");

        console2.log("Deploying strategy from config:", strategyName);
        deployFromConfig(strategyName, deployerPrivateKey);
    }

    /// @notice Deploy a strategy using Solidity configuration
    /// @param strategyName The name of the strategy to deploy (must match a config in DeploymentConfig)
    /// @param deployerPrivateKey The private key of the deployer
    /// @return strategy The deployed strategy
    function deployFromConfig(string memory strategyName, uint256 deployerPrivateKey)
        public
        returns (address strategy)
    {}
}
