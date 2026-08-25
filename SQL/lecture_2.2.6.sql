DROP TABLE IF EXISTS rental_loadtest;

CREATE TABLE rental_loadtest (
	rental_id SERIAL PRIMARY KEY,
    rental_date TIMESTAMP,
	inventory_id INT,
	customer_id INT,
	return_date TIMESTAMP,
    staff_id INT,
    last_update TIMESTAMP
);

INSERT INTO rental_loadtest (rental_date, inventory_id, customer_id, return_date, staff_id, last_update)
SELECT 
	now() - (random() * interval '365 days'),
	(random() * 1000)::int,
	(random() * 100)::int,
    now() - (random() * interval '200 days'),
	(random() * 10)::int,
    now()
FROM generate_series(1, 15000000);