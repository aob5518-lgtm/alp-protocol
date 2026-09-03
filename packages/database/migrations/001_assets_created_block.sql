-- Required for reorg-safe AssetRegistered projections on databases created before P0 indexer work.
ALTER TABLE assets ADD COLUMN IF NOT EXISTS created_block BIGINT;
UPDATE assets SET created_block = 0 WHERE created_block IS NULL;
ALTER TABLE assets ALTER COLUMN created_block SET NOT NULL;
