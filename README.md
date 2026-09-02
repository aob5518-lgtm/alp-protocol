# Asset Launch Protocol (ALP)

ALP is an EVM-compatible protocol for launching partner assets through 50/50 partner-asset and USDT positions, with transparent ALP emissions and global compute accounting.

> Status: active implementation. This repository is not production-ready and contains no deployed production contracts.

## Safety boundary

This repository must be independently audited before handling user funds. Production activation is intentionally guarded by the on-chain production configuration validator, a timelock, and a Safe multisig.

## Local development

1. Install Node.js 22+ and pnpm 11+.
2. Copy `.env.example` to `.env` and fill only local/testnet values.
3. Start dependencies with `docker compose -f infra/docker-compose.yml up -d`.
4. Install packages with `pnpm install`.
5. Run all services with `pnpm dev`.
6. Run Solidity tests with `pnpm contracts:test`.

See `docs/ALP_IMPLEMENTATION_PLAN.md` for delivery status and `docs/DEPLOYMENT.md` before any deployment.
