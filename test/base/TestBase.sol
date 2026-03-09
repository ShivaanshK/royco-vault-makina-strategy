// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.28;

import { IAllocateModule } from "lib/concrete-earn-v2-bug-bounty/src/interface/IAllocateModule.sol";
import { IConcreteStandardVaultImpl } from "lib/concrete-earn-v2-bug-bounty/src/interface/IConcreteStandardVaultImpl.sol";
import { ConcreteV2RolesLib } from "lib/concrete-earn-v2-bug-bounty/src/lib/Roles.sol";
import { Test } from "lib/forge-std/src/Test.sol";
import { Vm } from "lib/forge-std/src/Vm.sol";
import { IMachine } from "lib/makina-core/src/interfaces/IMachine.sol";
import { IAccessControlEnumerable } from "lib/openzeppelin-contracts/contracts/access/extensions/IAccessControlEnumerable.sol";
import { IAccessManager } from "lib/openzeppelin-contracts/contracts/access/manager/IAccessManager.sol";
import { IERC4626 } from "lib/openzeppelin-contracts/contracts/interfaces/IERC4626.sol";
import { IERC20 } from "lib/openzeppelin-contracts/contracts/token/ERC20/IERC20.sol";
import { DeployScript } from "script/Deploy.s.sol";
import { DeploymentConfig, StrategyType } from "script/config/DeploymentConfig.sol";
import { RoycoVaultMakinaStrategy } from "src/RoycoVaultMakinaStrategy.sol";

abstract contract TestBase is Test, DeploymentConfig {
    // -----------------------------------------
    // Test Wallets
    // -----------------------------------------
    Vm.Wallet internal DEPLOYER;
    address internal DEPLOYER_ADDRESS;

    Vm.Wallet internal ALICE;
    address internal ALICE_ADDRESS;

    Vm.Wallet internal BOB;
    address internal BOB_ADDRESS;

    // -----------------------------------------
    // Deploy Script
    // -----------------------------------------
    DeployScript internal DEPLOY_SCRIPT;

    // -----------------------------------------
    // Core Contracts (from deployment)
    // -----------------------------------------
    RoycoVaultMakinaStrategy internal STRATEGY;
    IConcreteStandardVaultImpl internal ROYCO_VAULT;
    IMachine internal MAKINA_MACHINE;
    IERC20 internal ASSET;
    IERC20 internal MACHINE_SHARE_TOKEN;

    // -----------------------------------------
    // Fork Configuration
    // -----------------------------------------
    uint256 internal forkId;

    // -----------------------------------------
    // Modifiers
    // -----------------------------------------
    modifier prankModifier(address _pranker) {
        vm.startPrank(_pranker);
        _;
        vm.stopPrank();
    }

    // -----------------------------------------
    // Setup Functions
    // -----------------------------------------
    function _setUpFork() internal virtual {
        (uint256 forkBlock, string memory forkRpcUrl) = _forkConfiguration();
        require(bytes(forkRpcUrl).length > 0, "Fork RPC URL required");
        forkId = vm.createSelectFork(forkRpcUrl, forkBlock);
    }

    function _setUpTestBase(string memory _strategyName) internal virtual {
        _setUpFork();
        _setupWallets();
        _loadDeploymentConfig(_strategyName);

        // Deploy the deploy script
        DEPLOY_SCRIPT = new DeployScript();
    }

    function _setupWallets() internal {
        DEPLOYER = _initWallet("DEPLOYER", 1000 ether);
        DEPLOYER_ADDRESS = DEPLOYER.addr;

        ALICE = _initWallet("ALICE", 1000 ether);
        ALICE_ADDRESS = ALICE.addr;

        BOB = _initWallet("BOB", 1000 ether);
        BOB_ADDRESS = BOB.addr;
    }

    function _loadDeploymentConfig(string memory _strategyName) internal {
        StrategyDeploymentConfig memory config = _strategyConfigs[_strategyName];

        ROYCO_VAULT = IConcreteStandardVaultImpl(config.roycoVault);
        MAKINA_MACHINE = IMachine(config.makinaMachine);
        ASSET = IERC20(IERC4626(config.roycoVault).asset());
        MACHINE_SHARE_TOKEN = IERC20(MAKINA_MACHINE.shareToken());

        vm.label(address(ROYCO_VAULT), "ROYCO_VAULT");
        vm.label(address(MAKINA_MACHINE), "MAKINA_MACHINE");
        vm.label(address(ASSET), "ASSET");
        vm.label(address(MACHINE_SHARE_TOKEN), "MACHINE_SHARE_TOKEN");
    }

    /// @notice Deploys the strategy using the deployment script
    /// @param _strategyName The name of the strategy config to use
    function _deployStrategy(string memory _strategyName) internal returns (RoycoVaultMakinaStrategy) {
        // Deploy using the deployment script
        address strategyAddress = DEPLOY_SCRIPT.deployFromConfig(_strategyName, DEPLOYER.privateKey);
        STRATEGY = RoycoVaultMakinaStrategy(strategyAddress);
        vm.label(strategyAddress, string.concat(_strategyName, " STRATEGY"));

        // Configure strategy on the Royco vault
        _addStrategyToVault();

        // Configure strategy on Makina machine
        _configureStrategyOnMachine();

        // Configure factory to allow deployer to call restricted functions
        _configureFactoryAdmin();

        return STRATEGY;
    }

    // -----------------------------------------
    // Royco Vault Configuration
    // -----------------------------------------

    /// @notice Adds the strategy to the Royco vault and configures deallocation order
    /// @dev Requires impersonating accounts with STRATEGY_MANAGER and ALLOCATOR roles
    function _addStrategyToVault() internal {
        // Get a STRATEGY_MANAGER role holder and add strategy
        address strategyManager = _getRoleHolder(address(ROYCO_VAULT), ConcreteV2RolesLib.STRATEGY_MANAGER);
        vm.prank(strategyManager);
        ROYCO_VAULT.addStrategy(address(STRATEGY));

        // Get an ALLOCATOR role holder and add strategy to deallocation order
        address allocator = _getRoleHolder(address(ROYCO_VAULT), ConcreteV2RolesLib.ALLOCATOR);
        address[] memory currentOrder = ROYCO_VAULT.getDeallocationOrder();
        address[] memory newOrder = new address[](currentOrder.length + 1);
        for (uint256 i = 0; i < currentOrder.length; i++) {
            newOrder[i] = currentOrder[i];
        }
        newOrder[currentOrder.length] = address(STRATEGY);

        vm.prank(allocator);
        ROYCO_VAULT.setDeallocationOrder(newOrder);
    }

    /// @notice Gets the first account that holds a specific role on the vault
    function _getRoleHolder(address _vault, bytes32 _role) internal view returns (address) {
        uint256 count = IAccessControlEnumerable(_vault).getRoleMemberCount(_role);
        require(count > 0, "No role holder found");
        return IAccessControlEnumerable(_vault).getRoleMember(_role, 0);
    }

    /// @notice Gets an authorized admin address that can manage the strategy
    /// @dev Returns the deployer address which is granted admin role on the factory
    function _getAuthorizedAdmin() internal view returns (address) {
        return DEPLOYER_ADDRESS;
    }

    /// @notice Configures the Royco Factory to allow the deployer to call restricted functions
    /// @dev Mocks the canCall check to return true for the deployer on all strategy functions
    function _configureFactoryAdmin() internal {
        // Mock canCall to return (true, 0) for deployer on any strategy function
        vm.mockCall(
            ROYCO_FACTORY_ADDRESS, abi.encodeWithSelector(IAccessManager.canCall.selector, DEPLOYER_ADDRESS, address(STRATEGY)), abi.encode(true, uint32(0))
        );
    }

    // -----------------------------------------
    // Makina Machine Configuration
    // -----------------------------------------

    /// @dev EIP-7201 storage slot for Makina Machine storage
    /// keccak256(abi.encode(uint256(keccak256("makina.storage.Machine")) - 1)) & ~bytes32(uint256(0xff))
    bytes32 private constant MACHINE_STORAGE_LOCATION = 0x55fe2a17e400bcd0e2125123a7fc955478e727b29a4c522f4f2bd95d961bd900;

    /// @dev Slot offset for _depositor in MachineStorage struct (after _shareToken, _accountingToken)
    uint256 private constant DEPOSITOR_SLOT_OFFSET = 2;

    /// @dev Slot offset for _redeemer in MachineStorage struct (after _shareToken, _accountingToken, _depositor)
    uint256 private constant REDEEMER_SLOT_OFFSET = 3;

    /// @notice Configures the strategy as depositor and redeemer on the Makina machine
    /// @dev Uses vm.store to directly set the depositor/redeemer storage slots
    function _configureStrategyOnMachine() internal {
        _setMachineDepositor(address(STRATEGY));
        _setMachineRedeemer(address(STRATEGY));
    }

    /// @notice Sets the depositor on the Makina machine via storage manipulation
    function _setMachineDepositor(address _depositor) internal {
        bytes32 slot = bytes32(uint256(MACHINE_STORAGE_LOCATION) + DEPOSITOR_SLOT_OFFSET);
        vm.store(address(MAKINA_MACHINE), slot, bytes32(uint256(uint160(_depositor))));
    }

    /// @notice Sets the redeemer on the Makina machine via storage manipulation
    function _setMachineRedeemer(address _redeemer) internal {
        bytes32 slot = bytes32(uint256(MACHINE_STORAGE_LOCATION) + REDEEMER_SLOT_OFFSET);
        vm.store(address(MAKINA_MACHINE), slot, bytes32(uint256(uint160(_redeemer))));
    }

    // -----------------------------------------
    // Fork Configuration (override in child)
    // -----------------------------------------
    function _forkConfiguration() internal view virtual returns (uint256 forkBlock, string memory forkRpcUrl);

    // -----------------------------------------
    // Utility Functions
    // -----------------------------------------
    function _initWallet(string memory _name, uint256 _amount) internal returns (Vm.Wallet memory) {
        Vm.Wallet memory wallet = vm.createWallet(_name);
        vm.label(wallet.addr, _name);
        vm.deal(wallet.addr, _amount);
        return wallet;
    }

    function _encodeAllocationParams(uint256 _amount, uint256 _minSharesOut) internal pure returns (bytes memory) {
        return abi.encode(_amount, _minSharesOut);
    }

    function _encodeDeallocationParams(uint256 _sharesToRedeem, uint256 _minAssetsOut) internal pure returns (bytes memory) {
        return abi.encode(_sharesToRedeem, _minAssetsOut);
    }

    function _dealAsset(address _to, uint256 _amount) internal {
        deal(address(ASSET), _to, _amount);
    }

    /// @notice Deals assets to the Makina machine to ensure liquidity for redemptions
    function _dealAssetToMachine(uint256 _amount) internal {
        deal(address(ASSET), address(MAKINA_MACHINE), _amount);
    }

    /// @notice Gets the current machine liquidity available for withdrawal
    function _getMachineLiquidity() internal view returns (uint256) {
        return ASSET.balanceOf(address(MAKINA_MACHINE));
    }

    /// @notice Gets the strategy's current share balance in the machine
    function _getStrategyShares() internal view returns (uint256) {
        return MACHINE_SHARE_TOKEN.balanceOf(address(STRATEGY));
    }

    /// @notice Gets the strategy's current allocated value
    function _getStrategyAllocatedValue() internal view returns (uint256) {
        return STRATEGY.totalAllocatedValue();
    }

    // -----------------------------------------
    // Vault Allocation Helpers
    // -----------------------------------------

    /// @notice Allocates assets from vault to strategy through proper vault flow
    /// @param _amount Amount of assets to allocate
    /// @param _minSharesOut Minimum shares expected (slippage protection)
    function _allocateToStrategy(uint256 _amount, uint256 _minSharesOut) internal {
        address allocator = _getRoleHolder(address(ROYCO_VAULT), ConcreteV2RolesLib.ALLOCATOR);

        IAllocateModule.AllocateParams[] memory params = new IAllocateModule.AllocateParams[](1);
        params[0] = IAllocateModule.AllocateParams({ isDeposit: true, strategy: address(STRATEGY), extraData: _encodeAllocationParams(_amount, _minSharesOut) });

        vm.prank(allocator);
        ROYCO_VAULT.allocate(abi.encode(params));
    }

    /// @notice Deallocates assets from strategy back to vault through proper vault flow
    /// @param _sharesToRedeem Shares to redeem from machine
    /// @param _minAssetsOut Minimum assets expected (slippage protection)
    function _deallocateFromStrategy(uint256 _sharesToRedeem, uint256 _minAssetsOut) internal {
        address allocator = _getRoleHolder(address(ROYCO_VAULT), ConcreteV2RolesLib.ALLOCATOR);

        IAllocateModule.AllocateParams[] memory params = new IAllocateModule.AllocateParams[](1);
        params[0] = IAllocateModule.AllocateParams({
            isDeposit: false, strategy: address(STRATEGY), extraData: _encodeDeallocationParams(_sharesToRedeem, _minAssetsOut)
        });

        vm.prank(allocator);
        ROYCO_VAULT.allocate(abi.encode(params));
    }
}
