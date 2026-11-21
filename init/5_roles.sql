-- create roles and users
-- Филиальные роли: отдельная пара «читатель/писатель» на каждый из 2 филиалов
CREATE ROLE app_reader_s1 NOLOGIN;
CREATE ROLE app_reader_s2 NOLOGIN;
CREATE ROLE app_writer_s1 NOLOGIN;
CREATE ROLE app_writer_s2 NOLOGIN;
CREATE ROLE app_owner NOLOGIN BYPASSRLS;
CREATE ROLE auditor NOLOGIN;

CREATE ROLE ddl_admin NOLOGIN;
CREATE ROLE dml_admin NOLOGIN BYPASSRLS;
CREATE ROLE security_admin NOLOGIN;

CREATE ROLE reader_user LOGIN PASSWORD 'pass' NOINHERIT;
CREATE ROLE writer_user LOGIN PASSWORD 'pass' NOINHERIT;
CREATE ROLE auditor_user LOGIN PASSWORD 'pass' NOINHERIT;
CREATE ROLE owner_user LOGIN PASSWORD 'pass' NOINHERIT;
CREATE ROLE ddl_user LOGIN PASSWORD 'pass' NOINHERIT;
CREATE ROLE dml_user LOGIN PASSWORD 'pass' NOINHERIT;
CREATE ROLE sec_user LOGIN PASSWORD 'pass' NOINHERIT;

GRANT app_reader_s1, app_reader_s2 TO reader_user;
GRANT app_writer_s1, app_writer_s2 TO writer_user;
GRANT app_owner TO owner_user;
GRANT auditor TO auditor_user;
GRANT ddl_admin TO ddl_user;
GRANT dml_admin TO dml_user;
GRANT security_admin TO sec_user;

-- permissions on tables and schemas
GRANT ALL ON SCHEMA app TO app_owner;
GRANT ALL ON ALL TABLES IN SCHEMA app to app_owner;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app TO app_owner;
GRANT ALL ON SCHEMA ref TO app_owner;
GRANT ALL ON ALL TABLES IN SCHEMA ref to app_owner;
GRANT ALL ON ALL SEQUENCES IN SCHEMA ref TO app_owner;
GRANT ALL ON SCHEMA stg TO app_owner;
GRANT ALL ON ALL TABLES IN SCHEMA stg to app_owner;
GRANT ALL ON ALL SEQUENCES IN SCHEMA stg TO app_owner;

GRANT USAGE ON SCHEMA app TO app_reader_s1, app_reader_s2;
GRANT USAGE ON SCHEMA ref TO app_reader_s1, app_reader_s2;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO app_reader_s1, app_reader_s2;
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO app_reader_s1, app_reader_s2;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA app TO app_reader_s1, app_reader_s2;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ref TO app_reader_s1, app_reader_s2;

GRANT USAGE ON SCHEMA app TO app_writer_s1, app_writer_s2;
GRANT USAGE ON SCHEMA ref TO app_writer_s1, app_writer_s2;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA app TO app_writer_s1, app_writer_s2;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA ref TO app_writer_s1, app_writer_s2;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA app TO app_writer_s1, app_writer_s2;
GRANT USAGE ON ALL SEQUENCES IN SCHEMA ref TO app_writer_s1, app_writer_s2;

GRANT USAGE ON SCHEMA audit TO auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA audit TO auditor;

-- auditor
GRANT USAGE ON SCHEMA app TO auditor;
GRANT USAGE ON SCHEMA ref TO auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA app TO auditor;
GRANT SELECT ON ALL TABLES IN SCHEMA ref TO auditor;

GRANT CREATE ON SCHEMA app TO ddl_admin;
GRANT CREATE ON SCHEMA ref TO ddl_admin;
GRANT CREATE ON SCHEMA stg TO ddl_admin;

GRANT USAGE ON SCHEMA app TO dml_admin;
GRANT USAGE ON SCHEMA ref TO dml_admin;
GRANT USAGE ON SCHEMA stg TO dml_admin;
GRANT ALL ON ALL TABLES IN SCHEMA app TO dml_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA app TO dml_admin;
GRANT ALL ON ALL TABLES IN SCHEMA ref TO dml_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA ref TO dml_admin;
GRANT ALL ON ALL TABLES IN SCHEMA stg TO dml_admin;
GRANT ALL ON ALL SEQUENCES IN SCHEMA stg TO dml_admin;

ALTER SCHEMA app OWNER TO app_owner;
ALTER SCHEMA ref OWNER TO app_owner;
ALTER SCHEMA stg OWNER TO app_owner;

-- permissions on functions
REVOKE ALL ON FUNCTION audit.log_function_call(TEXT, NAME, JSONB, BOOLEAN, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION audit.log_function_call(TEXT, NAME, JSONB, BOOLEAN, TEXT) TO app_owner;
GRANT USAGE ON SCHEMA audit TO app_owner;
GRANT SELECT ON audit.function_calls TO auditor;

ALTER FUNCTION app.create_ticket(INTEGER, INTEGER, INTEGER, NUMERIC) OWNER TO app_owner;
REVOKE ALL ON FUNCTION app.create_ticket(INTEGER, INTEGER, INTEGER, NUMERIC) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.create_ticket(INTEGER, INTEGER, INTEGER, NUMERIC) TO app_writer_s1, app_writer_s2;

ALTER FUNCTION app.cancel_ticket(INTEGER) OWNER TO app_owner;
REVOKE ALL ON FUNCTION app.cancel_ticket(INTEGER) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.cancel_ticket(INTEGER) TO app_writer_s1, app_writer_s2;

ALTER FUNCTION app.update_trip_status(INTEGER, TEXT) OWNER TO app_owner;
REVOKE ALL ON FUNCTION app.update_trip_status(INTEGER, TEXT) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION app.update_trip_status(INTEGER, TEXT) TO app_writer_s1, app_writer_s2;

REVOKE INSERT, UPDATE ON app.tickets FROM app_writer_s1, app_writer_s2;

REVOKE UPDATE ON app.trips FROM app_writer_s1, app_writer_s2;
GRANT UPDATE (route_id, vehicle_id, departure_time, arrival_time) ON app.trips TO app_writer_s1, app_writer_s2;
