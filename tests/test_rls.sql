-- psql -h 127.0.0.1 -p 6000 -d transport -U postgres -f tests/test_rls.sql

\set ON_ERROR_STOP on
\pset pager off

-- 1 чтение своего филиала (пассажиры)
BEGIN;
SET SESSION AUTHORIZATION reader_user;
SET ROLE app_reader_s1;

DO $$
DECLARE
    v_passengers INTEGER;
BEGIN
    SELECT count(*) INTO v_passengers FROM app.passengers p where p.branch_id = 1;

    IF v_passengers = 0 THEN
        RAISE EXCEPTION '1 - FAIL: app_reader_s1 не увидел строки своего филиала';
    END IF;

    RAISE NOTICE '1 - PASS: app_reader_s1 увидел строки своего филиала';
END $$;

-- 2 чтение чужого филиала (пассажиры)
DO $$
DECLARE
    v_passengers INTEGER;
BEGIN
    SELECT count(*) INTO v_passengers FROM app.passengers p where p.branch_id = 2;

    IF v_passengers <> 0 THEN
        RAISE EXCEPTION '2 - FAIL: app_reader_s1 увидел строки чужого филиала';
    END IF;

    RAISE NOTICE '2 - PASS: app_reader_s1 не увидел строки чужого филиала';
END $$;

ROLLBACK;

-- 3 - вставка в свой филиал (пассажиры)
BEGIN;
SET SESSION AUTHORIZATION writer_user;
SET ROLE app_writer_s1;

DO $$
BEGIN
    INSERT INTO app.passengers (branch_id, surname, name, patronymic, passport_enc, email, phone)
    VALUES (1, 'Тестов', 'Тест', 'Тестович', decode('00', 'hex'),
            'testov@example.ru', '79000000001');
    RAISE NOTICE '3 - PASS: вставка строки для своего выполнена';
EXCEPTION WHEN OTHERS THEN
    RAISE EXCEPTION '3 - FAIL: вставка в свой филиал не удалась: %', SQLERRM;
END $$;

-- 4 - вставка  в чужой филиал
DO $$
BEGIN
    INSERT INTO app.passengers (branch_id, surname, name, patronymic, passport_enc, email, phone)
    VALUES (2, 'Тестов', 'Тест', 'Тестович', decode('00', 'hex'),
            'testov@example.ru', '79000000001');
    RAISE EXCEPTION '4 - FAIL: вставка с чужим branch_id была разрешена';
EXCEPTION WHEN insufficient_privilege THEN
    RAISE NOTICE '4 - PASS: вставка с чужим branch_id отклонена: %', SQLERRM;
END $$;

ROLLBACK;

-- 5 - auditor видит все филиалы
BEGIN;
SET SESSION AUTHORIZATION auditor_user;
SET ROLE auditor;

DO $$
DECLARE
    v_passengers_branches INTEGER;
BEGIN
    SELECT COUNT(DISTINCT p.branch_id) INTO v_passengers_branches FROM app.passengers p;

    IF v_passengers_branches <> 2 THEN
        RAISE EXCEPTION '5 - FAIL: auditor должен увидеть 2 филиала, увидел %', v_passengers_branches;
    END IF;
    RAISE NOTICE '5 - PASS: auditor видит оба филиала';
END $$;

ROLLBACK;

-- 6 - обновление в своем филиале
BEGIN;
SET SESSION AUTHORIZATION writer_user;
SET ROLE app_writer_s1;

DO $$
DECLARE
    v_rows INTEGER;
BEGIN
    UPDATE app.passengers
       SET phone = '79001112233'
     WHERE surname = 'Иванов' AND name = 'Иван' AND branch_id = 1;
    
    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 1 THEN
        RAISE EXCEPTION '6 - FAIL: обновлено % строк, ожидалось - 1', v_rows;
    END IF;
    RAISE NOTICE '6 - PASS: строка своего филиала обновлена';
END $$;

-- 7 - обновление в чужом филиале 
DO $$
DECLARE
    v_rows INTEGER;
BEGIN
    UPDATE app.passengers
       SET phone = '79001112233'
     WHERE branch_id = 2;

    GET DIAGNOSTICS v_rows = ROW_COUNT;
    IF v_rows <> 0 THEN
        RAISE EXCEPTION '7 - FAIL: удалось обновить % чужих строк', v_rows;
    END IF;
    RAISE NOTICE '7 - PASS: не удалось обновить чужие строки';
END $$;

ROLLBACK;

-- 8 - успешная установка guc
BEGIN;
SET SESSION AUTHORIZATION reader_user;
SET ROLE app_reader_s1;

DO $$
DECLARE
    v_guc   TEXT;
    v_rows  INTEGER;
BEGIN
    PERFORM app.set_session_ctx(1);

    v_guc := current_setting('app.branch_id', true);
    SELECT count(*) INTO v_rows FROM app.passengers p where p.branch_id = 1;
    IF v_guc <> '1' OR v_rows = 0 THEN
        RAISE EXCEPTION '8 - FAIL: контекст не установлен: guc branch=% строк=%', v_guc, v_rows;
    END IF;

    RAISE NOTICE '8 - PASS: guc установлен, видно % строк', v_rows;
END $$;

ROLLBACK;

-- 9 - попытка установить чужой филиал в guc
BEGIN;
SET SESSION AUTHORIZATION reader_user;
SET ROLE app_reader_s1;

DO $$
BEGIN
    PERFORM app.set_session_ctx(2);
    RAISE EXCEPTION '9 - FAIL: чужой филиал 2 был разрешён роли из филиала 1';
EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE '9 - PASS: доступ к чужому филиалу отклонён: %', SQLERRM;
END $$;

ROLLBACK;

-- 10 создание билета своего филиала
BEGIN;
SET SESSION AUTHORIZATION writer_user;
SET ROLE app_writer_s1;

DO $$
BEGIN
    BEGIN
        PERFORM app.create_ticket(1, 1, 10, NULL);
    EXCEPTION WHEN OTHERS THEN
        RAISE EXCEPTION '10 - FAIL: билет в своём филиале не создан: %', SQLERRM;
    END;
    RAISE NOTICE '10 - PASS: билет в своем филиале создан';
END $$;

ROLLBACK;

-- 11 создание билета чужого филиала
BEGIN;
SET SESSION AUTHORIZATION writer_user;
SET ROLE app_writer_s1;

DO $$
BEGIN
    BEGIN
        PERFORM app.create_ticket(3, 1, 5, NULL);
        RAISE EXCEPTION '11 - FAIL: билет на рейс чужого филиала был создан';
    EXCEPTION WHEN OTHERS THEN
        RAISE NOTICE '11 - PASS: межфилиальная операция запрещена %', SQLERRM;
    END;
END $$;

ROLLBACK;

\echo 'Все тесты пройдены'
