WITH rental_dates AS (
	SELECT 
		customer_id,
		DATE_TRUNC('month', rental_date)::DATE AS rental_month,
		MIN(DATE_TRUNC('month', rental_date)::DATE) OVER(PARTITION BY customer_id) AS first_month
	FROM rental
	ORDER BY customer_id, rental_date
)
SELECT 
	first_month,
	rental_month,
	COUNT(DISTINCT customer_id) AS cnt_customers
FROM rental_dates
GROUP BY 
	first_month,
	rental_month
ORDER BY 
	first_month,
	rental_month;

WITH rental_amount AS (
	SELECT 
		customer_id,
		DATE_TRUNC('month', rental_date)::DATE AS rental_month,
		COUNT(DISTINCT rental_id) AS cnt_rentals
	FROM rental
	GROUP BY
		customer_id,
		DATE_TRUNC('month', rental_date)::DATE
	ORDER BY customer_id, rental_month
), rental_amount_lag AS (
	SELECT 
		customer_id,
		rental_month,
		cnt_rentals,
		LAG(cnt_rentals, 1) OVER(PARTITION BY customer_id ORDER BY rental_month ASC) AS cnt_rentals_lag
	FROM rental_amount
	ORDER BY customer_id, rental_month
)
SELECT 
	customer_id,
	rental_month,
	cnt_rentals,
	cnt_rentals_lag,
	(cnt_rentals::FLOAT / cnt_rentals_lag::FLOAT) - 1 AS rentals_pct_change
FROM rental_amount_lag
ORDER BY customer_id, rental_month 