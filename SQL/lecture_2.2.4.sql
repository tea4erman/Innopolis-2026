SELECT 
	customer.customer_id,
	customer.first_name,
	customer.last_name,
	rental.rental_id,
	CAST(rental.rental_date AS DATE) AS rental_date,
	MIN(CAST(rental.rental_date AS DATE)) OVER(PARTITION BY customer.customer_id) AS first_rental_date,
	EXTRACT (EPOCH FROM rental.rental_date - MIN(rental.rental_date) OVER(PARTITION BY customer.customer_id )):: INT/86400 AS lifetime,
	film.rental_duration,
	film.rental_rate,
	EXTRACT (EPOCH FROM rental.return_date - rental.rental_date)::FLOAT/86400 AS fact_rental
FROM rental
LEFT JOIN customer
ON rental.customer_id = customer.customer_id
LEFT JOIN inventory
ON inventory.inventory_id = rental.inventory_id
LEFT JOIN film
ON inventory.film_id = film.film_id
ORDER BY customer.customer_id ASC, rental.rental_date ASC
;

WITH top_rent AS (	
	SELECT 		
		customer_id,		
		COUNT(rental_id) AS rentals_cnt
	FROM rental	
	GROUP BY customer_id	
	HAVING COUNT(rental_id) > 40 
), top_pay AS (
	SELECT
		customer_id,
		SUM(amount) AS payments_amt
	FROM payment
	GROUP BY customer_id
	HAVING SUM(amount) > 170
)
SELECT
	COALESCE(top_rent.customer_id, top_pay.customer_id) AS customer_id,
	COALESCE(top_rent.rentals_cnt, 0) AS rentals_cnt,
	top_pay.payments_amt
FROM top_rent
FULL JOIN top_pay
ON top_rent.customer_id = top_pay.customer_id