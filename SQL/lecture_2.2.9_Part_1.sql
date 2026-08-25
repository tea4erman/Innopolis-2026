--==ОГРАНИЧЕНИЯ==--
--NOT NULL
--В таблице customer поле email обязано быть заполнено
ALTER TABLE customer ALTER COLUMN email SET NOT NULL;

INSERT INTO customer (store_id, first_name, last_name, address_id)
VALUES (1, 'Анна', 'Петрова', 5);

SELLE

--DEFAULT
--Если значение не указано явно, подставляется заданное по умолчанию:
ALTER TABLE customer ALTER COLUMN active SET DEFAULT true;

--UNIQUE
--Email клиента не должен повторяться--
ALTER TABLE customer ADD CONSTRAINT customer_email_unique UNIQUE (email);

INSERT INTO customer (store_id, first_name, last_name, email, address_id)
VALUES (1, 'Иван', 'Сидоров', 'mary.smith@sakilacustomer.org', 5);

--CHECK
--Сумма платежа должна быть положительной--
ALTER TABLE payment ADD CONSTRAINT payment_amount_positive CHECK (amount > 0);

INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
VALUES (1, 1, 5, -4.99, NOW());


--==ФУНКЦИИ==--
CREATE FUNCTION customer_full_name(p_customer_id INT)
RETURNS TEXT AS $$
DECLARE
   v_name TEXT;
BEGIN
   SELECT first_name || ' ' || last_name INTO v_name
   FROM customer WHERE customer_id = p_customer_id;
   RETURN v_name;
END;
$$ LANGUAGE plpgsql;

SELECT customer_full_name(1);

--==VIEWS==--
--Агрегаты по клиенту--
--CREATE VIEW customer_activity_view AS
SELECT
    c.customer_id,
    c.first_name || ' ' || c.last_name 		AS customer_name,
    COUNT(r.rental_id)                		AS total_rentals,
    COALESCE(SUM(p.amount), 0)        		AS total_paid,
    MAX(r.rental_date)                		AS last_rental_date
FROM customer 		AS c
LEFT JOIN rental 	AS r ON r.customer_id = c.customer_id
LEFT JOIN payment 	AS p ON p.customer_id = c.customer_id
GROUP BY c.customer_id;

--Агрегаты по категориям фильмов--
--CREATE MATERIALIZED VIEW mv_category_revenue AS
SELECT
    cat.name             	 AS category_name,
    COUNT(r.rental_id)   	 AS total_rentals,
    SUM(p.amount)         	 AS total_revenue
FROM category cat
JOIN film_category 		AS fc 	ON fc.category_id = cat.category_id
JOIN inventory 			AS i 	ON i.film_id = fc.film_id
JOIN rental 			AS r	ON r.inventory_id = i.inventory_id
JOIN payment 			AS p	ON p.rental_id = r.rental_id
GROUP BY cat.name;

--Замечание 1: MATERIALIZED VIEW устаревает
SELECT SUM(total_revenue) FROM mv_category_revenue;

INSERT INTO payment(customer_id, staff_id, rental_id, amount, payment_date)
VALUES (1, 1, 5, 4.99, NOW());

SELECT SUM(total_revenue) FROM mv_category_revenue;

--Замечание 2: VIEW нельзя обновить напрямую
UPDATE customer_activity_view
SET customer_name = 'Иван Иванов'
WHERE customer_id = 1;

--==ТРИГГЕРЫ==--
--Триггер для обновления MATERIALIZED VIEW--
CREATE FUNCTION refresh_category_revenue()
RETURNS TRIGGER AS $$
BEGIN
   REFRESH MATERIALIZED VIEW mv_category_revenue;
   RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_refresh_revenue
AFTER INSERT ON payment
FOR EACH STATEMENT
EXECUTE FUNCTION refresh_category_revenue();

--Триггер для обновления VIEW--
CREATE FUNCTION update_customer_via_view()
RETURNS TRIGGER AS $$
BEGIN
   UPDATE customer
   SET first_name = split_part(NEW.customer_name, ' ', 1),
       last_name  = split_part(NEW.customer_name, ' ', 2)
   WHERE customer_id = OLD.customer_id;
   RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_update_customer_activity
INSTEAD OF UPDATE ON customer_activity_view
FOR EACH ROW
EXECUTE FUNCTION update_customer_via_view();

--Уведомление о большом платеже--
CREATE TABLE payment_notifications (
    notification_id SERIAL PRIMARY KEY,
    payment_id       INT,
    customer_id      INT,
    amount           NUMERIC,
    message          TEXT,
    created_at        TIMESTAMP DEFAULT NOW()
);

CREATE OR REPLACE FUNCTION notify_large_payment()
RETURNS TRIGGER AS $$
DECLARE
    v_customer_name TEXT;
    v_message       TEXT;
BEGIN
    -- находим имя клиента, совершившего крупный платёж
    SELECT first_name || ' ' || last_name INTO v_customer_name
    FROM customer
    WHERE customer_id = NEW.customer_id;

    v_message := 'Крупный платёж: ' || v_customer_name ||
                 ' оплатил ' || NEW.amount || ' $';

    -- сохраняем уведомление в таблицу
    INSERT INTO payment_notifications(payment_id, customer_id, amount, message)
    VALUES (NEW.payment_id, NEW.customer_id, NEW.amount, v_message);

    -- дополнительно отправляем асинхронный сигнал через pg_notify
    PERFORM pg_notify('large_payment_channel', v_message);

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_payment_large_amount_notify
AFTER INSERT
ON payment
FOR EACH ROW
WHEN (NEW.amount > 100)
EXECUTE FUNCTION notify_large_payment();

--Обычный платеж--
INSERT INTO payment(customer_id, staff_id, rental_id, amount, payment_date)
VALUES (1, 1, 5, 4.99, NOW());

--Крупный платеж--
INSERT INTO payment(customer_id, staff_id, rental_id, amount, payment_date)
VALUES (1, 1, 5, 150.00, NOW());

SELECT * FROM payment_notifications;

