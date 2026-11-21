-- psql -h 127.0.0.1 -p 6000 -d transport -U postgres -f tests/test_privileges.sql

\set ON_ERROR_STOP on
\pset pager off

TRUNCATE audit.function_calls RESTART IDENTITY;

BEGIN;

-- app_reader_s1
SET SESSION AUTHORIZATION reader_user;
SET ROLE app_reader_s1;

-- 1 - чтение app и ref
DO $$
BEGIN
    BEGIN
        PERFORM 1 FROM app.tickets LIMIT 1;
        PERFORM 1 FROM ref.routes LIMIT 1;
        RAISE NOTICE '1 - PASS: app_reader_s1 чтение из app.tickets и ref.routes успешно';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE EXCEPTION '1 - FAIL: app_reader_s1 не может прочитать: %', SQLERRM;
    END;
END $$;

-- 2 - чтение stg
DO $$
BEGIN
    BEGIN
        PERFORM 1 FROM stg.passengers_import LIMIT 1;
        RAISE EXCEPTION '2 - FAIL: app_reader_s1 прочитал stg.passengers_import';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '2 - PASS: app_reader_s1 не имеет доступа к stg.passengers_import';
    END;
END $$;

-- 3 - чтение stg
DO $$
BEGIN
    BEGIN
        PERFORM 1 FROM audit.function_calls LIMIT 1;
        RAISE EXCEPTION '3 - FAIL: app_reader_s1 прочитал audit.function_calls';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '3 - PASS: app_reader_s1 не имеет доступа к audit.function_calls';
    END;
END $$;

-- 4 - запись app_reader_s1
DO $$
BEGIN
    BEGIN
        INSERT INTO app.tickets (trip_id, passenger_id, seat_number, price)
        VALUES (1, 1, 1, 100);
        RAISE EXCEPTION '4 - FAIL: app_reader_s1 смог вставить в app.tickets';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '4 - PASS: app_reader_s1 не смог вставить в app.tickets';
    END;
END $$;

-- 5 - функции app_reader_s1
DO $$
BEGIN
    BEGIN
        PERFORM app.create_ticket(1, 1, 1, NULL);
        RAISE EXCEPTION '5 - FAIL: app_reader_s1 смог вызвать app.create_ticket';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '5 - PASS: app_reader_s1 не смог вызвать app.create_ticket';
    END;
END $$;

RESET ROLE;
RESET SESSION AUTHORIZATION;

-- app_writer_s1
SET SESSION AUTHORIZATION writer_user;
SET ROLE app_writer_s1;

-- 6 - ddl app_writer_s1
DO $$
BEGIN
    BEGIN
        EXECUTE 'CREATE TABLE app.testtable (id INTEGER)';
        RAISE EXCEPTION '6 - FAIL: app_writer_s1 смог выполнить DDL в схеме app';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '6 - PASS: app_writer_s1 не может выполнять DDL (CREATE TABLE) в app';
    END;
END $$;

-- 7 - запись в audit
DO $$
BEGIN
    BEGIN
        INSERT INTO audit.function_calls (function_name, caller_role, success)
        VALUES ('func', 'writer_user', TRUE);
        RAISE EXCEPTION '7 - FAIL: app_writer_s1 смог вставить в audit.function_calls';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '7 - PASS: app_writer_s1 не смог вставить в audit.function_calls';
    END;
END $$;

-- 8 - запись в билеты
DO $$
BEGIN
    BEGIN
        INSERT INTO app.tickets (trip_id, passenger_id, seat_number, price)
        VALUES (1, 1, 1, 100);
        RAISE EXCEPTION '8 - FAIL: app_writer_s1 смог напрямую вставить билет';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE NOTICE '8 - PASS: app_writer_s1 не смог вставить билет';
    END;
END $$;

-- 9 - правильный вызов функции
DO $$
BEGIN
    BEGIN
        PERFORM app.create_ticket(1, 1, 1, NULL);
        RAISE NOTICE '9 - PASS: app_writer_s1 создал билет через функцию';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '9 - FAIL: не удалось создать билет через функцию: %', SQLERRM;
    END;
END $$;

-- 10 - создание и отмена билета
DO $$
DECLARE
    v_ticket   INTEGER;
BEGIN
    BEGIN
        v_ticket := app.create_ticket(1, 1, 2, NULL);
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '10 - FAIL: не удалось создать билет через функцию: %', SQLERRM;
    END;
    BEGIN
        PERFORM app.cancel_ticket(v_ticket);
        RAISE NOTICE '10 - PASS: app_writer_s1 отменил билет через функцию';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '10 - FAIL: не удалось отменить билет через функцию: %', SQLERRM;
    END;
END $$;

-- 11 - создание билета с несуществующим рейсом
DO $$
BEGIN
    BEGIN
        PERFORM app.create_ticket(999999, 1, 1, NULL);
        RAISE EXCEPTION '11 - FAIL: create_ticket принял несуществующий рейс';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '11 - PASS: создание билета с несуществующим рейсом отклонено';
    END;
END $$;

-- 12 - смена статуса рейса scheduled -> boarding.
DO $$
BEGIN
    BEGIN
        PERFORM app.update_trip_status(1, 'boarding');
        RAISE NOTICE '12 - PASS: удалось изменить статус рейса через функцию';
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '12 - FAIL: не удалось изменить статус рейса: %', SQLERRM;
    END;
END $$;

RESET ROLE;
RESET SESSION AUTHORIZATION;

-- auditor
SET SESSION AUTHORIZATION auditor_user;
SET ROLE auditor;

DO $$
BEGIN
    PERFORM 1 FROM audit.function_calls LIMIT 1;
    RAISE NOTICE '13 - PASS: auditor может читать audit.function_calls';
    EXCEPTION WHEN insufficient_privilege THEN
        RAISE EXCEPTION '13 - FAIL: auditor не может прочитать audit.function_calls: %', SQLERRM;
END $$;

RESET ROLE;
RESET SESSION AUTHORIZATION;

ROLLBACK;

\echo 'Все тесты пройдены'
