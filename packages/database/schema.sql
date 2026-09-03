CREATE TABLE IF NOT EXISTS chain_blocks (
  chain_id BIGINT NOT NULL, number BIGINT NOT NULL, hash TEXT NOT NULL, parent_hash TEXT NOT NULL,
  indexed_at TIMESTAMPTZ NOT NULL DEFAULT now(), PRIMARY KEY (chain_id, number)
);
CREATE TABLE IF NOT EXISTS indexed_events (
  chain_id BIGINT NOT NULL, tx_hash TEXT NOT NULL, log_index INTEGER NOT NULL, block_number BIGINT NOT NULL,
  block_hash TEXT NOT NULL, contract_address TEXT NOT NULL, event_name TEXT NOT NULL, payload JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(), PRIMARY KEY (chain_id, tx_hash, log_index)
);
CREATE TABLE IF NOT EXISTS assets (asset_id BIGINT PRIMARY KEY, token_address TEXT NOT NULL UNIQUE, symbol TEXT NOT NULL, name TEXT NOT NULL, oracle_address TEXT, vault_address TEXT, launch_status TEXT NOT NULL, risk_status TEXT NOT NULL, sealed BOOLEAN NOT NULL DEFAULT false, updated_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS launch_pools (pool_address TEXT PRIMARY KEY, asset_id BIGINT NOT NULL REFERENCES assets(asset_id), created_block BIGINT NOT NULL, owner_address TEXT NOT NULL, active BOOLEAN NOT NULL DEFAULT true);
CREATE TABLE IF NOT EXISTS positions (global_position_id TEXT PRIMARY KEY, pool_address TEXT NOT NULL REFERENCES launch_pools(pool_address), wallet_address TEXT NOT NULL, partner_amount NUMERIC NOT NULL, usdt_amount NUMERIC NOT NULL, total_value NUMERIC NOT NULL, effective_compute NUMERIC NOT NULL, status TEXT NOT NULL, created_block BIGINT NOT NULL, created_at TIMESTAMPTZ NOT NULL);
CREATE TABLE IF NOT EXISTS epochs (epoch_id BIGINT PRIMARY KEY, reserve_before NUMERIC NOT NULL, burn_amount NUMERIC NOT NULL, emission_amount NUMERIC NOT NULL, output_rate_bps INTEGER NOT NULL, settled_block BIGINT NOT NULL, settled_at TIMESTAMPTZ NOT NULL);
CREATE TABLE IF NOT EXISTS treasury_flows (id BIGSERIAL PRIMARY KEY, tx_hash TEXT NOT NULL, treasury_kind TEXT NOT NULL, token_address TEXT NOT NULL, amount NUMERIC NOT NULL, direction TEXT NOT NULL, block_number BIGINT NOT NULL, event_ref TEXT NOT NULL UNIQUE);
CREATE TABLE IF NOT EXISTS liquidity_events (id BIGSERIAL PRIMARY KEY, tx_hash TEXT NOT NULL UNIQUE, asset_id BIGINT, pair_address TEXT NOT NULL, alp_amount NUMERIC NOT NULL, usdt_amount NUMERIC NOT NULL, lp_amount NUMERIC NOT NULL, block_number BIGINT NOT NULL);
CREATE TABLE IF NOT EXISTS buybacks (id BIGSERIAL PRIMARY KEY, trade_id TEXT NOT NULL UNIQUE, token_in TEXT NOT NULL, token_out TEXT NOT NULL, amount_in NUMERIC NOT NULL, amount_out NUMERIC, status TEXT NOT NULL, block_number BIGINT);
CREATE TABLE IF NOT EXISTS reconciliation_runs (id BIGSERIAL PRIMARY KEY, day DATE NOT NULL UNIQUE, status TEXT NOT NULL, findings JSONB NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS admin_audit_logs (id BIGSERIAL PRIMARY KEY, actor_address TEXT NOT NULL, role TEXT NOT NULL, action TEXT NOT NULL, proposal_payload JSONB NOT NULL, tx_hash TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS admin_roles (wallet_address TEXT PRIMARY KEY, role TEXT NOT NULL CHECK (role IN ('SUPER_ADMIN','FINANCE','RISK','OPERATIONS','AUDITOR','READ_ONLY')), granted_by TEXT NOT NULL, granted_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE TABLE IF NOT EXISTS siwe_nonces (nonce TEXT PRIMARY KEY, expires_at TIMESTAMPTZ NOT NULL, consumed_at TIMESTAMPTZ);
CREATE TABLE IF NOT EXISTS safe_proposals (id UUID PRIMARY KEY, proposer_address TEXT NOT NULL, required_role TEXT NOT NULL, operation TEXT NOT NULL, payload JSONB NOT NULL, status TEXT NOT NULL DEFAULT 'DRAFT', safe_tx_hash TEXT, created_at TIMESTAMPTZ NOT NULL DEFAULT now());
CREATE INDEX IF NOT EXISTS positions_wallet_idx ON positions(wallet_address);
CREATE INDEX IF NOT EXISTS events_block_idx ON indexed_events(chain_id, block_number);
CREATE INDEX IF NOT EXISTS audit_logs_actor_idx ON admin_audit_logs(actor_address, created_at DESC);
