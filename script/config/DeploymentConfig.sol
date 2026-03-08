// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import {StrategyType} from "../../src/RoycoVaultMakinaStrategy.sol";

/**
 * @title DeploymentConfig
 * @notice Single configuration contract for all deployment parameters
 */
abstract contract DeploymentConfig {
    uint256 internal constant MAINNET = 1;

    string internal constant ROYCO_DAWN_SENIOR_VAULT = "DSV";

    // TODO: Update with new factory once deployed
    // Deployed using CREATE2, so the address is the same on all chain
    address internal constant ROYCO_FACTORY_ADDRESS = 0xD567cCbb336Eb71eC2537057E2bCF6DB840bB71d;

    /// @dev Address of the Royco Dawn Senior Vault
    address internal constant DSV = 0xcD9f5907F92818bC06c9Ad70217f089E190d2a32;

    /// @dev Address of the DUSD Makina Machine
    address internal constant DUSD_MAKINA_MACHINE = 0x6b006870C83b1Cd49E766Ac9209f8d68763Df721;

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

    function _initializeStrategyConfigs() internal {
        _strategyConfigs[ROYCO_DAWN_SENIOR_VAULT] = StrategyDeploymentConfig({
            roycoFactory: ROYCO_FACTORY_ADDRESS,
            roycoVault: DSV,
            makinaMachine: DUSD_MAKINA_MACHINE,
            strategyType: StrategyType.ASYNC
        });
    }
}
