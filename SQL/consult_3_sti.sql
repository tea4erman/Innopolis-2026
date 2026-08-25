-- Вариант 1: STI (Single Table Inheritance)
-- Перед запуском проверьте реальные диапазоны id в вашей dvdrental:
-- SELECT count(*) FROM customer;   -- ожидается 599
-- SELECT count(*) FROM store;      -- ожидается 2
-- SELECT count(*) FROM staff;      -- ожидается 2
-- SELECT count(*) FROM film;       -- ожидается 1000
-- Если числа отличаются — поправьте константы 599 / 2 / 2 / 1000 ниже.
 
DROP TABLE IF EXISTS sales_events_sti;
 
CREATE TABLE sales_events_sti (
    event_id        BIGINT 		  PRIMARY KEY,
    event_type      VARCHAR(20)   NOT NULL,     -- 'dvd_rent' / 'merchandise'
    customer_id     SMALLINT      NOT NULL,
    store_id        SMALLINT      NOT NULL,
    staff_id        SMALLINT      NOT NULL,
    event_date      TIMESTAMP     NOT NULL,
    amount          NUMERIC(10,2) NOT NULL,
    -- === атрибуты подтипа dvd_rent (NULL для merchandise) ===
    film_id         SMALLINT,
    rental_duration SMALLINT,
    rental_rate     NUMERIC(4,2),
    return_date     TIMESTAMP,
    -- === атрибуты подтипа merchandise (NULL для dvd_rent) ===
    product_sku     VARCHAR(20),
    color           VARCHAR(30),
    size            VARCHAR(10),
    sex             VARCHAR(10)
);
 
-- Настройки сессии для ускорения массовой загрузки (не влияют на
-- целостность данных, только на скорость записи; безопасны для лабы)
SET synchronous_commit = OFF;
SET maintenance_work_mem = '512MB';
 
-- Генерация 15 000 000 строк.
-- is_dvd вычисляется ОДИН РАЗ на строку и переиспользуется во всех
-- зависимых колонках — иначе разные random() в разных CASE дадут
-- рассинхронизацию event_type и заполненных атрибутов.
INSERT INTO sales_events_sti
SELECT
    gs                                                              AS event_id,
    CASE WHEN is_dvd THEN 'dvd_rent' ELSE 'merchandise' END         AS event_type,
    (floor(random() * 599) + 1)::SMALLINT                           AS customer_id,
    (floor(random() * 2)   + 1)::SMALLINT                           AS store_id,
    (floor(random() * 2)   + 1)::SMALLINT                           AS staff_id,
    TIMESTAMP '2022-01-01' + (random() * 1460) * INTERVAL '1 day'   AS event_date,
    CASE WHEN is_dvd
         THEN round((random() * 3 + 0.99)::numeric, 2)              -- прокат дешевле
         ELSE round((random() * 45 + 4.99)::numeric, 2)             -- мерч дороже
    END                                                              AS amount,
    -- dvd-атрибуты
    CASE WHEN is_dvd THEN (floor(random()*1000)+1)::SMALLINT END    AS film_id,
    CASE WHEN is_dvd THEN (ARRAY[3,5,7])[(floor(random()*3)+1)::int] END AS rental_duration,
    CASE WHEN is_dvd THEN round((random()*4+0.99)::numeric,2) END   AS rental_rate,
    CASE WHEN is_dvd AND random() < 0.85                            -- 15% ещё не возвращены
         THEN TIMESTAMP '2022-01-01' + (random()*1460)*INTERVAL '1 day' + INTERVAL '5 days'
    END                                                              AS return_date,
    -- merch-атрибуты
    CASE WHEN NOT is_dvd THEN 'SKU-' || (floor(random()*90000)+10000)::text END AS product_sku,
    CASE WHEN NOT is_dvd THEN (ARRAY['black','white','red','blue','green'])[(floor(random()*5)+1)::int] END AS color,
    CASE WHEN NOT is_dvd THEN (ARRAY['XS','S','M','L','XL'])[(floor(random()*5)+1)::int] END AS size,
    CASE WHEN NOT is_dvd THEN (ARRAY['male','female','unisex'])[(floor(random()*3)+1)::int] END AS sex
FROM (
    SELECT gs, (random() < 0.7) AS is_dvd     -- 70% прокат, 30% мерч
    FROM generate_series(1, 15000000) AS gs
) src;
 
-- Ориентировочное время загрузки: 3-8 минут в зависимости от железа.
 
ANALYZE sales_events_sti;
 
-- Контрольная проверка распределения
SELECT event_type, count(*), round(100.0*count(*)/sum(count(*)) OVER (), 1) AS pct
FROM sales_events_sti GROUP BY event_type;