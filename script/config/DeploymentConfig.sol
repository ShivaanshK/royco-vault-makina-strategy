// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {StrategyType} from "../../src/RoycoVaultMakinaStrategy.sol";

/**
 * @title DeploymentConfig
 * @notice Single configuration contract for all deployment parameters
 */
abstract contract DeploymentConfig {
    uint256 internal constant MAINNET = 1;

    // TODO: Update with new factory
    address internal constant ROYCO_FACTORY_ADDRESS = 0xD567cCbb336Eb71eC2537057E2bCF6DB840bB71d;

    struct StrategyDeploymentConfig {
        address roycoFactory;
        address roycoVault;
        address makinaMachine;
        StrategyType strategyType;
    }

    mapping(string strategyName => StrategyDeploymentConfig) internal _strategyConfigs;

    constructor() {
        _initializeStrategyConfigs();
    }

    function _initializeStrategyConfigs() internal {}
}
