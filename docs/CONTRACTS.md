# Contract modules

## Implemented foundation

- `ALPToken`: non-upgradeable fixed supply of 210,000,000 ALP; a one-time MainPair configuration; buy restriction; 17% sell fee split; no public or privileged mint path.
- `AssetRegistry`: governance registry keyed by asset ID. It records token, oracle, vault, launch time, risk status, and lifecycle state.
- `PartnerAssetVault`: per-partner-asset custody with sealed LOCK, BURN, LIQUIDITY, TREASURY, or REDEEM policy after its first contribution.
- `LaunchPool`: immutable partner-token/USDT 50/50 quoting and contribution workflow, including token decimal normalization, price validity checks, slippage ceiling, and immutable compensation/compute-weight snapshot.
- `GlobalComputeEngine`: O(1) global reward-index accounting and user claims; it never loops over positions at emission time.
- `EmissionEngine`: permissionless daily MainPair reserve settlement, burn, emission transfer, compute index update, and pair sync.
- `SponsorRegistry` / `ReferralRewardEngine`: irreversible sponsor bindings, effective-direct unlock depth, 20-level fixed schedule, and configurable USDT/compute reward split.
- `ProductionConfigValidator`: prevents production activation until an oracle, MainPair, Safe, timelock, compensation strategy, node funding source, and final reward split are recorded.

## Privilege model

The intended production owner/admin for every contract is a timelock-controlled Safe. Pools, epoch engine, and referral engine receive narrow roles instead of broad administrator ownership. The deployed Safe must grant `EMISSION_ENGINE_ROLE`, `EMISSION_ROLE`, `POOL_ROLE`, and treasury allowance only to addresses recorded in the deployment address book.

## Important deployment ordering

1. Deploy token, treasuries, compute engine, registry, validator, and strategy contracts.
2. Deploy/configure the pair and liquidity manager. Exempt only the authorized initialization path from sell fees and whitelist necessary protocol receivers for pair-originated transfers.
3. Deploy emission engine, grant its token/compute roles, and set the MainPair once.
4. Register an asset and deploy its vault/pool; grant only that pool the vault, compute, sponsor, and referral roles.
5. Transfer governance to the timelock/Safe; populate and verify the production validator before activation.

No address in this document is a deployment address. Testnet and mainnet address books are generated only by deployment scripts.
