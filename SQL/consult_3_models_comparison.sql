-- Бенчмарки: (А) размер на диске, (Б) скорость тяжелых запросов
--
-- МЕТОДИКА ЗАМЕРА ВРЕМЕНИ:
--   1. В psql выполните: \timing on
--   2. Каждый запрос прогоняйте 3 раза подряд, фиксируйте ВТОРОЙ и
--      ТРЕТИЙ результат (первый прогрев кэша не считается репрезентативным)
--   3. Для честного сравнения используйте EXPLAIN (ANALYZE, BUFFERS)
--      и смотрите Execution Time + Buffers: shared hit/read
--   4. Прогоните весь блок дважды: без индексов (после 01-03) и
--      с индексами (после 04_indexes.sql) 
-- =====================================================================
-- (А) РАЗМЕР НА ДИСКЕ
-- ===================================================================== 
SELECT 'sales_events_sti' AS object,
       pg_size_pretty(pg_relation_size('sales_events_sti'))       AS table_size,
       pg_size_pretty(pg_indexes_size('sales_events_sti'))        AS indexes_size,
       pg_size_pretty(pg_total_relation_size('sales_events_sti')) AS total_size
UNION ALL
SELECT 'sales_events_cti (база)',
       pg_size_pretty(pg_relation_size('sales_events_cti')),
       pg_size_pretty(pg_indexes_size('sales_events_cti')),
       pg_size_pretty(pg_total_relation_size('sales_events_cti'))
UNION ALL
SELECT 'sales_events_cti_dvd',
       pg_size_pretty(pg_relation_size('sales_events_cti_dvd')),
       pg_size_pretty(pg_indexes_size('sales_events_cti_dvd')),
       pg_size_pretty(pg_total_relation_size('sales_events_cti_dvd'))
UNION ALL
SELECT 'sales_events_cti_merch',
       pg_size_pretty(pg_relation_size('sales_events_cti_merch')),
       pg_size_pretty(pg_indexes_size('sales_events_cti_merch')),
       pg_size_pretty(pg_total_relation_size('sales_events_cti_merch'))
UNION ALL
SELECT 'sales_events_eav_base',
       pg_size_pretty(pg_relation_size('sales_events_eav_base')),
       pg_size_pretty(pg_indexes_size('sales_events_eav_base')),
       pg_size_pretty(pg_total_relation_size('sales_events_eav_base'))
UNION ALL
SELECT 'sales_event_attributes',
       pg_size_pretty(pg_relation_size('sales_event_attributes')),
       pg_size_pretty(pg_indexes_size('sales_event_attributes')),
       pg_size_pretty(pg_total_relation_size('sales_event_attributes'));
 
-- Итоговый размер КАЖДОГО РЕШЕНИЯ ЦЕЛИКОМ (для итоговой таблицы в отчёте)
SELECT 'STI решение (1 таблица)' AS solution,
       pg_size_pretty(pg_total_relation_size('sales_events_sti')) AS total
UNION ALL
SELECT 'CTI решение (3 таблицы)',
       pg_size_pretty(
           pg_total_relation_size('sales_events_cti') +
           pg_total_relation_size('sales_events_cti_dvd') +
           pg_total_relation_size('sales_events_cti_merch'))
UNION ALL
SELECT 'EAV решение (2 таблицы)',
       pg_size_pretty(
           pg_total_relation_size('sales_events_eav_base') +
           pg_total_relation_size('sales_event_attributes'));
 
-- =====================================================================
-- (Б) ЗАПРОС 1 — "Выручка по городам от проката DVD за 2023 год"
-- Средней тяжести: JOIN customer -> address -> city, фильтр + агрегация
-- =====================================================================
 
----- STI ---
--Execution time ~ 35 726 ms
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
	ci.city, 
	COUNT(*) 					AS rentals, 
	SUM(s.amount) 				AS revenue,
    AVG(s.rental_duration) 		AS avg_duration
FROM sales_events_sti 	AS s
JOIN customer 	AS c 	ON s.customer_id = c.customer_id
JOIN address 	AS a  	ON c.address_id  = a.address_id
JOIN city 		AS ci   ON a.city_id     = ci.city_id
WHERE s.event_type = 'dvd_rent'
AND s.event_date >= '2023-01-01' 
AND s.event_date < '2024-01-01'
GROUP BY ci.city
ORDER BY revenue DESC
LIMIT 20;
 
----- CTI ---
--Execution time ~ 54 445 ms
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
	ci.city,
	COUNT(*) 				AS rentals, 
	SUM(b.amount) 			AS revenue,
   	AVG(d.rental_duration) 	AS avg_duration
FROM sales_events_cti 		AS b
JOIN sales_events_cti_dvd 	AS d 	ON b.event_id = d.event_id
JOIN customer 				AS c 	ON b.customer_id = c.customer_id
JOIN address 				AS a  	ON c.address_id  = a.address_id
JOIN city 					AS ci   ON a.city_id     = ci.city_id
WHERE b.event_date >= '2023-01-01' 
AND b.event_date < '2024-01-01'
GROUP BY ci.city
ORDER BY revenue DESC
LIMIT 20;
 
----- EAV ---
--Execution time ~ 93 737 ms
EXPLAIN (ANALYZE, BUFFERS)
SELECT 
	ci.city, 
	COUNT(*) 							AS rentals, 
	SUM(b.amount) 						AS revenue,
	AVG(attr.attribute_value::numeric)  AS avg_duration
FROM sales_events_eav_base 		AS b
JOIN sales_event_attributes 	AS attr
ON b.event_id = attr.event_id
JOIN customer 	AS c 	ON b.customer_id = c.customer_id
JOIN address  	AS a  	ON c.address_id  = a.address_id
JOIN city 		AS ci   ON a.city_id     = ci.city_id
WHERE b.event_type = 'dvd_rent'
AND attr.attribute_name = 'rental_duration'
AND b.event_date >= '2023-01-01' 
AND b.event_date < '2024-01-01'
GROUP BY ci.city
ORDER BY revenue DESC
LIMIT 20;
 
 
-- =====================================================================
-- (Б) ЗАПРОС 2 — "Продажи мерча по цветам и размерам по каждому
-- магазину, с указанием города магазина и менеджера"
-- =====================================================================
 
-- --- STI ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT st.store_id, ci.city, s.color, s.size,
       COUNT(*) AS units_sold, SUM(s.amount) AS revenue
FROM sales_events_sti s
JOIN store st   ON s.store_id  = st.store_id
JOIN address a  ON st.address_id = a.address_id
JOIN city ci    ON a.city_id     = ci.city_id
WHERE s.event_type = 'merchandise'
GROUP BY st.store_id, ci.city, s.color, s.size
ORDER BY revenue DESC
LIMIT 30;
 
-- --- CTI ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT st.store_id, ci.city, m.color, m.size,
       COUNT(*) AS units_sold, SUM(b.amount) AS revenue
FROM sales_events_cti b
JOIN sales_events_cti_merch m ON b.event_id = m.event_id
JOIN store st   ON b.store_id  = st.store_id
JOIN address a  ON st.address_id = a.address_id
JOIN city ci    ON a.city_id     = ci.city_id
GROUP BY st.store_id, ci.city, m.color, m.size
ORDER BY revenue DESC
LIMIT 30;
 
-- --- EAV ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT st.store_id, ci.city, p.color, p.size,
       COUNT(*) AS units_sold, SUM(b.amount) AS revenue
FROM sales_events_eav_base b
JOIN (
    SELECT event_id,
           MAX(attribute_value) FILTER (WHERE attribute_name = 'color') AS color,
           MAX(attribute_value) FILTER (WHERE attribute_name = 'size')  AS size
    FROM sales_event_attributes
    WHERE attribute_name IN ('color','size')
    GROUP BY event_id
) p ON b.event_id = p.event_id
JOIN store st   ON b.store_id  = st.store_id
JOIN address a  ON st.address_id = a.address_id
JOIN city ci    ON a.city_id     = ci.city_id
WHERE b.event_type = 'merchandise'
GROUP BY st.store_id, ci.city, p.color, p.size
ORDER BY revenue DESC
LIMIT 30;
 
 
-- =====================================================================
-- (Б) ЗАПРОС 3 — "Клиентский 360°-отчёт": самый тяжёлый запрос.
-- Для каждого клиента: выручка по прокату, средняя длительность
-- аренды, выручка по мерчу, любимый цвет мерча, город и страна.
-- Именно здесь EAV должен показать наихудший результат — требуется
-- полный pivot атрибутов по 15 млн событий (group by на ~60 млн строк).
-- =====================================================================
 
-- --- STI ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.first_name, c.last_name, co.country, ci.city,
       COUNT(*) FILTER (WHERE s.event_type='dvd_rent')      AS rentals,
       SUM(s.amount) FILTER (WHERE s.event_type='dvd_rent') AS dvd_revenue,
       AVG(s.rental_duration)                                AS avg_duration,
       COUNT(*) FILTER (WHERE s.event_type='merchandise')      AS purchases,
       SUM(s.amount) FILTER (WHERE s.event_type='merchandise') AS merch_revenue,
       mode() WITHIN GROUP (ORDER BY s.color)                AS favorite_color
FROM sales_events_sti s
JOIN customer c ON s.customer_id = c.customer_id
JOIN address a  ON c.address_id  = a.address_id
JOIN city ci    ON a.city_id     = ci.city_id
JOIN country co ON ci.country_id = co.country_id
GROUP BY c.customer_id, c.first_name, c.last_name, co.country, ci.city
ORDER BY dvd_revenue DESC NULLS LAST
LIMIT 50;
 
-- --- CTI ---
EXPLAIN (ANALYZE, BUFFERS)
SELECT c.customer_id, c.first_name, c.last_name, co.country, ci.city,
       COUNT(*) FILTER (WHERE b.event_type='dvd_rent')      AS rentals,
       SUM(b.amount) FILTER (WHERE b.event_type='dvd_rent') AS dvd_revenue,
       AVG(d.rental_duration)                                AS avg_duration,
       COUNT(*) FILTER (WHERE b.event_type='merchandise')      AS purchases,
       SUM(b.amount) FILTER (WHERE b.event_type='merchandise') AS merch_revenue,
       mode() WITHIN GROUP (ORDER BY m.color)                AS favorite_color
FROM sales_events_cti b
JOIN customer c ON b.customer_id = c.customer_id
JOIN address a  ON c.address_id  = a.address_id
JOIN city ci    ON a.city_id     = ci.city_id
JOIN country co ON ci.country_id = co.country_id
LEFT JOIN sales_events_cti_dvd d   ON b.event_id = d.event_id
LEFT JOIN sales_events_cti_merch m ON b.event_id = m.event_id
GROUP BY c.customer_id, c.first_name, c.last_name, co.country, ci.city
ORDER BY dvd_revenue DESC NULLS LAST
LIMIT 50;
 
-- --- EAV ---
EXPLAIN (ANALYZE, BUFFERS)
WITH eav_pivot AS (
    SELECT event_id,
           MAX(attribute_value) FILTER (WHERE attribute_name='rental_duration')::numeric AS rental_duration,
           MAX(attribute_value) FILTER (WHERE attribute_name='color')                     AS color
    FROM sales_event_attributes
    WHERE attribute_name IN ('rental_duration','color')
    GROUP BY event_id
)
SELECT c.customer_id, c.first_name, c.last_name, co.country, ci.city,
       COUNT(*) FILTER (WHERE b.event_type='dvd_rent')      AS rentals,
       SUM(b.amount) FILTER (WHERE b.event_type='dvd_rent') AS dvd_revenue,
       AVG(p.rental_duration)                                AS avg_duration,
       COUNT(*) FILTER (WHERE b.event_type='merchandise')      AS purchases,
       SUM(b.amount) FILTER (WHERE b.event_type='merchandise') AS merch_revenue,
       mode() WITHIN GROUP (ORDER BY p.color)                AS favorite_color
FROM sales_events_eav_base b
JOIN eav_pivot p ON b.event_id = p.event_id
JOIN customer c ON b.customer_id = c.customer_id
JOIN address a  ON c.address_id  = a.address_id
JOIN city ci    ON a.city_id     = ci.city_id
JOIN country co ON ci.country_id = co.country_id
GROUP BY c.customer_id, c.first_name, c.last_name, co.country, ci.city
ORDER BY dvd_revenue DESC NULLS LAST
LIMIT 50;