// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { Script } from "lib/forge-std/src/Script.sol";
import { console2 } from "lib/forge-std/src/console2.sol";

/// @dev Address of the deterministic CREATE2 factory (deployed on all EVM chains)
address constant CREATE2_FACTORY_ADDRESS = 0x4e59b44847b379578588920cA78FbF26c0B4956C;

/**
 * @title Create2DeployUtils
 * @author Shivaansh Kapoor, Ankur Dubey
 * @notice Utility contract for deterministic CREATE2 deployments with sanity checks
 * @dev Provides helper functions for deploying contracts to predictable addresses across chains
 */
contract Create2DeployUtils is Script {
    /// @dev Thrown when the CREATE2 factory is not deployed on the current chain
    error NONEXISTANT_CREATE_2_DEPLOYER();

    /// @dev Thrown when the CREATE2 deployment call fails
    /// @param data The revert data from the failed deployment
    error DEPLOYMENT_FAILED(bytes data);

    /// @dev Thrown when attempting to deploy to an address that already has code
    /// @param deployedAddress The address that already contains a contract
    error CONTRACT_ALREADY_DEPLOYED(address deployedAddress);

    /// @dev Thrown when the deployed address doesn't match the expected CREATE2 address
    /// @param expectedAddress The computed CREATE2 address
    /// @param deployedAddress The actual address returned by the factory
    error DEPLOYED_TO_UNEXPECTED_ADDRESS(address expectedAddress, address deployedAddress);

    /// @dev Thrown when deployment succeeds but the address contains no bytecode
    /// @param deployedAddress The address that should contain bytecode
    error DEPLOYED_CONTRACT_CONTAINS_NO_CODE(address deployedAddress);

    /**
     * @notice Deploy a contract using CREATE2 with comprehensive sanity checks
     * @dev Checks for existing deployment, verifies factory existence, and validates deployed bytecode
     * @param _salt The salt for deterministic address generation
     * @param _creationCode The contract creation code including constructor arguments
     * @param _revertIfCONTRACT_ALREADY_DEPLOYED If true, reverts when contract already exists at computed address
     * @return The deployed contract address
     * @return isCONTRACT_ALREADY_DEPLOYED True if the contract was already deployed, false if newly deployed
     */
    function _deployWithSanityChecks(
        bytes32 _salt,
        bytes memory _creationCode,
        bool _revertIfCONTRACT_ALREADY_DEPLOYED
    )
        internal
        returns (address, bool isCONTRACT_ALREADY_DEPLOYED)
    {
        bool debug = vm.envOr("DEBUG", false);

        if (CREATE2_FACTORY_ADDRESS.code.length == 0) {
            revert NONEXISTANT_CREATE_2_DEPLOYER();
        }

        address expectedAddress = _generateDeterminsticAddress(_salt, _creationCode);

        if (address(expectedAddress).code.length != 0) {
            if (debug) console2.log("Contract already deployed at: ", expectedAddress);

            require(!_revertIfCONTRACT_ALREADY_DEPLOYED, CONTRACT_ALREADY_DEPLOYED(expectedAddress));

            return (expectedAddress, true);
        }

        address addr = _deploy(_salt, _creationCode);

        require(addr == expectedAddress, DEPLOYED_TO_UNEXPECTED_ADDRESS(expectedAddress, addr));
        require(address(addr).code.length != 0, DEPLOYED_CONTRACT_CONTAINS_NO_CODE(addr));

        if (debug) console2.log("Contract deployed at: ", addr);

        return (addr, false);
    }

    /**
     * @notice Compute the deterministic CREATE2 address for a given salt and creation code
     * @dev Uses the standard CREATE2 address derivation: keccak256(0xff ++ factory ++ salt ++ keccak256(creationCode))
     * @param _salt The salt for address generation
     * @param _creationCode The contract creation code including constructor arguments
     * @return The computed deterministic address
     */
    function _generateDeterminsticAddress(bytes32 _salt, bytes memory _creationCode) internal pure returns (address) {
        bytes32 hash = keccak256(abi.encodePacked(bytes1(0xff), CREATE2_FACTORY_ADDRESS, _salt, keccak256(_creationCode)));
        return address(uint160(uint256(hash)));
    }

    /**
     * @notice Execute the CREATE2 deployment via the factory
     * @dev Makes a low-level call to the CREATE2 factory with salt prepended to creation code
     * @param _salt The salt for deterministic deployment
     * @param _creationCode The contract creation code including constructor arguments
     * @return deployedAddress The address of the deployed contract
     */
    function _deploy(bytes32 _salt, bytes memory _creationCode) private returns (address deployedAddress) {
        // solhint-disable-next-line avoid-low-level-calls
        (bool success, bytes memory data) = CREATE2_FACTORY_ADDRESS.call(abi.encodePacked(_salt, _creationCode));

        require(success, DEPLOYMENT_FAILED(data));

        // solhint-disable-next-line no-inline-assembly
        assembly ("memory-safe") {
            deployedAddress := shr(0x60, mload(add(data, 0x20)))
        }
    }
}
