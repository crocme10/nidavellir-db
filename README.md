# PostgreSQL database setup for Nidavellir.

contains first.sql which creates the database and its admin
second.sql contains the database schema
third.sql is the API
fourth.sql is some data to populate the database

```
docker run --name postgres -e POSTGRES_PASSWORD=secret -p 5433:5432/tcp -d postgres
psql postgres://postgres:secret@localhost:5433 < first.sql
psql postgres://postgres:secret@localhost:5433/nidavellir < second.sql
psql postgres://postgres:secret@localhost:5433/nidavellir < third.sql
psql postgres://postgres:secret@localhost:5433/nidavellir < third.sql
```
