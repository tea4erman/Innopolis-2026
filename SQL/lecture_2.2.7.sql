DROP MATERIALIZED VIEW IF EXISTS mv_customer_summary;

-- Dim_Date — измерение времени --
DROP VIEW IF EXISTS vw_dim_date;
CREATE VIEW vw_dim_date AS 
SELECT
    TO_CHAR(d, 'YYYYMMDD')::INT    	AS date_key,
    d								AS date,
    EXTRACT(DAY FROM d)::INT 		AS day,
    EXTRACT(MONTH FROM d)::INT 		AS month,
    EXTRACT(QUARTER FROM d)::INT 	AS quarter,
    EXTRACT(YEAR FROM d)::INT 		AS year,
    TO_CHAR(d, 'Day') 				AS day_of_week
FROM generate_series('2005-01-01'::DATE, '2006-12-31'::DATE, '1 day') AS d;

--Dim_Customer — денормализованное измерение клиента--
DROP VIEW IF EXISTS vw_dim_customer;
CREATE VIEW vw_dim_customer AS
SELECT
    c.customer_id 			AS customer_key,
    c.first_name 			AS first_name,
    c.last_name				AS last_name,
	c.email					AS email,
    ci.city					AS city,
    co.country				AS country
FROM customer AS c
JOIN address AS a ON c.address_id = a.address_id
JOIN city AS ci ON a.city_id = ci.city_id
JOIN country AS co ON ci.country_id = co.country_id;

--Dim_Film — денормализованное измерение фильма --
--у фильма в dvdrental может быть несколько категорий, упрощаем и берем первую по алфавиту --
DROP VIEW IF EXISTS vw_dim_film;
CREATE VIEW vw_dim_film AS
SELECT
    f.film_id 				AS film_key,
    f.title					AS title,
    (
		SELECT cat.name
     	FROM film_category fc
     	JOIN category cat ON fc.category_id = cat.category_id
     	WHERE fc.film_id = f.film_id
     	ORDER BY cat.name
     	LIMIT 1
	 ) 						AS category_name,
    f.rating				AS rating,
    f.rental_rate			AS rental_rate,
    f.length				AS length
FROM film AS f;

--Dim_Staff--
DROP VIEW IF EXISTS vw_dim_staff;
CREATE VIEW vw_dim_staff AS
SELECT
    s.staff_id								AS staff_key,
    s.first_name || ' ' || s.last_name		AS staff_name,
    'Store #' || s.store_id					AS store_name
FROM staff AS s;

-- Fact_Rental — таблица фактов --
DROP VIEW IF EXISTS vw_fact_rental;
CREATE VIEW vw_fact_rental AS
SELECT
    r.rental_id																AS rental_key,
    TO_CHAR(r.rental_date, 'YYYYMMDD')::INT									AS date_key,
	r.customer_id															AS customer_key,
    i.film_id																AS film_key,
    r.staff_id																AS staff_key,
    COALESCE(EXTRACT(DAY FROM (r.return_date - r.rental_date))::INT, 0)		AS rental_duration_days,
    COALESCE(p.amount, 0)													AS amount_paid
FROM rental AS r
JOIN inventory AS i ON r.inventory_id = i.inventory_id
LEFT JOIN payment AS p ON p.rental_id = r.rental_id;

-- Витрина данных: основные характеристики клиента --
DROP MATERIALIZED VIEW IF EXISTS mv_customer_summary;
CREATE MATERIALIZED VIEW mv_customer_summary AS
SELECT
    dc.customer_key,
    dc.first_name || ' ' || dc.last_name   AS customer_name,
    dc.email,
    dc.city,
    dc.country,
    -- Активность
    COUNT(fr.rental_key)                     AS total_rentals,
    MIN(dd.date)                             AS first_rental_date,
    MAX(dd.date)                             AS last_rental_date,
    CURRENT_DATE - MAX(dd.date)              AS days_since_last_rental,
    -- Финансовые метрики
    SUM(fr.amount_paid)                      AS total_spent,
    ROUND(AVG(fr.amount_paid), 2)            AS avg_check,
    -- Поведенческие метрики
    ROUND(AVG(fr.rental_duration_days), 1)   AS avg_rental_days,
    COUNT(DISTINCT df.category_name)         AS distinct_categories,
    MODE() WITHIN GROUP (ORDER BY df.category_name) AS favorite_category,
    -- Магазин, через который клиент чаще всего обслуживался
    MODE() WITHIN GROUP (ORDER BY ds.store_name)    AS most_frequent_store
FROM vw_dim_customer 		AS dc
LEFT JOIN vw_fact_rental 	AS fr ON fr.customer_key = dc.customer_key
LEFT JOIN vw_dim_film 		AS df ON df.film_key = fr.film_key
LEFT JOIN vw_dim_date 		AS dd ON dd.date_key = fr.date_key
LEFT JOIN vw_dim_staff 		AS ds ON ds.staff_key = fr.staff_key
GROUP BY
    dc.customer_key, 
	dc.first_name, 
	dc.last_name,
    dc.email, 
	dc.city, 
	dc.country
;

SELECT *
FROM mv_customer_summary