# ALP database projections

`schema.sql` stores replayable event projections only. It is never the authority for balances, permissions, or financial settlement: each projection retains its chain/block identity so the indexer can roll it back after a reorg and reconcile it against contracts.
