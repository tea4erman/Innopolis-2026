-- Вариант 2: CTI (Class Table Inheritance)
-- данные разворачиваются из sales_events_sti
 
DROP TABLE IF EXISTS sales_events_cti_dvd;
DROP TABLE IF EXISTS sales_events_cti_merch;
DROP TABLE IF EXISTS sales_events_cti;
 
-- Базовая таблица: только общие для всех событий поля
CREATE TABLE sales_events_cti (
    event_id     BIGINT PRIMARY KEY,
    event_type   VARCHAR(20)   NOT NULL,
    customer_id  SMALLINT      NOT NULL,
    store_id     SMALLINT      NOT NULL,
    staff_id     SMALLINT      NOT NULL,
    event_date   TIMESTAMP     NOT NULL,
    amount       NUMERIC(10,2) NOT NULL
);
 
CREATE TABLE sales_events_cti_dvd (
    event_id        BIGINT PRIMARY KEY REFERENCES sales_events_cti(event_id),
    film_id         SMALLINT      NOT NULL,
    rental_duration SMALLINT      NOT NULL,
    rental_rate     NUMERIC(4,2)  NOT NULL,
    return_date     TIMESTAMP
);
 
CREATE TABLE sales_events_cti_merch (
    event_id     BIGINT PRIMARY KEY REFERENCES sales_events_cti(event_id),
    product_sku  VARCHAR(20)  NOT NULL,
    color        VARCHAR(30)  NOT NULL,
    size         VARCHAR(10)  NOT NULL,
    sex          VARCHAR(10)  NOT NULL
);
 
SET synchronous_commit = OFF;
 
-- Наполнение базовой таблицы (все 15M строк)
INSERT INTO sales_events_cti
SELECT event_id, event_type, customer_id, store_id, staff_id, event_date, amount
FROM sales_events_sti;
 
-- Наполнение подтипа dvd_rent (~70% строк, без единого NULL)
INSERT INTO sales_events_cti_dvd
SELECT event_id, film_id, rental_duration, rental_rate, return_date
FROM sales_events_sti
WHERE event_type = 'dvd_rent';
 
-- Наполнение подтипа merchandise (~30% строк, без единого NULL)
INSERT INTO sales_events_cti_merch
SELECT event_id, product_sku, color, size, sex
FROM sales_events_sti
WHERE event_type = 'merchandise';
 
-- Контрольная проверка: суммы строк должны совпадать с STI
SELECT
    (SELECT count(*) FROM sales_events_cti)       AS base_rows,
    (SELECT count(*) FROM sales_events_cti_dvd)   AS dvd_rows,
    (SELECT count(*) FROM sales_events_cti_merch) AS merch_rows;