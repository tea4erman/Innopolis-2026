\set customer_id random(1, 100)
SELECT * 
FROM rental_loadtest 
WHERE customer_id = customer_id
AND rental_date >= '2026-05-01';