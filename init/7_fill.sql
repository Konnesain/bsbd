SET app.passport_key = 'passport_key';

-- -----------------------------------------------------------------------------
-- 0. Филиалы (ось изоляции BR) и соответствие ролей филиалам
-- -----------------------------------------------------------------------------
INSERT INTO ref.branches (code, name) VALUES
    ('MSK-CENTER', 'Филиал «Москва-Центр»'),
    ('VOLGA-URAL', 'Филиал «Поволжье-Урал»');

-- резервный путь идентификации субъекта: филиальная роль -> branch_id.
-- Админские роли (dml_admin, app_owner/owner_user) и auditor в справочнике
-- не значатся: они не зависят от RLS (BYPASSRLS либо политика auditor).
INSERT INTO app.role_branches (role_name, branch_id) VALUES
    ('app_reader_s1', 1),
    ('app_writer_s1', 1),
    ('app_reader_s2', 2),
    ('app_writer_s2', 2);

-- -----------------------------------------------------------------------------
-- 1. Города (12)
-- -----------------------------------------------------------------------------
INSERT INTO ref.cities (name) VALUES
    ('Москва'),
    ('Санкт-Петербург'),
    ('Казань'),
    ('Новосибирск'),
    ('Екатеринбург'),
    ('Нижний Новгород'),
    ('Самара'),
    ('Омск'),
    ('Ростов-на-Дону'),
    ('Уфа'),
    ('Красноярск'),
    ('Воронеж');

-- -----------------------------------------------------------------------------
-- 2. Остановки (15)
-- -----------------------------------------------------------------------------
INSERT INTO ref.stops (name, city_id) VALUES
    ('Автовокзал Центральный (Москва)',              (SELECT id FROM ref.cities WHERE name = 'Москва')),
    ('Аэропорт Домодедово',                           (SELECT id FROM ref.cities WHERE name = 'Москва')),
    ('Автовокзал Обводный канал (Санкт-Петербург)',   (SELECT id FROM ref.cities WHERE name = 'Санкт-Петербург')),
    ('Аэропорт Пулково',                              (SELECT id FROM ref.cities WHERE name = 'Санкт-Петербург')),
    ('Автостанция Казань-1',                          (SELECT id FROM ref.cities WHERE name = 'Казань')),
    ('ТЦ «Мега» Казань',                              (SELECT id FROM ref.cities WHERE name = 'Казань')),
    ('Автовокзал Новосибирск-Главный',                (SELECT id FROM ref.cities WHERE name = 'Новосибирск')),
    ('Автовокзал Южный (Екатеринбург)',               (SELECT id FROM ref.cities WHERE name = 'Екатеринбург')),
    ('Автостанция Канавинская (Нижний Новгород)',     (SELECT id FROM ref.cities WHERE name = 'Нижний Новгород')),
    ('Автовокзал Центральный (Самара)',               (SELECT id FROM ref.cities WHERE name = 'Самара')),
    ('Автовокзал Омск',                               (SELECT id FROM ref.cities WHERE name = 'Омск')),
    ('Автовокзал Ростов-на-Дону',                     (SELECT id FROM ref.cities WHERE name = 'Ростов-на-Дону')),
    ('Автостанция Уфа-Южная',                         (SELECT id FROM ref.cities WHERE name = 'Уфа')),
    ('Автовокзал Красноярск',                         (SELECT id FROM ref.cities WHERE name = 'Красноярск')),
    ('Автовокзал Воронеж',                            (SELECT id FROM ref.cities WHERE name = 'Воронеж'));

-- -----------------------------------------------------------------------------
-- 3. Маршруты (12)
-- -----------------------------------------------------------------------------
INSERT INTO ref.routes (number, origin, destination, base_price) VALUES
    ('101', 'Москва',           'Санкт-Петербург', 1800.00),
    ('102', 'Санкт-Петербург',  'Москва',          1800.00),
    ('201', 'Москва',           'Казань',          1500.00),
    ('202', 'Казань',           'Москва',          1500.00),
    ('301', 'Москва',           'Нижний Новгород',  900.00),
    ('302', 'Нижний Новгород',  'Москва',           900.00),
    ('401', 'Екатеринбург',     'Новосибирск',     2200.00),
    ('402', 'Новосибирск',      'Екатеринбург',    2200.00),
    ('501', 'Казань',           'Самара',           800.00),
    ('502', 'Самара',           'Казань',           800.00),
    ('601', 'Москва',           'Ростов-на-Дону',  1600.00),
    ('602', 'Ростов-на-Дону',   'Москва',          1600.00);

-- -----------------------------------------------------------------------------
-- 4. Остановки маршрутов (route_stops)
-- -----------------------------------------------------------------------------
INSERT INTO ref.route_stops (route_id, stop_id, stop_order, arrival_offset) VALUES
    ((SELECT id FROM ref.routes WHERE number='101'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Москва)'),            1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='101'), (SELECT id FROM ref.stops WHERE name='Аэропорт Домодедово'),                          2, '01:30'),
    ((SELECT id FROM ref.routes WHERE number='101'), (SELECT id FROM ref.stops WHERE name='Автовокзал Обводный канал (Санкт-Петербург)'), 3, '08:30'),
    ((SELECT id FROM ref.routes WHERE number='102'), (SELECT id FROM ref.stops WHERE name='Автовокзал Обводный канал (Санкт-Петербург)'), 1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='102'), (SELECT id FROM ref.stops WHERE name='Аэропорт Пулково'),                              2, '01:00'),
    ((SELECT id FROM ref.routes WHERE number='102'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Москва)'),              3, '08:30'),
    ((SELECT id FROM ref.routes WHERE number='201'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Москва)'),              1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='201'), (SELECT id FROM ref.stops WHERE name='Автостанция Казань-1'),                          2, '10:45'),
    ((SELECT id FROM ref.routes WHERE number='202'), (SELECT id FROM ref.stops WHERE name='Автостанция Казань-1'),                          1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='202'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Москва)'),              2, '10:45'),
    ((SELECT id FROM ref.routes WHERE number='301'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Москва)'),              1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='301'), (SELECT id FROM ref.stops WHERE name='Автостанция Канавинская (Нижний Новгород)'),    2, '06:30'),
    ((SELECT id FROM ref.routes WHERE number='302'), (SELECT id FROM ref.stops WHERE name='Автостанция Канавинская (Нижний Новгород)'),    1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='302'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Москва)'),              2, '06:30'),
    ((SELECT id FROM ref.routes WHERE number='401'), (SELECT id FROM ref.stops WHERE name='Автовокзал Южный (Екатеринбург)'),             1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='401'), (SELECT id FROM ref.stops WHERE name='Автовокзал Новосибирск-Главный'),              2, '14:00'),
    ((SELECT id FROM ref.routes WHERE number='402'), (SELECT id FROM ref.stops WHERE name='Автовокзал Новосибирск-Главный'),              1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='402'), (SELECT id FROM ref.stops WHERE name='Автовокзал Южный (Екатеринбург)'),             2, '14:00'),
    ((SELECT id FROM ref.routes WHERE number='501'), (SELECT id FROM ref.stops WHERE name='Автостанция Казань-1'),                          1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='501'), (SELECT id FROM ref.stops WHERE name='ТЦ «Мега» Казань'),                              2, '00:40'),
    ((SELECT id FROM ref.routes WHERE number='501'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Самара)'),              3, '05:30'),
    ((SELECT id FROM ref.routes WHERE number='502'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Самара)'),              1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='502'), (SELECT id FROM ref.stops WHERE name='ТЦ «Мега» Казань'),                              2, '04:50'),
    ((SELECT id FROM ref.routes WHERE number='502'), (SELECT id FROM ref.stops WHERE name='Автостанция Казань-1'),                          3, '05:30'),
    ((SELECT id FROM ref.routes WHERE number='601'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Москва)'),              1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='601'), (SELECT id FROM ref.stops WHERE name='Автовокзал Ростов-на-Дону'),                    2, '12:30'),
    ((SELECT id FROM ref.routes WHERE number='602'), (SELECT id FROM ref.stops WHERE name='Автовокзал Ростов-на-Дону'),                    1, '00:00'),
    ((SELECT id FROM ref.routes WHERE number='602'), (SELECT id FROM ref.stops WHERE name='Автовокзал Центральный (Москва)'),              2, '12:30');

-- -----------------------------------------------------------------------------
-- 5. Транспортные средства (12)
-- -----------------------------------------------------------------------------
-- branch_id соответствует филиалу рейса, на котором работает транспортное
-- средство (филиал 1: маршруты 101/102/301/302/601/602,
-- филиал 2: маршруты 201/202/401/402/501/502)
INSERT INTO app.vehicles (branch_id, plate_number, model, capacity, year_manufactured) VALUES
    (1, 'А123ВС77', 'Neoplan N316 SHD',   44, 2012),
    (1, 'В456ЕК78', 'Setra S 515 HD',     48, 2015),
    (2, 'Е789КХ16', 'ЛиАЗ-5292.65',       40, 2018),
    (2, 'К321МН02', 'ПАЗ-3205',           28, 2010),
    (1, 'М654ОР52', 'MAN Lion''s Coach',  46, 2016),
    (1, 'Н987РС66', 'Yutong ZK6122',      50, 2019),
    (2, 'Т135УФ66', 'Scania Touring',     52, 2017),
    (2, 'У246ФХ54', 'Setra S 417 HDH',    50, 2014),
    (2, 'Х357ЦЧ16', 'МАЗ-103.486',        45, 2013),
    (2, 'Ц468ЧШ63', 'Волжанин-5270',      44, 2008),
    (1, 'Ш579ЩЭ77', 'Богдан А092',        42, 2011),
    (1, 'Э680ЮЯ61', 'Ютонг ZK6899H',      46, 2020);

-- -----------------------------------------------------------------------------
-- 6. Пассажиры (12) — паспорт шифруется pgp_sym_encrypt
-- -----------------------------------------------------------------------------
INSERT INTO app.passengers (branch_id, surname, name, patronymic, passport_enc, email, phone) VALUES
    (1, 'Иванов',   'Иван',      'Иванович',    app.pgp_sym_encrypt('4509 123456', current_setting('app.passport_key')), 'ivanov@example.ru',    '79161234567'),
    (1, 'Петрова',  'Мария',     'Сергеевна',   app.pgp_sym_encrypt('4510 234567', current_setting('app.passport_key')), 'petrova@example.ru',   '79212345678'),
    (1, 'Сидоров',  'Алексей',   'Петрович',    app.pgp_sym_encrypt('5012 345678', current_setting('app.passport_key')), 'sidorov@example.ru',   '79053456789'),
    (1, 'Кузнецова','Ольга',     'Андреевна',   app.pgp_sym_encrypt('5013 456789', current_setting('app.passport_key')), 'kuznetsova@example.ru','79674567890'),
    (1, 'Смирнов',  'Дмитрий',   'Владимирович',app.pgp_sym_encrypt('6001 567890', current_setting('app.passport_key')), 'smirnov@example.ru',   '79125678901'),
    (2, 'Волкова',  'Анна',      'Николаевна',  app.pgp_sym_encrypt('6002 678901', current_setting('app.passport_key')), 'volkova@example.ru',   '79536789012'),
    (2, 'Морозов',  'Сергей',    'Александрович',app.pgp_sym_encrypt('7701 789012', current_setting('app.passport_key')), 'morozov@example.ru',   '79267890123'),
    (2, 'Новикова', 'Екатерина', 'Дмитриевна',  app.pgp_sym_encrypt('7702 890123', current_setting('app.passport_key')), 'novikova@example.ru',  '79978901234'),
    (1, 'Фёдоров',  'Павел',     'Игоревич',    app.pgp_sym_encrypt('7801 901234', current_setting('app.passport_key')), 'fedorov@example.ru',   '79989012345'),
    (1, 'Соколова', 'Татьяна',   'Михайловна',  app.pgp_sym_encrypt('7802 012345', current_setting('app.passport_key')), 'sokolova@example.ru',  '79630123456'),
    (2, 'Попов',    'Николай',   'Васильевич',  app.pgp_sym_encrypt('6601 112233', current_setting('app.passport_key')), 'popov@example.ru',     '79121234560'),
    (2, 'Лебедева', 'Ирина',     'Олеговна',    app.pgp_sym_encrypt('6602 223344', current_setting('app.passport_key')), 'lebedeva@example.ru',  '79672345671');

-- -----------------------------------------------------------------------------
-- 7. Рейсы (12)
-- -----------------------------------------------------------------------------
-- филиал рейса определяется филиалом-оператором маршрута
-- (филиал 1: 101/102/301/302/601/602, филиал 2: 201/202/401/402/501/502)
INSERT INTO app.trips (branch_id, route_id, vehicle_id, departure_time, arrival_time, status) VALUES
    (1, (SELECT id FROM ref.routes   WHERE number='101'), (SELECT id FROM app.vehicles WHERE plate_number='А123ВС77'), '2026-11-01 07:30:00+03', '2026-11-01 16:00:00+03', 'scheduled'),
    (1, (SELECT id FROM ref.routes   WHERE number='102'), (SELECT id FROM app.vehicles WHERE plate_number='В456ЕК78'), '2026-11-01 09:00:00+03', '2026-11-01 17:30:00+03', 'scheduled'),
    (2, (SELECT id FROM ref.routes   WHERE number='201'), (SELECT id FROM app.vehicles WHERE plate_number='Е789КХ16'), '2026-11-01 08:15:00+03', '2026-11-01 19:00:00+03', 'boarding'),
    (2, (SELECT id FROM ref.routes   WHERE number='202'), (SELECT id FROM app.vehicles WHERE plate_number='К321МН02'), '2026-11-01 10:00:00+03', '2026-11-01 20:45:00+03', 'scheduled'),
    (1, (SELECT id FROM ref.routes   WHERE number='301'), (SELECT id FROM app.vehicles WHERE plate_number='М654ОР52'), '2026-11-01 06:45:00+03', '2026-11-01 13:15:00+03', 'in_progress'),
    (1, (SELECT id FROM ref.routes   WHERE number='302'), (SELECT id FROM app.vehicles WHERE plate_number='Н987РС66'), '2026-11-01 14:00:00+03', '2026-11-01 20:30:00+03', 'scheduled'),
    (2, (SELECT id FROM ref.routes   WHERE number='401'), (SELECT id FROM app.vehicles WHERE plate_number='Т135УФ66'), '2026-11-01 21:00:00+05', '2026-11-02 11:00:00+07', 'scheduled'),
    (2, (SELECT id FROM ref.routes   WHERE number='402'), (SELECT id FROM app.vehicles WHERE plate_number='У246ФХ54'), '2026-11-02 08:00:00+07', '2026-11-02 22:00:00+05', 'scheduled'),
    (2, (SELECT id FROM ref.routes   WHERE number='501'), (SELECT id FROM app.vehicles WHERE plate_number='Х357ЦЧ16'), '2026-11-01 12:30:00+03', '2026-11-01 18:00:00+03', 'completed'),
    (2, (SELECT id FROM ref.routes   WHERE number='502'), (SELECT id FROM app.vehicles WHERE plate_number='Ц468ЧШ63'), '2026-11-01 19:00:00+03', '2026-11-02 00:30:00+03', 'scheduled'),
    (1, (SELECT id FROM ref.routes   WHERE number='601'), (SELECT id FROM app.vehicles WHERE plate_number='Ш579ЩЭ77'), '2026-11-01 15:00:00+03', '2026-11-02 03:30:00+03', 'cancelled'),
    (1, (SELECT id FROM ref.routes   WHERE number='602'), (SELECT id FROM app.vehicles WHERE plate_number='Э680ЮЯ61'), '2026-11-01 17:00:00+03', '2026-11-02 05:30:00+03', 'scheduled');

-- -----------------------------------------------------------------------------
-- 8. Билеты (16) — ссылки на рейс по номеру маршрута и времени отправления
-- -----------------------------------------------------------------------------
-- филиал билета наследуется от филиала рейса
INSERT INTO app.tickets (branch_id, trip_id, passenger_id, seat_number, price, status, issued_at)
SELECT t.branch_id, t.id, p.id, v.seat, v.price, v.status, v.issued_at::timestamptz
FROM (VALUES
    ('101', '2026-11-01 07:30:00+03', 'Иванов',   'Иван',      'Иванович',   5, 1800.00, 'paid',     '2026-10-20 10:00:00+03'),
    ('101', '2026-11-01 07:30:00+03', 'Петрова',  'Мария',     'Сергеевна',  6, 1800.00, 'issued',   '2026-10-21 12:30:00+03'),
    ('101', '2026-11-01 07:30:00+03', 'Сидоров',  'Алексей',   'Петрович',   7, 1650.00, 'paid',     '2026-10-22 09:15:00+03'),
    ('102', '2026-11-01 09:00:00+03', 'Кузнецова','Ольга',     'Андреевна',  1, 1800.00, 'paid',     '2026-10-20 18:40:00+03'),
    ('102', '2026-11-01 09:00:00+03', 'Смирнов',  'Дмитрий',   'Владимирович',2,1800.00,'used',    '2026-10-15 08:00:00+03'),
    ('201', '2026-11-01 08:15:00+03', 'Волкова',  'Анна',      'Николаевна',10,1500.00,'paid',    '2026-10-18 14:20:00+03'),
    ('201', '2026-11-01 08:15:00+03', 'Морозов',  'Сергей',    'Александрович',11,1500.00,'issued','2026-10-19 16:05:00+03'),
    ('201', '2026-11-01 08:15:00+03', 'Новикова', 'Екатерина', 'Дмитриевна',12,1350.00,'cancelled','2026-10-17 11:00:00+03'),
    ('301', '2026-11-01 06:45:00+03', 'Фёдоров',  'Павел',     'Игоревич',   3,  900.00, 'used',     '2026-10-10 07:45:00+03'),
    ('301', '2026-11-01 06:45:00+03', 'Соколова', 'Татьяна',   'Михайловна', 4,  900.00, 'paid',     '2026-10-12 13:10:00+03'),
    ('501', '2026-11-01 12:30:00+03', 'Попов',    'Николай',   'Васильевич', 8,  800.00, 'used',     '2026-10-25 10:30:00+03'),
    ('501', '2026-11-01 12:30:00+03', 'Лебедева', 'Ирина',     'Олеговна',   9,  800.00, 'used',     '2026-10-25 10:35:00+03'),
    ('501', '2026-11-01 12:30:00+03', 'Иванов',   'Иван',      'Иванович',  15,  750.00, 'used',     '2026-10-26 19:00:00+03'),
    ('601', '2026-11-01 15:00:00+03', 'Петрова',  'Мария',     'Сергеевна', 20, 1600.00, 'cancelled','2026-10-24 09:00:00+03'),
    ('601', '2026-11-01 15:00:00+03', 'Сидоров',  'Алексей',   'Петрович',  21, 1600.00, 'cancelled','2026-10-24 09:05:00+03'),
    ('401', '2026-11-01 21:00:00+05', 'Кузнецова','Ольга',     'Андреевна', 14, 2200.00, 'paid',     '2026-10-19 20:00:00+05')
) AS v(route_number, dep, surname, name, patronymic, seat, price, status, issued_at)
JOIN ref.routes      r ON r.number = v.route_number
JOIN app.trips       t ON t.route_id = r.id AND t.departure_time = v.dep::timestamptz
JOIN app.passengers  p ON p.surname = v.surname AND p.name = v.name AND p.patronymic = v.patronymic;


-- -----------------------------------------------------------------------------
-- 9. Импорт пассажиров в staging (10 записей)
-- -----------------------------------------------------------------------------
INSERT INTO stg.passengers_import (raw_full_name, phone, email, passport_raw, errors)
VALUES
    ('Алексеев Артём Викторович', '79000000001', 'alekseev@example.ru', '4001 000001', NULL),
    ('Борисова Виктория Игоревна', '79000000002', 'borisova@example.ru', '4001 000002', NULL),
    ('Васильев Николай Павлович',  '79000000003', 'vasilyev@example.ru', '4001 000003', NULL),
    ('Григорьева Елена Алексеевна', '79000000004', 'grigoryeva@example.ru','4001 000004', NULL),
    ('Дмитриев Илья Сергеевич',    '79000000005', 'dmitriev@example.ru', '4001 000005', NULL),
    ('Егорова Анастасия Романовна', '79000000006', 'egorova@example.ru',   '4001 000006', NULL),
    ('Жуков Максим Олегович',       '79000000007', 'zhukov@example.ru',    '4001 000007', NULL),
    ('Зайцева Полина Денисовна',    '79000000008', 'zaytseva@example.ru',  '4001 000008', NULL),
    ('Исаев Андрей Евгеньевич',     '79000000009', 'isaev@example.ru',     '4001 000009', NULL),
    ('Ковалёва Дарья Никитична',   '79000000010', 'kovaleva@example.ru',  '4001 000010', NULL);
