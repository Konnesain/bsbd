DROP SCHEMA PUBLIC CASCADE;
CREATE SCHEMA IF NOT EXISTS app;
CREATE SCHEMA IF NOT EXISTS ref;
CREATE SCHEMA IF NOT EXISTS audit;
CREATE SCHEMA IF NOT EXISTS stg;

-- филиалы
CREATE TABLE ref.branches (
    id          INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    code        VARCHAR(30)  NOT NULL UNIQUE,
    name        VARCHAR(100) NOT NULL
);

-- Резервный путь идентификации субъекта: филиальная роль -> branch_id.
CREATE TABLE app.role_branches (
    role_name   NAME PRIMARY KEY,
    branch_id  INTEGER NOT NULL REFERENCES ref.branches(id) ON DELETE CASCADE
);
CREATE INDEX idx_role_branches_branch ON app.role_branches(branch_id);

-- маршруты
CREATE TABLE ref.routes (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    number          VARCHAR(20) NOT NULL UNIQUE,
    origin          VARCHAR(100) NOT NULL,
    destination     VARCHAR(100) NOT NULL,
    base_price      NUMERIC(10,2) NOT NULL CHECK (base_price > 0),

    CONSTRAINT chk_route_origin_dest CHECK (origin <> destination)
);

-- города
CREATE TABLE ref.cities (
    id      INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name    VARCHAR(100) NOT NULL UNIQUE
);

-- остановки
CREATE TABLE ref.stops (
    id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    name       VARCHAR(100) NOT NULL,
    city_id    INTEGER NOT NULL REFERENCES ref.cities(id) ON DELETE CASCADE,

    UNIQUE(name, city_id)
);
CREATE INDEX idx_stops_name ON ref.stops(name);

-- связь остановок и маршрутов
CREATE TABLE ref.route_stops (
    route_id        INTEGER NOT NULL REFERENCES ref.routes(id) ON DELETE CASCADE,
    stop_id         INTEGER NOT NULL REFERENCES ref.stops(id) ON DELETE CASCADE,
    stop_order      INTEGER NOT NULL CHECK (stop_order > 0),
    arrival_offset  INTERVAL,

    PRIMARY KEY (route_id, stop_id)
);

CREATE TABLE stg.passengers_import (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    raw_full_name   VARCHAR(150) NOT NULL,
    phone           VARCHAR(20),
    email           VARCHAR(100),
    passport_raw    VARCHAR(20),
    errors          TEXT,
    imported_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- пассажиры
CREATE TABLE app.passengers (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id      INTEGER NOT NULL REFERENCES ref.branches(id) ON DELETE RESTRICT,
    surname         VARCHAR(50) NOT NULL,
    name            VARCHAR(50) NOT NULL,
    patronymic      VARCHAR(50),
    passport_enc    BYTEA NOT NULL,
    email           VARCHAR(100) NOT NULL,
    phone           VARCHAR(15) NOT NULL CHECK (length(phone) >= 11)
);
CREATE INDEX idx_passengers_surname ON app.passengers(surname);
CREATE INDEX idx_passengers_branch_surname ON app.passengers (branch_id, surname);

-- транспорт
CREATE TABLE app.vehicles (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id          INTEGER NOT NULL REFERENCES ref.branches(id) ON DELETE RESTRICT,
    plate_number        VARCHAR(15) NOT NULL UNIQUE,
    model               VARCHAR(100) NOT NULL,
    capacity            INTEGER NOT NULL CHECK (capacity > 0),
    year_manufactured   INTEGER CHECK (year_manufactured >= 1990 AND year_manufactured <= EXTRACT(YEAR FROM CURRENT_DATE))
);
CREATE INDEX idx_vehicles_branch_plate ON app.vehicles (branch_id, plate_number);

-- рейсы
CREATE TABLE app.trips (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id      INTEGER NOT NULL REFERENCES ref.branches(id) ON DELETE RESTRICT,
    route_id        INTEGER NOT NULL REFERENCES ref.routes(id),
    vehicle_id      INTEGER NOT NULL REFERENCES app.vehicles(id),
    departure_time  TIMESTAMPTZ NOT NULL,
    arrival_time    TIMESTAMPTZ NOT NULL,
    status          VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'boarding', 'in_progress', 'completed', 'cancelled')),

    CONSTRAINT chk_trip_times CHECK (arrival_time > departure_time)
);
CREATE INDEX idx_trips_route ON app.trips(route_id);
CREATE INDEX idx_trips_departure ON app.trips(departure_time);
CREATE INDEX idx_trips_status ON app.trips(status);
CREATE INDEX idx_trips_branch_route ON app.trips (branch_id, route_id);
CREATE INDEX idx_trips_branch_departure ON app.trips (branch_id, departure_time);
CREATE INDEX idx_trips_branch_status ON app.trips (branch_id, status);

-- билеты
CREATE TABLE app.tickets (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    branch_id      INTEGER NOT NULL REFERENCES ref.branches(id) ON DELETE RESTRICT,
    trip_id         INTEGER NOT NULL REFERENCES app.trips(id),
    passenger_id    INTEGER NOT NULL REFERENCES app.passengers(id),
    seat_number     INTEGER NOT NULL CHECK (seat_number > 0),
    price           NUMERIC(10,2) NOT NULL CHECK (price >= 0),
    status          VARCHAR(20) DEFAULT 'issued' CHECK (status IN ('issued', 'paid', 'used', 'cancelled')),
    issued_at       TIMESTAMPTZ DEFAULT NOW(),

    UNIQUE (trip_id, seat_number)
);
CREATE INDEX idx_tickets_trip ON app.tickets(trip_id);
CREATE INDEX idx_tickets_passenger ON app.tickets(passenger_id);
CREATE INDEX idx_tickets_branch_trip ON app.tickets (branch_id, trip_id);
CREATE INDEX idx_tickets_branch_passenger ON app.tickets (branch_id, passenger_id);
CREATE INDEX idx_tickets_branch_status ON app.tickets (branch_id, status);

-- лог входа
CREATE TABLE audit.login_log (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    login_time      TIMESTAMPTZ DEFAULT NOW(),
    username        VARCHAR(100) NOT NULL,
    client_ip       INET
);

-- лог функций
CREATE TABLE audit.function_calls (
    id              BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    call_time       TIMESTAMPTZ NOT NULL DEFAULT clock_timestamp(),
    function_name   TEXT NOT NULL,
    caller_role     NAME NOT NULL,
    input_params    JSONB,
    success         BOOLEAN NOT NULL,
    error_message   TEXT
);