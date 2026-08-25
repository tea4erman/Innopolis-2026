-- Вариант 3: EAV (Entity-Attribute-Value)

-- ВАЖНО: базовая таблица здесь СОЗДАЕТСЯ ОТДЕЛЬНО от sales_events_cti
-- (не переиспользуется), чтобы решение EAV было самодостаточным и
-- его полный размер на диске (база + атрибуты) измерялся честно, как
-- отдельный вариант архитектуры, а не делил базовую таблицу с CTI.
-- =====================================================================
 
DROP TABLE IF EXISTS sales_event_attributes;
DROP TABLE IF EXISTS sales_events_eav_base;
 
CREATE TABLE sales_events_eav_base (
    event_id     BIGINT PRIMARY KEY,
    event_type   VARCHAR(20)   NOT NULL,
    customer_id  SMALLINT      NOT NULL,
    store_id     SMALLINT      NOT NULL,
    staff_id     SMALLINT      NOT NULL,
    event_date   TIMESTAMP     NOT NULL,
    amount       NUMERIC(10,2) NOT NULL
);
 
CREATE TABLE sales_event_attributes (
    event_id        BIGINT       NOT NULL REFERENCES sales_events_eav_base(event_id),
    attribute_name   VARCHAR(30) NOT NULL,
    attribute_value  VARCHAR(255)
);
 
SET synchronous_commit = OFF;
 
INSERT INTO sales_events_eav_base
SELECT event_id, event_type, customer_id, store_id, staff_id, event_date, amount
FROM sales_events_sti;
 
-- Разворачиваем 8 потенциальных колонок-атрибутов в строки.
-- Каждое событие дает ровно 4 строки атрибутов (свои 4 для dvd,
-- свои 4 для merch) — итог: ~15M * 4 = ~60M строк в attributes.
-- Главный наглядный эффект EAV: разбухание числа строк.
INSERT INTO sales_event_attributes (event_id, attribute_name, attribute_value)
SELECT event_id, 'film_id', film_id::text
FROM sales_events_sti WHERE film_id IS NOT NULL
UNION ALL
SELECT event_id, 'rental_duration', rental_duration::text
FROM sales_events_sti WHERE rental_duration IS NOT NULL
UNION ALL
SELECT event_id, 'rental_rate', rental_rate::text
FROM sales_events_sti WHERE rental_rate IS NOT NULL
UNION ALL
SELECT event_id, 'return_date', return_date::text
FROM sales_events_sti WHERE return_date IS NOT NULL
UNION ALL
SELECT event_id, 'product_sku', product_sku
FROM sales_events_sti WHERE product_sku IS NOT NULL
UNION ALL
SELECT event_id, 'color', color
FROM sales_events_sti WHERE color IS NOT NULL
UNION ALL
SELECT event_id, 'size', size
FROM sales_events_sti WHERE size IS NOT NULL
UNION ALL
SELECT event_id, 'sex', sex
FROM sales_events_sti WHERE sex IS NOT NULL;
 
ANALYZE sales_events_eav_base;
ANALYZE sales_event_attributes;
 
-- Контрольная проверка покажет разбухший объем строк
SELECT
    (SELECT count(*) FROM sales_events_eav_base)   AS base_rows,
    (SELECT count(*) FROM sales_event_attributes)  AS attribute_rows;
 