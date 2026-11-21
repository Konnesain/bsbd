CREATE SCHEMA exp;

CREATE TABLE exp.vehicles (
    id                  INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    plate_number        VARCHAR(15) NOT NULL UNIQUE,
    model               VARCHAR(100) NOT NULL,
    capacity            INTEGER NOT NULL CHECK (capacity > 0),
    year_manufactured   INTEGER CHECK (year_manufactured >= 1990 AND year_manufactured <= EXTRACT(YEAR FROM CURRENT_DATE))
);

CREATE TABLE exp.routes (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    number          VARCHAR(20) NOT NULL UNIQUE,
    origin          VARCHAR(100) NOT NULL,
    destination     VARCHAR(100) NOT NULL,
    base_price      NUMERIC(10,2) NOT NULL CHECK (base_price > 0),

    CONSTRAINT chk_route_origin_dest CHECK (origin <> destination)
);

INSERT INTO exp.routes (number, origin, destination, base_price) VALUES
    ('101', 'Москва',           'Санкт-Петербург', 1800.00);

INSERT INTO exp.vehicles (plate_number, model, capacity, year_manufactured) VALUES
    ('А123ВС77', 'Neoplan N316 SHD',   44, 2012);

CREATE TABLE exp.trips_check (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id        INTEGER NOT NULL REFERENCES exp.routes(id),
    vehicle_id      INTEGER NOT NULL REFERENCES exp.vehicles(id),
    departure_time  TIMESTAMPTZ NOT NULL,
    arrival_time    TIMESTAMPTZ NOT NULL,
    status          VARCHAR(20) DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'boarding', 'in_progress', 'completed', 'cancelled')),
    CONSTRAINT chk_trip_times CHECK (arrival_time > departure_time)
);

CREATE TABLE exp.trips_trigger (
    id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    route_id        INTEGER NOT NULL REFERENCES exp.routes(id),
    vehicle_id      INTEGER NOT NULL REFERENCES exp.vehicles(id),
    departure_time  TIMESTAMPTZ NOT NULL,
    arrival_time    TIMESTAMPTZ NOT NULL,
    status          VARCHAR(20) DEFAULT 'scheduled'
);

CREATE FUNCTION exp.fn_check_trip_constraints_trigger()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.status NOT IN ('scheduled', 'boarding', 'in_progress', 'completed', 'cancelled') THEN
        RAISE EXCEPTION 'Недопустимый статус поездки';
    END IF;

    IF NEW.arrival_time <= NEW.departure_time THEN
        RAISE EXCEPTION 'Время прибытия должно быть позже времени отправления';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_check_trip_constraints
BEFORE INSERT OR UPDATE ON exp.trips_trigger
FOR EACH ROW
EXECUTE FUNCTION exp.fn_check_trip_constraints_trigger();

EXPLAIN ANALYZE
INSERT INTO exp.trips_check (route_id, vehicle_id, departure_time, arrival_time, status)
    SELECT 1, 1, '2026-01-01', '2026-01-02', 'scheduled'
    FROM generate_series(1, 10000);

EXPLAIN ANALYZE
INSERT INTO exp.trips_trigger (route_id, vehicle_id, departure_time, arrival_time, status)
    SELECT 1, 1, '2026-01-01', '2026-01-02', 'scheduled'
    FROM generate_series(1, 10000);

DROP SCHEMA exp CASCADE;