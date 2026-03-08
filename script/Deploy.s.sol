// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {Script} from "lib/forge-std/src/Script.sol";
import {DeploymentConfig} from "./config/DeploymentConfig.sol";
import {console2} from "lib/forge-std/src/console2.sol";
import {RoycoVaultMakinaStrategy} from "../src/RoycoVaultMakinaStrategy.sol";
import {Create2DeployUtils} from "./utils/Create2DeployUtils.sol";

contract DeployScript is Script, Create2DeployUtils, DeploymentConfig {
    bytes32 internal constant STRATEGY_DEPLOYMENT_SALT = keccak256(abi.encode("ROYCO_VAULT_MAKINA_STRATEGY"));

    function run() external virtual {
        // Read deployer private key
        uint256 deployerPrivateKey = vm.envUint("DEPLOYER_PRIVATE_KEY");

        // Read market name from config
        string memory strategyName = vm.envString("STRATEGY_NAME");

        console2.log("Deploying Makina strategy from config:", strategyName);
        deployFromConfig(strategyName, deployerPrivateKey);
    }

    /// @notice Deploy a strategy using Solidity configuration
    /// @param _strategyName The name of the strategy to deploy (must match a config in DeploymentConfig)
    /// @param _deployerPrivateKey The private key of the deployer
    /// @return strategy The deployed strategy
    function deployFromConfig(string memory _strategyName, uint256 _deployerPrivateKey)
        public
        returns (address strategy)
    {
        StrategyDeploymentConfig memory config = _strategyConfigs[_strategyName];

        bytes memory strategyCreationCode = abi.encodePacked(
            type(RoycoVaultMakinaStrategy).creationCode,
            abi.encode(config.roycoFactory, config.roycoVault, config.makinaMachine, config.strategyType)
        );

        vm.startBroadcast(_deployerPrivateKey);

        bool alreadyDeployed;
        (strategy, alreadyDeployed) = _deployWithSanityChecks(STRATEGY_DEPLOYMENT_SALT, strategyCreationCode, false);

        vm.stopBroadcast();

        if (alreadyDeployed) {
            console2.log(_strategyName, " Makina Strategy already deployed at:", strategy);
        } else {
            console2.log(_strategyName, " Makina Strategy deployed at:", strategy);
        }
    }
}
