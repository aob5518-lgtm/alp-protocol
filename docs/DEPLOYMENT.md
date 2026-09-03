# BSC Testnet deployment runbook

Status: **BSC Testnet development only. Do not use this process for mainnet.**

The address book at `deployments/bsc-testnet.json` is deliberately a template. It must contain only addresses emitted by a successful testnet deployment and post-deployment verification. Do not manually paste guessed contract addresses.

## Preconditions

1. Run the complete local contract suite: `pnpm contracts:test`.
2. Use BSC Testnet (chain ID `97`) and a dedicated testnet deployer funded only with test BNB.
3. Populate `.env` from `.env.example`. `USDT_ADDRESS`, `PANCAKE_V2_ROUTER`, and `PANCAKE_V2_FACTORY` must be deployed contracts on the connected chain. `SAFE_ADDRESS` and `TIMELOCK_ADDRESS` cannot be zero.
4. Transfer the administrative roles to the test Safe/timelock only after checking every deployment address and role assignment.

## Mandatory preflight

From `packages/contracts`, run:

```powershell
forge script script/BscTestnetPreflight.s.sol:BscTestnetPreflight --rpc-url $env:RPC_URL
```

This command is read-only. It fails if the RPC points at the wrong chain, an external dependency has no bytecode, or governance addresses are missing.

## Post-deployment checklist

- Record the transaction hashes, deployed bytecode hashes, block number, Git commit, and verified explorer links in the address book release artifact.
- Confirm `GenesisReserve` is the sole initial ALP holder and only registered protocol modules can move it.
- Confirm the bootstrapper is the only initial main-pair writer; verify LP balance is held by `PermanentLiquidityLocker`.
- Confirm `ProtocolController` guardian/governance roles and all production-validator fields before enabling any production flag.
- Exercise a small testnet position, liquidity add, pause/resume, and one time-locked buyback in a disposable test configuration.

Mainnet remains prohibited until an independent audit, approved Safe/timelock configuration, verified oracle feeds, formal deployment review, and an explicit user-authorized mainnet release.
