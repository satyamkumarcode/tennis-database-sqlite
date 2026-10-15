-- build the whole tennis database from the repo root
-- usage:  sqlite3 tennis_assignment.db ".read build.sql"
.bail on
.read sql/01_schema.sql
.read sql/02_data.sql
.read sql/03_queries.sql
