CREATE OR REPLACE FUNCTION audit.log_function_call(
    p_function_name TEXT,
    p_caller_role   NAME,
    p_input_params  JSONB,
    p_success       BOOLEAN,
    p_error_message TEXT DEFAULT NULL
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, audit
AS $$
DECLARE
    v_conn TEXT;
    v_sql  TEXT;
BEGIN
    v_conn := format('dbname=%s user=postgres connect_timeout=5', current_database());
    v_sql := format(
        'INSERT INTO audit.function_calls '
        '(function_name, caller_role, input_params, success, error_message) '
        'VALUES (%L, %L, %L::jsonb, %L::boolean, %L)',
        p_function_name,
        p_caller_role,
        p_input_params::text,
        p_success,
        p_error_message
    );
    PERFORM audit.dblink_exec(v_conn, v_sql);
END;
$$;

CREATE OR REPLACE FUNCTION app.create_ticket(
    p_trip_id      INTEGER,
    p_passenger_id INTEGER,
    p_seat_number  INTEGER,
    p_price        NUMERIC DEFAULT NULL
)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app, ref, audit
AS $$
DECLARE
    v_trip       app.trips;
    v_capacity   INTEGER;
    v_base_price NUMERIC(10,2);
    v_price      NUMERIC(10,2);
    v_ticket_id  INTEGER;
    v_params     JSONB;
BEGIN
    v_params := jsonb_build_object(
        'trip_id',      p_trip_id,
        'passenger_id', p_passenger_id,
        'seat_number',  p_seat_number,
        'price',        p_price
    );

    IF p_trip_id IS NULL THEN
        RAISE EXCEPTION 'Не указан идентификатор рейса';
    END IF;
    IF p_passenger_id IS NULL THEN
        RAISE EXCEPTION 'Не указан идентификатор пассажира';
    END IF;
    IF p_seat_number IS NULL THEN
        RAISE EXCEPTION 'Не указан номер места';
    END IF;

    SELECT * INTO v_trip
    FROM app.trips
    WHERE id = p_trip_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Рейс с id=% не найден', p_trip_id;
    END IF;

    IF v_trip.status NOT IN ('scheduled', 'boarding') THEN
        RAISE EXCEPTION 'Нельзя продать билет на рейс %: статус рейса "%", ожидается scheduled или boarding',
            p_trip_id, v_trip.status;
    END IF;

    -- Изоляция по филиалам: функция проверяет филиал сама, потому что её владелец
    -- app_owner имеет BYPASSRLS и RLS внутри SECURITY DEFINER-функции не
    -- действует. Если филиал субъекта не определён (нет GUC app.branch_id
    -- и нет записи роли в app.role_branches) — операция запрещается.
    IF v_trip.branch_id IS DISTINCT FROM app.current_branch_id() THEN
        RAISE EXCEPTION 'Межфилиальная операция запрещена: рейс % принадлежит филиалу %, филиал субъекта %',
            p_trip_id, v_trip.branch_id,
            COALESCE(app.current_branch_id()::TEXT, '<не определён>');
    END IF;

    SELECT capacity INTO v_capacity
    FROM app.vehicles
    WHERE id = v_trip.vehicle_id;

    IF p_seat_number < 1 OR p_seat_number > v_capacity THEN
        RAISE EXCEPTION 'Недопустимый номер места %: на рейсе % номера мест 1..%',
            p_seat_number, p_trip_id, v_capacity;
    END IF;

    IF NOT EXISTS (SELECT 1 FROM app.passengers WHERE id = p_passenger_id) THEN
        RAISE EXCEPTION 'Пассажир с id=% не найден', p_passenger_id;
    END IF;

    IF EXISTS (
        SELECT 1 FROM app.tickets
        WHERE trip_id = p_trip_id AND seat_number = p_seat_number
    ) THEN
        RAISE EXCEPTION 'Место % на рейсе % уже занято', p_seat_number, p_trip_id;
    END IF;

    SELECT base_price INTO v_base_price
    FROM ref.routes
    WHERE id = v_trip.route_id;

    v_price := COALESCE(p_price, v_base_price);

    IF v_price < 0 OR v_price > v_base_price THEN
        RAISE EXCEPTION 'Цена билета должна быть в диапазоне 0..%', v_base_price;
    END IF;

    INSERT INTO app.tickets (branch_id, trip_id, passenger_id, seat_number, price, status, issued_at)
    VALUES (v_trip.branch_id, p_trip_id, p_passenger_id, p_seat_number, v_price, 'issued', now())
    RETURNING id INTO v_ticket_id;

    PERFORM audit.log_function_call(
        'app.create_ticket', session_user, v_params, TRUE, NULL
    );

    RETURN v_ticket_id;
EXCEPTION WHEN OTHERS THEN
    PERFORM audit.log_function_call(
        'app.create_ticket', session_user, v_params, FALSE, SQLERRM
    );
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION app.cancel_ticket(p_ticket_id INTEGER)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app, audit
AS $$
DECLARE
    v_ticket      app.tickets;
    v_trip_status TEXT;
    v_result      JSONB;
    v_params      JSONB;
BEGIN
    v_params := jsonb_build_object('ticket_id', p_ticket_id);

    IF p_ticket_id IS NULL THEN
        RAISE EXCEPTION 'Не указан идентификатор билета';
    END IF;

    SELECT * INTO v_ticket
    FROM app.tickets
    WHERE id = p_ticket_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Билет с id=% не найден', p_ticket_id;
    END IF;

    -- изоляция по филиалам: RLS внутри SECURITY DEFINER не действует (у владельца
    -- app_owner BYPASSRLS), поэтому филиал проверяется явно, fail-closed
    IF v_ticket.branch_id IS DISTINCT FROM app.current_branch_id() THEN
        RAISE EXCEPTION 'Межфилиальная операция запрещена: билет % принадлежит филиалу %, филиал субъекта %',
            p_ticket_id, v_ticket.branch_id,
            COALESCE(app.current_branch_id()::TEXT, '<не определён>');
    END IF;

    IF v_ticket.status = 'cancelled' THEN
        RAISE EXCEPTION 'Билет % уже отменён', p_ticket_id;
    END IF;

    IF v_ticket.status = 'used' THEN
        RAISE EXCEPTION 'Нельзя отменить использованный билет %', p_ticket_id;
    END IF;

    SELECT status INTO v_trip_status
    FROM app.trips
    WHERE id = v_ticket.trip_id;

    IF v_trip_status IN ('completed', 'cancelled') THEN
        RAISE EXCEPTION 'Нельзя отменить билет %: рейс % находится в статусе "%"',
            p_ticket_id, v_ticket.trip_id, v_trip_status;
    END IF;

    UPDATE app.tickets
    SET status = 'cancelled'
    WHERE id = p_ticket_id;

EXCEPTION WHEN OTHERS THEN
    PERFORM audit.log_function_call(
        'app.cancel_ticket', session_user, v_params, FALSE, SQLERRM
    );
    RAISE;
END;
$$;

CREATE OR REPLACE FUNCTION app.update_trip_status(
    p_trip_id    INTEGER,
    p_new_status TEXT
)
RETURNS VOID
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = pg_catalog, app, audit
AS $$
DECLARE
    v_trip   app.trips;
    v_params JSONB;
BEGIN
    v_params := jsonb_build_object(
        'trip_id',    p_trip_id,
        'new_status', p_new_status
    );

    IF p_trip_id IS NULL THEN
        RAISE EXCEPTION 'Не указан идентификатор рейса';
    END IF;
    IF p_new_status IS NULL OR btrim(p_new_status) = '' THEN
        RAISE EXCEPTION 'Не указан новый статус рейса';
    END IF;

    p_new_status := btrim(p_new_status);

    IF p_new_status NOT IN ('scheduled', 'boarding', 'in_progress', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Недопустимый статус рейса "%". Допустимые статусы: scheduled, boarding, in_progress, completed, cancelled',
            p_new_status;
    END IF;

    SELECT * INTO v_trip
    FROM app.trips
    WHERE id = p_trip_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Рейс с id=% не найден', p_trip_id;
    END IF;

    -- изоляция по филиалам: RLS внутри SECURITY DEFINER не действует (у владельца
    -- app_owner BYPASSRLS), поэтому филиал проверяется явно, fail-closed
    IF v_trip.branch_id IS DISTINCT FROM app.current_branch_id() THEN
        RAISE EXCEPTION 'Межфилиальная операция запрещена: рейс % принадлежит филиалу %, филиал субъекта %',
            p_trip_id, v_trip.branch_id,
            COALESCE(app.current_branch_id()::TEXT, '<не определён>');
    END IF;

    IF v_trip.status = p_new_status THEN
        RAISE EXCEPTION 'Рейс % уже находится в статусе "%"', p_trip_id, p_new_status;
    END IF;

    IF NOT (
        (v_trip.status = 'scheduled'   AND p_new_status IN ('boarding', 'cancelled')) OR
        (v_trip.status = 'boarding'    AND p_new_status IN ('in_progress', 'cancelled')) OR
        (v_trip.status = 'in_progress' AND p_new_status = 'completed')
    ) THEN
        RAISE EXCEPTION 'Недопустимый переход статуса рейса %: "%" -> "%"',
            p_trip_id, v_trip.status, p_new_status;
    END IF;

    UPDATE app.trips
    SET status = p_new_status
    WHERE id = p_trip_id;

    PERFORM audit.log_function_call(
        'app.update_trip_status', session_user, v_params, TRUE, NULL
    );

EXCEPTION WHEN OTHERS THEN
    PERFORM audit.log_function_call(
        'app.update_trip_status', session_user, v_params, FALSE, SQLERRM
    );
    RAISE;
END;
$$;
