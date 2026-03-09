# Royco Vault Makina Strategy [![CI](https://github.com/roycoprotocol/royco-vault-makina-strategy/actions/workflows/test.yml/badge.svg)](https://github.com/roycoprotocol/royco-vault-makina-strategy/actions/workflows/test.yml)

A strategy contract enabling Royco vaults to allocate assets into Makina machines.

## Overview

`RoycoVaultMakinaStrategy` serves as a bridge between Royco's vaults and Makina's yield-generating machines. The strategy implements `IStrategyTemplate` and handles:

- **Allocation**: Deposits vault assets into a Makina machine, receiving share tokens
- **Deallocation**: Redeems shares from the machine, returning assets to the vault
- **Withdrawals**: Supports user-initiated withdrawals through the vault's deallocation flow

## Architecture

```
Royco Vault <──> Strategy <──> Makina Machine
     │              │               │
     │   allocate   │    deposit    │
     ├─────────────>├──────────────>│
     │              │               │
     │  deallocate  │    redeem     │
     │<─────────────┤<──────────────┤
```

## Requirements

- Strategy must be configured as the depositor and redeemer on the Makina machine
- Royco vault and Makina machine must share the same base asset
- Strategy must be added to the vault's strategy list and deallocation order

## Build

```bash
forge build
```

## Test

```bash
forge test
```

## Deploy

```bash
forge script script/Deploy.s.sol --rpc-url <RPC_URL> --private-key <PRIVATE_KEY> --broadcast
```

## Configuration

Deployment configs are defined in `script/config/DeploymentConfig.sol`. Each strategy requires:

- `roycoVault`: Address of the Royco vault
- `makinaMachine`: Address of the Makina machine
- `strategyType`: Operational type (ATOMIC, ASYNC, or CROSSCHAIN)

## Security

- Access controlled via the Royco Dawn Factory which uses OpenZeppelin's `AccessManaged`
- Pausable by authorized admins
- Token rescue function excludes machine share tokens to protect accounting


