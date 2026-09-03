# ALP implementation plan

## SECOND ROUND REMEDIATION

Status: **BSC Testnet development only. Not production ready.**

This checklist tracks the second-round acceptance remediation. Contract arithmetic and custody remain the source of truth; indexer, API, admin, and UI may only derive state from contracts and indexed events.

### P0 — Economic integrity and custody

- [x] Differential rewards use a monotonic `highestPaidRateBps` path algorithm; total paid never exceeds the highest reached tier rate.
- [x] Liquidity cycles take an independent balance snapshot at the start of each of four cycles.
- [x] P2P transfers retain the sender's active liquidity obligation; protocol and sell transfers remain narrowly exempt.
- [x] Fixed genesis supply is held by a restricted GenesisReserve with no arbitrary wallet withdrawal.
- [ ] Liquidity allocation reaches a real Pancake V2 add-liquidity flow using a configured, no-mint ALP source and permanent LP lock.
- [x] Main-pair bootstrap enforces the 0.0001 USDT ALP target price and one-time configuration.
- [x] Token privileged operations are narrowed to configured emission and cycle-manager entry points.
- [x] Emission activation requires compute; deferred emission is accounted for rather than stranded.
- [ ] Explicit Day-60 emission schedule and governance approval gate are documented and enforced for production.
- [x] Buyback supports timelocked, whitelisted multi-hop execution with independent oracle checks.
- [ ] OracleRouter supports Chainlink and Pancake V2 TWAP assets with stale, liquidity, and deviation checks.
- [x] Asset immutable fields seal after first active pool; mutable risk/oracle changes remain governed.
- [ ] ProtocolController and ProductionConfigValidator are wired as real production and emergency-pause gates.
- [ ] Referral, tier, solvency, Top100, node, and fee invariants are covered by tests.

### P1 — Operable BSC testnet protocol

- [ ] Testnet deployment scripts, verified address book, router/pair integration, and permanent LP proof.
- [ ] PostgreSQL schema, indexer with reorg handling, API read models, and reconciliation jobs.
- [ ] SIWE/RBAC admin app with Safe proposal generation and immutable audit log.
- [ ] Real wagmi/viem wallet integration and chain-derived user/public protocol data.

### P2 — Product, monitoring, and verification

- [ ] App Router web pages, asset/position details, cycle guidance, network graph pagination, Top100, and nodes.
- [ ] `next-intl` message catalogs for `en-US` and `zh-CN`; no component-local ad-hoc translation pairs.
- [ ] Shared UI package, mobile wallet flow, accessibility states, loading/error handling, and data visualization.
- [ ] Economics and attack simulations, fuzz/invariant/integration/fork tests, CI, Docker, monitoring, and full documentation.

### Completion evidence

- [ ] `forge test` passes after every material contract stage.
- [ ] `pnpm typecheck` and `pnpm build` pass after every material application stage.
- [ ] No claim of production readiness without external audit, Safe, timelock, approved production configuration, and actual mainnet deployment.

## Delivery rules

- Contract arithmetic and custody are the source of truth; the database and UI are derived views.
- No production launch occurs until an external audit, multisig, timelock, oracle configuration, and production configuration validation are complete.
- Unspecified economic choices remain parameterized and are blocked from production activation.

## Phase 0 — Foundation (in progress)

- [x] Initialize Turborepo workspace layout and environment template.
- [x] Define security boundaries, address-book workflow, and production safety gates.
- [x] Define the protocol contract module graph and fixed economics.
- [ ] Install reproducible Node/Foundry toolchain and lock dependencies.
- [ ] Establish CI, Docker development dependencies, code style, and secret scanning.

## Phase 1 — Smart contracts

- [ ] ALP fixed-supply token, transfer restriction, sell fee, and treasury split.
- [ ] Asset registry, OracleAdapter, partner vault strategies, pool factory, and 50/50 position entry.
- [ ] Global compute reward index, compensation strategies, emission/burn epoch settlement, and claims.
- [x] Initial fixed-supply token, registry, vault, launch-pool, global compute, compensation, and epoch-settlement implementation.
- [x] Sponsor registry, 20-level referral reward engine, and production configuration guard.
- [x] Chainlink price adapter with stale-data and incomplete-round rejection.
- [x] Launch Pool Factory and end-to-end 50/50 position creation with registry risk checks and referral activation.
- [x] V1–V9 Tier volume ledger with largest-branch exclusion and configurable volume base for new deployments.
- [x] Node registry and independently funded, Merkle-snapshot node-dividend claims.
- [x] Top100 Merkle distributor with rank/compute snapshot leaves and one-time claims.
- [x] Tier differential reward engine with non-overlapping 20-level rate deltas.
- [x] Four-cycle ALP liquidity requirement, permissionless forced-burn settlement, and deferred burn-debt enforcement.
- [x] Timelocked buyback executor with Router/Token whitelist, maximum trade, and Oracle slippage checks.
- [ ] Tier, node, Top100 Merkle, liquidity-cycle, buyback controls, and full integration tests.
- [ ] Foundry unit, fuzz, invariant, and fork tests.

## Phase 2 — Indexer and API

- [ ] Prisma schema, migrations, event projections, reorg handling, and replay.
- [ ] NestJS read API, SIWE authentication, RBAC, notification jobs, and reconciliation service.

## Phase 3 — User frontend

- [ ] Next.js web app, WalletConnect-compatible wallet flow, and address-book loading.
- [ ] Explore, asset detail, launch, portfolio, protocol, token-flow, network, node, and Top100 pages.
- [ ] i18n (en-US / zh-CN), error translation, responsive accessibility, and real chain/indexer reads.

## Phase 4 — Admin

- [ ] SIWE + RBAC admin app, audit log, safe/timelock action preparation, risk controls, and finance dashboards.

## Phase 5 — Verification

- [ ] Economic 365-day simulations and CSV/chart artifacts.
- [ ] Vitest, Playwright wallet mocks, mobile checks, Lighthouse, and reconciliation test fixtures.

## Phase 6 — BSC testnet deployment

- [ ] Deterministic deployment scripts, address book, verification, Safe ownership transfer, and testnet runbook.

## Phase 7 — Security hardening

- [ ] Independent audit remediation, monitoring alerts, incident runbook, mainnet dry run, and launch checklist.
