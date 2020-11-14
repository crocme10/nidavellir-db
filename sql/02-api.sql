---------
-- API --
---------

-- This type is used to return a environment to the client
CREATE TYPE return_environment_type AS (
    id          UUID
  , name        TEXT
  , signature   TEXT
  , created_at  TIMESTAMPTZ
  , updated_at  TIMESTAMPTZ
);

-- This type is used to return an index to the client
CREATE TYPE return_index_type AS (
    id          UUID
  , signature   TEXT
  , index_type  TEXT
  , data_source TEXT
  , regions     TEXT[]
  , status      index_status
  , created_at  TIMESTAMPTZ
  , updated_at  TIMESTAMPTZ
);

CREATE OR REPLACE FUNCTION list_environments ( )
RETURNS SETOF return_environment_type
AS $$
BEGIN
  RETURN QUERY
  SELECT id, name, signature, created_at, updated_at
  FROM environments;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION list_environment_indexes (
  _id     UUID    -- (1)
)
RETURNS SETOF return_index_type
AS $$
BEGIN
  RETURN QUERY
  SELECT i.id, i.signature, i.index_type, i.data_source, i.regions, i.status, i.created_at, i.updated_at
  FROM indexes AS i
  INNER JOIN environment_index_map AS m ON i.id = m.index_id
  WHERE m.environment_id = $1;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_environment (
    _name        TEXT                 -- name        (1)
) RETURNS return_environment_type
AS $$
DECLARE
  res return_environment_type;
BEGIN
  INSERT INTO environments (name) VALUES (
      $1  -- name
  )
  -- We're faking an update, so that the returning clause is called, even if there is no real update.
  ON CONFLICT ("name") DO UPDATE SET name = EXCLUDED.name
  RETURNING id, name, signature, created_at, updated_at INTO res;
  RETURN res;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION create_index (
    _environment_id   UUID    -- (1)
  , _index_type       TEXT    -- (2)
  , _data_source      TEXT    -- (3)
  , _regions          TEXT[]  -- (4)
) RETURNS return_index_type
AS $$
DECLARE
  res return_index_type;
BEGIN
  INSERT INTO indexes (index_type, data_source, regions) VALUES (
      $2  -- index type
    , $3  -- data source
    , $4  -- regions
  )
  -- We're faking an update, so that the returning clause is called, even if there is no real update.
  ON CONFLICT ON CONSTRAINT unique_index_signature DO UPDATE SET index_type = EXCLUDED.index_type
  RETURNING id, signature, index_type, data_source, regions, status, created_at, updated_at INTO res;
  INSERT INTO environment_index_map (environment_id, index_id) VALUES ($1, res.id);
  PERFORM update_environment_signature($1);
  RETURN res;
END;
$$
LANGUAGE plpgsql;

-- FIXME Cascade  to env-idx-map
CREATE OR REPLACE FUNCTION delete_environment (
    _environment_id     UUID    -- id (1)
) RETURNS return_environment_type
AS $$
DECLARE
  res return_environment_type;
BEGIN
  DELETE FROM environments WHERE id = $1
  RETURNING id, signature, created_at, updated_at INTO res;
  RETURN res;
END;
$$
LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION update_environment_signature (
    _environment_id    UUID     -- id (1)
) RETURNS return_environment_type
AS $$
DECLARE
  res return_environment_type;
  v_state   TEXT;
  v_msg     TEXT;
  v_detail  TEXT;
  v_hint    TEXT;
  v_context TEXT;
BEGIN
  UPDATE environments
  SET signature = (
    SELECT string_agg(i.signature, ','  ORDER BY i.signature)
    FROM environment_index_map AS ei
    INNER JOIN indexes AS i ON ei.index_id = i.id
    WHERE ei.environment_id = $1
    GROUP BY ei.environment_id
  )
  WHERE id = $1
  RETURNING id, signature, created_at, updated_at INTO res;
  RETURN res;
  EXCEPTION
  WHEN others
  THEN
    GET STACKED DIAGNOSTICS
        v_state   = RETURNED_SQLSTATE,
        v_msg     = MESSAGE_TEXT,
        v_detail  = PG_EXCEPTION_DETAIL,
        v_hint    = PG_EXCEPTION_HINT,
        v_context = PG_EXCEPTION_CONTEXT;
    RAISE NOTICE E'Got exception:
        state  : %
        message: %
        detail : %
        hint   : %
        context: %', v_state, v_msg, v_detail, v_hint, v_context;
    RETURN NULL;
END;
$$
LANGUAGE plpgsql;
