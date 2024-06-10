-- Общие настройки

SET statement_timeout = 0; 
SET lock_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SET client_min_messages = warning;


DROP TABLE IF EXISTS Tickets CASCADE;
DROP TABLE IF EXISTS Payments CASCADE;
DROP TABLE IF EXISTS Passengers CASCADE;
DROP TABLE IF EXISTS Flights CASCADE;
DROP TABLE IF EXISTS Airports CASCADE;
DROP TABLE IF EXISTS Airplanes CASCADE;
DROP TABLE IF EXISTS Airlines CASCADE;

-- Таблицы бизнеса
-- Компании
CREATE TABLE Airlines (
    airline_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL
);

-- Самолёты
CREATE TABLE Airplanes (
    airplane_id SERIAL PRIMARY KEY,
    airline_id INT NOT NULL,
    model VARCHAR(50) NOT NULL,
    manufacturer VARCHAR(50) NOT NULL,
    seating_capacity INT NOT NULL,
    FOREIGN KEY (airline_id) REFERENCES Airlines(airline_id)
);

-- Аэропорты
CREATE TABLE Airports (
    airport_id SERIAL PRIMARY KEY,
    name VARCHAR(100) NOT NULL,
    city VARCHAR(100) NOT NULL, 
    country VARCHAR(100) NOT NULL
);

-- Рейсы
CREATE TABLE Flights (
    flight_id SERIAL PRIMARY KEY,
    airplane_id INT NOT NULL,
    origin_airport_id INT NOT NULL,
    destination_airport_id INT NOT NULL,
    departure_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    arrival_time TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    flight_number VARCHAR(10) NOT NULL,
    FOREIGN KEY (airplane_id) REFERENCES Airplanes(airplane_id),
    FOREIGN KEY (origin_airport_id) REFERENCES Airports(airport_id),
    FOREIGN KEY (destination_airport_id) REFERENCES Airports(airport_id)
);


-- Таблицы клиента
-- Пассажир
CREATE TABLE Passengers (
    passenger_id SERIAL PRIMARY KEY,
    first_name VARCHAR(100) NOT NULL,
    last_name VARCHAR(100) NOT NULL,
    birthday TIMESTAMP NOT NULL,
    passport_number VARCHAR(50) NOT NULL,
    email VARCHAR(100),
    phone_number VARCHAR(20)
);

-- Оплата
CREATE TABLE Payments (
    payment_id SERIAL PRIMARY KEY,
    payment_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP NOT NULL,
    amount DECIMAL(10, 2) CHECK (amount >= 0) NOT NULL
);

-- Билет
CREATE TABLE Tickets (
    ticket_id SERIAL PRIMARY KEY,
    payment_id INT NOT NULL,
    passenger_id INT NOT NULL,
    flight_id INT NOT NULL,
    ticket_number VARCHAR(20) NOT NULL,
    seat_number VARCHAR(10) NOT NULL,
    class VARCHAR(20) NOT NULL,
    FOREIGN KEY (payment_id) REFERENCES Payments(payment_id),
    FOREIGN KEY (passenger_id) REFERENCES Passengers(passenger_id),
    FOREIGN KEY (flight_id) REFERENCES Flights(flight_id)
);


-- Бизнес логика
-- Фунцкции

-- Получение всех данных для отображения билета
DROP FUNCTION IF EXISTS public.get_ticket_info(INT);

CREATE OR REPLACE FUNCTION public.get_ticket_info(ticket_id INT)
RETURNS TABLE (
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    ticket_number VARCHAR(20),
    seat_number VARCHAR(10),
    class VARCHAR(20),
    departure_time TIMESTAMP,
    arrival_time TIMESTAMP,
    origin_airport_name VARCHAR(100),
    destination_airport_name VARCHAR(100)
) AS $$
BEGIN
 RETURN QUERY
 SELECT 
     p.first_name, p.last_name, 
     t.ticket_number, t.seat_number, t.class, 
     f.departure_time, f.arrival_time,
     o.name as origin_airport_name, 
     d.name as destination_airport_name
 FROM Tickets t
 INNER JOIN Passengers p ON t.passenger_id = p.passenger_id
 INNER JOIN Flights f ON t.flight_id = f.flight_id
 INNER JOIN Airports o ON f.origin_airport_id = o.airport_id
 INNER JOIN Airports d ON f.destination_airport_id = d.airport_id
 WHERE t.ticket_id = get_ticket_info.ticket_id;
END;
$$ LANGUAGE plpgsql;


-- Процедура для создания билета
DROP PROCEDURE IF EXISTS public.create_ticket;

CREATE OR REPLACE PROCEDURE public.create_ticket(
    first_name VARCHAR(100),
    last_name VARCHAR(100),
    birthday TIMESTAMP,
    passport_number VARCHAR(50),
    email VARCHAR(100),
    phone_number VARCHAR(20),
    amount DECIMAL(10, 2),
    flight_id INT,
    seat_number VARCHAR(10),
    class VARCHAR(20)
)
LANGUAGE plpgsql
AS $$
DECLARE
    new_passenger_id INT;
    new_payment_id INT;
BEGIN
    -- Проверка пассажира
    SELECT passenger_id INTO new_passenger_id
    FROM Passengers p
    WHERE p.first_name = create_ticket.first_name
      AND p.last_name = create_ticket.last_name
      AND p.passport_number = create_ticket.passport_number;

    -- Если пассажира нет, то создаём его и возвращаем id
    IF new_passenger_id IS NULL THEN
        INSERT INTO Passengers (first_name, last_name, birthday, passport_number, email, phone_number)
        VALUES (create_ticket.first_name, create_ticket.last_name, create_ticket.birthday, create_ticket.passport_number, create_ticket.email, create_ticket.phone_number)
        RETURNING passenger_id INTO new_passenger_id;
    END IF;

    -- Добавляем сведения о новой оплате
    INSERT INTO Payments(amount)
    VALUES (create_ticket.amount)
    RETURNING payment_id INTO new_payment_id;

    -- Создание нового билета
    INSERT INTO Tickets (payment_id, passenger_id, flight_id, ticket_number, seat_number, class)
    VALUES (new_payment_id, new_passenger_id, create_ticket.flight_id,  
            CONCAT('T', new_payment_id, '-', new_passenger_id, '-', create_ticket.flight_id), create_ticket.seat_number, create_ticket.class);

    RAISE NOTICE 'Booking created with passenger_id: %, payment_id: %', new_passenger_id, new_payment_id;
END;
$$;

-- Вызов процедуры
CALL public.create_ticket(
    'John',
    'Doe',
    '1985-05-15 00:00:00',
    'A12345678',
    'john.doe@example.com',
    '+1234567890',
    200.00,
    1,
    '12A',
    'Economy'
);

-- Jobs
-- 
-- CREATE EXTENSION pg_cron; 
-- SELECT cron.schedule('daily_vacuum', '0 3 * * *', $$VACUUM$$);



-- Добавление данных
-- Вставка данных в таблицу Airlines
INSERT INTO Airlines (name) VALUES 
('Airline A'),
('Airline B'),
('Airline C');

-- Вставка данных в таблицу Airplanes
INSERT INTO Airplanes (airline_id, model, manufacturer, seating_capacity) VALUES 
(1, 'Boeing 737', 'Boeing', 150),
(1, 'Airbus A320', 'Airbus', 180),
(2, 'Boeing 747', 'Boeing', 400),
(2, 'Airbus A380', 'Airbus', 500),
(3, 'Embraer 190', 'Embraer', 100);

-- Вставка данных в таблицу Airports
INSERT INTO Airports (name, city, country) VALUES 
('JFK International', 'New York', 'USA'),
('Heathrow', 'London', 'UK'),
('Charles de Gaulle', 'Paris', 'France'),
('Haneda', 'Tokyo', 'Japan'),
('Frankfurt', 'Frankfurt', 'Germany');

-- Вставка данных в таблицу Flights
INSERT INTO Flights (airplane_id, origin_airport_id, destination_airport_id, departure_time, arrival_time, flight_number) VALUES 
(1, 1, 2, '2023-07-01 08:00:00', '2023-07-01 10:00:00', 'AA101'),
(2, 2, 3, '2023-07-02 12:00:00', '2023-07-02 14:00:00', 'BA202'),
(3, 3, 4, '2023-07-03 15:00:00', '2023-07-03 17:00:00', 'CA303'),
(4, 4, 5, '2023-07-04 09:00:00', '2023-07-04 13:00:00', 'DA404'),
(5, 5, 1, '2023-07-05 18:00:00', '2023-07-05 22:00:00', 'EA505');

-- Вставка данных в таблицу Passengers
INSERT INTO Passengers (first_name, last_name, birthday, passport_number, email, phone_number) VALUES 
('John', 'Doe', '1985-01-01', 'A12345678', 'john.doe@example.com', '1234567890'),
('Jane', 'Smith', '1990-02-02', 'B23456789', 'jane.smith@example.com', '2345678901'),
('Alice', 'Johnson', '1975-03-03', 'C34567890', 'alice.johnson@example.com', '3456789012'),
('Bob', 'Brown', '1980-04-04', 'D45678901', 'bob.brown@example.com', '4567890123'),
('Carol', 'Davis', '1995-05-05', 'E56789012', 'carol.davis@example.com', '5678901234');

-- Вставка данных в таблицу Payments
INSERT INTO Payments (payment_date, amount) VALUES 
('2023-06-01 10:00:00', 150.00),
('2023-06-02 11:00:00', 200.00),
('2023-06-03 12:00:00', 250.00),
('2023-06-04 13:00:00', 300.00),
('2023-06-05 14:00:00', 350.00);

-- Вставка данных в таблицу Tickets
INSERT INTO Tickets (payment_id, passenger_id, flight_id, ticket_number, seat_number, class) VALUES 
(1, 1, 1, 'T101', '12A', 'Economy'),
(2, 2, 2, 'T202', '14B', 'Business'),
(3, 3, 3, 'T303', '16C', 'Economy'),
(4, 4, 4, 'T404', '18D', 'First'),
(5, 5, 5, 'T505', '20E', 'Economy');
