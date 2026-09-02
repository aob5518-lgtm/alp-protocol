# ALP implementation plan

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
