DO $$
BEGIN
  CREATE ROLE odin WITH LOGIN PASSWORD 'secret';
  EXCEPTION WHEN DUPLICATE_OBJECT THEN
  RAISE NOTICE 'Not creating role ''odin'' -- it already exists';
END
$$;

CREATE DATABASE nidavellir OWNER odin;
