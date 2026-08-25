\set v_customer_id random(1, 599)
SELECT * FROM sales_events_sti
WHERE customer_id = :v_customer_id AND event_type = 'merchandise';