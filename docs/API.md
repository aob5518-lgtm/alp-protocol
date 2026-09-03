# API

The API is a read model over idempotently indexed chain events. It does not manufacture protocol balances.

- `GET /health` checks PostgreSQL reachability.
- `GET /v1/assets`, `/v1/protocol`, and `/v1/portfolio/:wallet` expose indexed projections.
- `GET /v1/auth/nonce` then `POST /v1/auth/siwe` establishes a short-lived signed-in session.
- `GET /v1/admin/audit` requires `AUDITOR` or higher.
- `POST /v1/admin/proposals` records a Safe proposal draft only; it never transmits a transaction.

Run the API with `DATABASE_URL=postgresql://alp:alp@localhost:5432/alp API_PORT=4000 pnpm --dir apps/api dev`.
