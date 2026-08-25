-- ПРИМЕР 1: Активные (незавершенные) прокаты -- 
DROP VIEW IF EXISTS vw_active_rentals;
CREATE VIEW vw_active_rentals AS
SELECT
    r.rental_id,
    c.first_name || ' ' || c.last_name AS customer_name,
	c.email,
    f.title AS film_title,
    r.rental_date,
    s.first_name || ' ' || s.last_name AS staff_name
FROM rental 	AS r
JOIN customer 	AS c ON c.customer_id = r.customer_id
JOIN inventory 	AS i ON i.inventory_id = r.inventory_id
JOIN film 		AS f ON f.film_id = i.film_id
JOIN staff 		AS s ON s.staff_id = r.staff_id
WHERE r.return_date IS NULL;

-- Проверяем
SELECT *
FROM vw_active_rentals
LIMIT 10;

-- ПРИМЕР 2: Ежедневные показатели проката --
DROP MATERIALIZED VIEW IF EXISTS mv_daily_rental_metrics;
CREATE VIEW mv_daily_rental_metrics AS
SELECT
    DATE(r.rental_date) 				AS report_date,
    cat.name 							AS category_name,
    s.first_name || ' ' || s.last_name 	AS staff_name,
    COUNT(*) 							AS rentals_count,
    SUM(p.amount) 						AS total_revenue,
    AVG(EXTRACT(EPOCH FROM (r.return_date - r.rental_date))/86400) AS avg_rental_days
FROM rental 			AS r
JOIN inventory 			AS i   ON i.inventory_id = r.inventory_id
JOIN film_category 		AS fc  ON fc.film_id = i.film_id
JOIN category 			AS cat ON cat.category_id = fc.category_id
JOIN staff 				AS s   ON s.staff_id = r.staff_id
LEFT JOIN payment 		AS p   ON p.rental_id = r.rental_id
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- Проверяем
SELECT *
FROM mv_daily_rental_metrics
WHERE total_revenue IS NOT NULL
ORDER BY report_date ASC
LIMIT 10;

-- ПРИМЕР 3: Рейтинг сотрудников -- 
DROP VIEW IF EXISTS vw_staff_ranking;
CREATE VIEW vw_staff_ranking AS
SELECT
    s.staff_id,
    s.first_name || ' ' || s.last_name 				AS staff_name,
    COUNT(r.rental_id) 								AS processed_rentals,
    RANK() OVER (ORDER BY COUNT(r.rental_id) DESC) 	AS rank_position
FROM staff 			AS s
LEFT JOIN rental 	AS r ON r.staff_id = s.staff_id
GROUP BY s.staff_id, s.first_name, s.last_name;

-- Проверяем
SELECT *
FROM vw_staff_ranking;

-- ПРИМЕР 4: Просроченные возвраты -- 
DROP VIEW IF EXISTS vw_overdue_rentals;
CREATE VIEW vw_overdue_rentals AS
SELECT
    r.rental_id,
    c.first_name || ' ' || c.last_name AS customer_name,
    f.title AS film_title,
    r.rental_date,
    f.rental_duration,
    CURRENT_DATE - r.rental_date::date AS days_out
FROM rental 	AS r
JOIN customer 	AS c ON c.customer_id = r.customer_id
JOIN inventory 	AS i ON i.inventory_id = r.inventory_id
JOIN film 		AS f ON f.film_id = i.film_id
WHERE r.return_date IS NULL
AND r.rental_date >= '2005-08-20' -- можно поставить NOW() - INTERVAL '30 days'
--AND (CURRENT_DATE - r.rental_date::date) > f.rental_duration
AND ('2005-09-20'::DATE - r.rental_date::DATE) > f.rental_duration
;

-- Проверяем
SELECT *
FROM vw_overdue_rentals;

