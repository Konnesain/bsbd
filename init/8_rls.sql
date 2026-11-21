CREATE OR REPLACE FUNCTION app.branch_of_role(p_role NAME)
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SECURITY DEFINER
SET search_path = pg_catalog, app
AS $$
DECLARE
    v_branch_id INTEGER;
BEGIN
    IF p_role IS NULL OR btrim(p_role::TEXT) = '' THEN
        RETURN NULL;
    END IF;

    SELECT rb.branch_id
      INTO v_branch_id
      FROM app.role_branches rb
     WHERE rb.role_name = p_role;
    RETURN v_branch_id;
END;
$$;

CREATE OR REPLACE FUNCTION app.current_branch_id()
RETURNS INTEGER
LANGUAGE plpgsql
STABLE
SET search_path = pg_catalog, app
AS $$
DECLARE
    v_guc TEXT := current_setting('app.branch_id', true);
    v_role TEXT := current_setting('role', true);
    v_branch INTEGER;
BEGIN
    IF v_guc IS NOT NULL AND btrim(v_guc) <> '' THEN
        BEGIN
            RETURN v_guc::INTEGER;
        EXCEPTION WHEN invalid_text_representation THEN
            RETURN NULL;
        END;
    END IF;

    IF v_role IS NOT NULL AND v_role <> 'none' THEN
        v_branch := app.branch_of_role(v_role::NAME);
        IF v_branch IS NOT NULL THEN
            RETURN v_branch;
        END IF;
    END IF;

    v_branch := app.branch_of_role(current_user);
    RETURN v_branch;
END;
$$;

CREATE OR REPLACE FUNCTION app.set_session_ctx(p_branch_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SET search_path = pg_catalog, app, ref
AS $$
DECLARE
    v_caller   NAME;
    v_role_guc TEXT := current_setting('role', true);
BEGIN
    IF p_branch_id IS NULL THEN
        RAISE EXCEPTION 'Не указан идентификатор филиала';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM ref.branches WHERE id = p_branch_id) THEN
        RAISE EXCEPTION 'Филиал id=% не существует', p_branch_id;
    END IF;

    IF COALESCE(app.branch_of_role(current_user), -1) = p_branch_id
       OR current_user = 'auditor'
       OR EXISTS (SELECT 1 FROM pg_catalog.pg_roles
                   WHERE rolname = current_user AND (rolsuper OR rolbypassrls))
    THEN
        PERFORM set_config('app.branch_id', p_branch_id::TEXT, true);
    ELSE
        RAISE EXCEPTION 'Роли "%" не разрешён доступ к филиалу id=%', current_user, p_branch_id;
    END IF;
END;
$$;

-- отменяем действие 1_default_priv.sql для этих функций
GRANT EXECUTE ON FUNCTION app.branch_of_role(NAME) TO PUBLIC;
GRANT EXECUTE ON FUNCTION app.current_branch_id() TO PUBLIC;
GRANT EXECUTE ON FUNCTION app.set_session_ctx(INTEGER) TO PUBLIC;

ALTER TABLE app.passengers ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.passengers FORCE ROW LEVEL SECURITY;
ALTER TABLE app.vehicles   ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.vehicles   FORCE ROW LEVEL SECURITY;
ALTER TABLE app.trips      ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.trips      FORCE ROW LEVEL SECURITY;
ALTER TABLE app.tickets    ENABLE ROW LEVEL SECURITY;
ALTER TABLE app.tickets    FORCE ROW LEVEL SECURITY;

CREATE POLICY p_passengers ON app.passengers
    FOR ALL
    USING     (current_user = 'auditor' OR branch_id = app.current_branch_id())
    WITH CHECK (current_user = 'auditor' OR branch_id = app.current_branch_id());

CREATE POLICY p_vehicles ON app.vehicles
    FOR ALL
    USING     (current_user = 'auditor' OR branch_id = app.current_branch_id())
    WITH CHECK (current_user = 'auditor' OR branch_id = app.current_branch_id());

CREATE POLICY p_trips ON app.trips
    FOR ALL
    USING     (current_user = 'auditor' OR branch_id = app.current_branch_id())
    WITH CHECK (current_user = 'auditor' OR branch_id = app.current_branch_id());

CREATE POLICY p_tickets ON app.tickets
    FOR ALL
    USING     (current_user = 'auditor' OR branch_id = app.current_branch_id())
    WITH CHECK (current_user = 'auditor' OR branch_id = app.current_branch_id());

REVOKE ALL ON app.role_branches
    FROM PUBLIC, app_reader_s1, app_reader_s2, app_writer_s1, app_writer_s2;
