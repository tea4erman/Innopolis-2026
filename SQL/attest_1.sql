WITH overdue_rentals AS (
	SELECT 
		rental.rental_id,
		rental.inventory_id,
		rental.customer_id,
		rental.staff_id,
		film.film_id,
		film.rental_rate,
		film.length, 
		film.replacement_cost,
		film.rating, 
		category.name AS film_category,
		EXTRACT (EPOCH FROM rental.return_date - rental.rental_date)::FLOAT/86400 AS fact_rental,
		film.rental_duration AS normative_rental,
		CASE WHEN EXTRACT (EPOCH FROM rental.return_date - rental.rental_date)::FLOAT/86400 > film.rental_duration THEN 1 ELSE 0 END AS is_overdue
	FROM rental
	LEFT JOIN inventory 
	ON rental.inventory_id = inventory.inventory_id
	LEFT JOIN film 
	ON inventory.film_id = film.film_id
	LEFT JOIN film_category 
	ON film.film_id = film_category.film_id
	LEFT JOIN category
	ON film_category.category_id = category.category_id
	WHERE return_date IS NOT NULL
)
SELECT *
FROM overdue_rentals

-- , cust_agg AS (
-- 	SELECT 
-- 		customer_id,
-- 		COUNT(rental_id) AS cnt_rental,
-- 		AVG(is_overdue) AS overdue_pct
-- 	FROM overdue_rentals
-- 	GROUP BY customer_id
-- 	ORDER BY overdue_pct ASC
-- ), film_agg AS (
-- 	SELECT 
-- 		film_id,
-- 		COUNT(rental_id) AS cnt_rental,
-- 		AVG(is_overdue) AS overdue_pct
-- 	FROM overdue_rentals
-- 	GROUP BY film_id
-- 	ORDER BY overdue_pct DESC
-- )
-- SELECT 
-- 	film_category,
-- 	COUNT(rental_id) AS cnt_rental,
-- 	AVG(is_overdue) AS overdue_pct
-- FROM overdue_rentals
-- GROUP BY film_category
-- ORDER BY overdue_pct DESC
-- ;

-- SELECT *
-- FROM category
-- LIMIT 10
