# Architecture

ALP separates custody, accounting, and presentation:

```text
Wallet -> LaunchPool -> PartnerAssetVault (partner token)
                     -> RewardTreasury / LiquidityManager (USDT)
LaunchPool -> GlobalComputeEngine -> EmissionDistributor -> ALP claims
ALP/USDT MainPair <- EmissionEngine burns / transfers -> Epoch records
Chain events -> Indexer -> PostgreSQL -> API -> Web/Admin
```

`AssetRegistry` stores each asset's address, price adapter, vault, launch status, and risk status. `LaunchPoolFactory` creates pools against registered assets rather than embedding CARD-specific addresses. On-chain events are canonical; the indexer can be replayed from its configured block.

Critical administrative actions are designed for a Safe multisig behind a timelock. An ordinary backend administrator has no custody authority.
