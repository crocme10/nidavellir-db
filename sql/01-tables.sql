CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE EXTENSION IF NOT EXISTS pgcrypto;

SET CLIENT_MIN_MESSAGES TO INFO;
SET CLIENT_ENCODING = 'UTF8';

-- For aggregating tags
-- See https://stackoverflow.com/questions/31210790/indexing-an-array-for-full-text-search
--
CREATE OR REPLACE FUNCTION array2string(TEXT[])
  RETURNS TEXT LANGUAGE SQL IMMUTABLE AS $$SELECT array_to_string($1, ',')$$;

CREATE OR REPLACE FUNCTION random_signature()
  RETURNS TEXT LANGUAGE SQL IMMUTABLE AS $$SELECT MD5(RANDOM()::TEXT)$$;

CREATE OR REPLACE FUNCTION index_signature(VARCHAR(64), VARCHAR(64), TEXT[])
  RETURNS VARCHAR(128) LANGUAGE SQL IMMUTABLE AS $$SELECT MD5($1 || '-' || $2 || '-' || array2string($3))$$;

CREATE TABLE index_types (
  id VARCHAR(64) PRIMARY KEY
);

ALTER TABLE index_types OWNER TO odin;

CREATE TABLE data_sources (
  id VARCHAR(64) PRIMARY KEY
);

ALTER TABLE data_sources OWNER TO odin;

CREATE TABLE index_type_data_source (
  index_type VARCHAR(64) REFERENCES index_types(id) ON DELETE CASCADE,
  data_source VARCHAR(64) REFERENCES data_sources(id) ON DELETE CASCADE
);

ALTER TABLE index_type_data_source OWNER TO odin;

CREATE TYPE index_status AS ENUM ('not_available', 'downloading_in_progress', 'downloading_error', 'downloaded', 'processing_in_progress', 'processing_error',
  'processed', 'indexing_in_progress', 'indexing_error', 'indexed', 'validation_in_progress', 'validation_error', 'available');

CREATE TABLE environments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name VARCHAR(256) UNIQUE,
  signature VARCHAR(512) CONSTRAINT unique_environment_signature UNIQUE DEFAULT random_signature(),
  port INTEGER,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE environments OWNER TO odin;

CREATE TABLE indexes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  index_type VARCHAR(64) REFERENCES index_types(id) ON DELETE CASCADE,
  data_source VARCHAR(64) REFERENCES data_sources(id) ON DELETE CASCADE,
  regions TEXT[],
  signature VARCHAR(128)
    GENERATED ALWAYS AS (index_signature(index_type, data_source, regions)) STORED
    CONSTRAINT unique_index_signature UNIQUE,
  status index_status NOT NULL DEFAULT 'not_available',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  -- FIXME This constraints is used to make sure that the data source is compatible with the index type.
  -- FOREIGN KEY (index_type, data_source) REFERENCES index_type_data_source (index_type, data_source)
  -- TODO The following is redundant with the unique_index_signature, so maybe remove it.
  -- Test with and without...
  UNIQUE (index_type, data_source, regions)
);

ALTER TABLE indexes OWNER TO odin;

CREATE TABLE environment_index_map (
  environment_id UUID REFERENCES environments(id) ON DELETE CASCADE,
  index_id UUID REFERENCES indexes(id) ON DELETE CASCADE,
  PRIMARY KEY (environment_id, index_id)
);

ALTER TABLE environment_index_map OWNER TO odin;
