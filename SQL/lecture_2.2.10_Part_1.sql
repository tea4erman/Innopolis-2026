-- Подсчет клиентов--
DO $$
DECLARE
    v_customer_count INT;
BEGIN
    SELECT COUNT(*) INTO v_customer_count FROM customer;
    RAISE NOTICE 'Клиентов: %', v_customer_count;
END $$;

SELECT * FROM payment LIMIT 5;

--Подсчет среднего чека на клиента на определенную дату--
DO $$
DECLARE
    v_customer_count 	INT		:=0;
	v_payments_amt   	NUMERIC :=0;
	v_avg_payment		NUMERIC;
BEGIN
    SELECT COUNT(*) INTO v_customer_count FROM payment WHERE payment_date::DATE = '2007-02-15';
	SELECT SUM(amount) INTO v_payments_amt FROM payment WHERE payment_date::DATE = '2007-02-15';
    v_avg_payment := v_payments_amt / v_customer_count;
	RAISE NOTICE 'Средний чек: %', v_avg_payment;
	EXCEPTION
		WHEN SQLSTATE '22012' THEN
			RAISE NOTICE 'Нет клиентов, нельзя делить на ноль';
END $$;

-- Функция, возврашающая скаляр--
CREATE OR REPLACE FUNCTION customer_tenure_days(p_customer_id INT)
RETURNS INT AS $$
DECLARE
    v_create_date DATE;
BEGIN
    SELECT create_date INTO v_create_date
    FROM customer WHERE customer_id = p_customer_id;
    RETURN CURRENT_DATE - v_create_date;
END;
$$ LANGUAGE plpgsql;

SELECT customer_tenure_days(999);

--Добавим проверку ошибок--
CREATE OR REPLACE FUNCTION customer_tenure_days(p_customer_id INT)
RETURNS INT AS $$
DECLARE
    v_create_date DATE;
BEGIN
    SELECT create_date INTO v_create_date
    FROM customer WHERE customer_id = p_customer_id;
	IF v_create_date IS NULL THEN 
		RAISE EXCEPTION 'Такого пользователя нет в базе данных';
	ELSE
    	RETURN CURRENT_DATE - v_create_date;
	END IF;
END;
$$ LANGUAGE plpgsql;

--Функция с условной логикой--
CREATE OR REPLACE FUNCTION customer_segment(p_customer_id INT)
RETURNS TEXT AS $$
DECLARE
    v_rental_count INT;
BEGIN
    SELECT COUNT(*) INTO v_rental_count
    FROM rental WHERE customer_id = p_customer_id;
    IF v_rental_count > 30 THEN
        RETURN 'VIP';
    ELSIF v_rental_count > 10 THEN
        RETURN 'Активный';
    ELSE
        RETURN 'Обычный';
    END IF;
END;
$$ LANGUAGE plpgsql;

SELECT customer_segment(100);

--Используем функцию внутри запроса--
SELECT 
	customer_id, 
	first_name,
	customer_segment(customer_id) AS segment
FROM customer
LIMIT 20;

--Альтернатива--
WITH cust_rentals AS (
	SELECT
		customer_id,
		COUNT(*) AS rental_count
    FROM rental 
	GROUP BY customer_id
),
cust_segment AS (
	SELECT 
		customer_id,
		CASE WHEN rental_count > 30 THEN 'VIP'
	    WHEN rental_count <=30 AND rental_count > 10 THEN 'Активный'
	    ELSE 'Обычный' END AS customer_segment
	FROM cust_rentals
)
SELECT 
	t1.customer_id,
	t1.first_name,
	t2.customer_segment
FROM customer 		AS t1
JOIN cust_segment 	AS t2
ON t1.customer_id = t2.customer_id;
	
-- Цикл FOR--
DO $$
DECLARE
    rec RECORD;
    v_total NUMERIC := 0;
BEGIN
    FOR rec IN SELECT amount FROM payment WHERE customer_id = 1 LOOP
        v_total := v_total + rec.amount;
    END LOOP;
    RAISE NOTICE 'Итого: %', v_total;
END $$;

--Цикл для определенного количества шагов (5 раз)--
DO $$
BEGIN
	FOR i IN 1..5 LOOP
	    RAISE NOTICE 'i: %', i;
	END LOOP;
END $$;

--Функция, возвращающая таблицу--
CREATE OR REPLACE FUNCTION top_films_by_category(p_category VARCHAR(255), p_limit INT)
RETURNS TABLE(film_title VARCHAR(255), rental_count BIGINT) AS $$
BEGIN
    RETURN QUERY
    SELECT f.title, COUNT(*) 
    FROM film f
    JOIN inventory i ON i.film_id = f.film_id
    JOIN rental r ON r.inventory_id = i.inventory_id
    JOIN film_category fc ON fc.film_id = f.film_id
    JOIN category c ON c.category_id = fc.category_id
    WHERE c.name = p_category
    GROUP BY f.title
    ORDER BY COUNT(*) DESC
    LIMIT p_limit;
END;
$$ LANGUAGE plpgsql;

SELECT * FROM top_films_by_category('Action', 5);

--Обработка ошибок--
CREATE OR REPLACE FUNCTION safe_average_rating(p_film_id INT)
RETURNS NUMERIC AS $$
DECLARE
    v_avg NUMERIC;
BEGIN
    SELECT AVG(replacement_cost) INTO v_avg
    FROM film WHERE film_id = p_film_id;

    IF v_avg IS NULL THEN
        RAISE EXCEPTION 'Фильм с ID % не найден', p_film_id;
    END IF;
    RETURN v_avg;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'Ошибка при вычислении: %', SQLERRM;
        RETURN NULL;
END;
$$ LANGUAGE plpgsql;

SELECT safe_average_rating('123');

--Процедура начисления штрафов за просроченные возвраты--
CREATE OR REPLACE PROCEDURE apply_late_fees(p_fee_amount NUMERIC DEFAULT 5.00)
LANGUAGE plpgsql
AS $$
DECLARE
    rec RECORD;
    v_processed INT := 0;
BEGIN
    FOR rec IN
        SELECT 
			r.rental_id, 
			r.customer_id, 
			i.film_id, 
			f.rental_duration
        FROM rental 	AS r
        JOIN inventory 	AS i ON i.inventory_id = r.inventory_id
        JOIN film 		AS f ON f.film_id = i.film_id
        WHERE r.return_date IS NULL
          AND r.rental_date + (f.rental_duration || ' days')::INTERVAL < '2006-03-01'
    LOOP
        -- Начисляем штраф как отдельный платёж
        INSERT INTO payment (customer_id, staff_id, rental_id, amount, payment_date)
        VALUES (rec.customer_id, 1, rec.rental_id, p_fee_amount, NOW());

        v_processed := v_processed + 1;

        -- Фиксируем каждые 50 обработанных записей
        IF v_processed % 50 = 0 THEN
            COMMIT;
            RAISE NOTICE 'Зафиксировано % штрафов', v_processed;
        END IF;
    END LOOP;

    COMMIT;
    RAISE NOTICE 'Готово. Всего начислено штрафов: %', v_processed;
END;
$$;

--Вызываем процедуру--
CALL apply_late_fees(3.00);

--Смотрим на начисленные штрафы--
SELECT *
FROM payment
WHERE payment_date >= '2026-07-01';

--Удалим созданные для демонстрации строки--
DELETE FROM payment WHERE payment_date > '2026-07-01';