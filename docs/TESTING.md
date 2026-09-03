# Testing

Run Solidity tests with `pnpm contracts:test`. Run workspace checks with `pnpm typecheck` and `pnpm build`. Start support services with `docker compose -f infra/docker-compose.yml up -d`, then apply `packages/database/schema.sql`.

`pnpm simulate:economics` creates a 365-day 100-to-100,000 user stress scenario in `artifacts/economics`. It is an engineering scenario, not a return or price forecast. Run `tsx scripts/reconcile/daily.ts` with `DATABASE_URL` to store a daily reconciliation result.
