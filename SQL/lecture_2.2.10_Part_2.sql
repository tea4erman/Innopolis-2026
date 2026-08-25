-- ПРИМЕР 1: СКОЛЬКО ВСЕГО ПОТРАТИЛ КЛИЕНТ НА ПРОКАТЫ
CREATE OR REPLACE FUNCTION customer_total_spent(p_customer_id INT)
RETURNS NUMERIC AS $$
DECLARE
    v_total NUMERIC;
BEGIN
    SELECT COALESCE(SUM(amount), 0) INTO v_total
    FROM payment
    WHERE customer_id = p_customer_id;

    RETURN v_total;
END;
$$ LANGUAGE plpgsql;

-- Проверка работы функции
SELECT customer_total_spent(1);

SELECT 
	first_name,
	last_name,
	customer_total_spent(customer_id)
FROM customer
LIMIT 10;

-- ПРИМЕР 2: СПИСОК ФИЛЬМОВ, КОТОРЫЕ АРЕНДОВАЛ КЛИЕНТ
CREATE OR REPLACE FUNCTION customer_rental_history(p_customer_id INT)
RETURNS TABLE(film_title TEXT, rental_date DATE, returned BOOLEAN) AS $$
BEGIN
    RETURN QUERY
    SELECT f.title::TEXT,
           r.rental_date::DATE,
           r.return_date IS NOT NULL
	FROM rental			AS r
    JOIN inventory 		AS i ON i.inventory_id = r.inventory_id
    JOIN film 			AS f ON f.film_id = i.film_id
    WHERE r.customer_id = p_customer_id
    ORDER BY r.rental_date DESC;
END;
$$ LANGUAGE plpgsql;

-- Проверка работы функции
SELECT * FROM customer_rental_history(1);

-- ПРИМЕР 3: СКОЛЬКО ФИЛЬМОВ В КАЖДОЙ КАТЕГОРИИ
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN
        SELECT 
			c.name, 
			COUNT(*) AS film_count
        FROM category 		AS c
        JOIN film_category 	AS fc ON fc.category_id = c.category_id
        GROUP BY c.name
        ORDER BY film_count DESC
    LOOP
        RAISE NOTICE 'Категория: % — фильмов: %', rec.name, rec.film_count;
    END LOOP;
END $$;

-- ПРИМЕР 4: НАЙТИ ПЕРВЫХ 5 КЛИЕНТОВ С СУММОЙ ПЛАТЕЖЕЙ СВЫШЕ 100, ПЕРЕБИРАЯ КЛИЕНТОВ ПО ОДНОМУ
DO $$
DECLARE
    v_customer_id INT := 1;
    v_found_count INT := 0;
    v_total NUMERIC;
BEGIN
    LOOP
        SELECT COALESCE(SUM(amount), 0) INTO v_total
        FROM payment
        WHERE customer_id = v_customer_id;

        IF v_total > 150 THEN
            v_found_count := v_found_count + 1;
            RAISE NOTICE 'Клиент %: сумма %', v_customer_id, v_total;
        END IF;

        v_customer_id := v_customer_id + 1;

        EXIT WHEN v_found_count >= 5 OR v_customer_id > 599;
    END LOOP;
END $$;

-- ПРИМЕР 5: СМОДЕЛИРУЕМ ПОСТЕПЕННОЕ СПИСАНИЕ БЮДЖЕТА НА МАРКЕТИНГ
DO $$
DECLARE
    v_budget NUMERIC := 500;
    v_discount NUMERIC := 35;
    v_rounds INT := 0;
BEGIN
    WHILE v_budget > 0 LOOP
        v_budget := v_budget - v_discount;
        v_rounds := v_rounds + 1;
        RAISE NOTICE 'Раунд %, остаток бюджета: %', v_rounds, v_budget;
    END LOOP;

    RAISE NOTICE 'Бюджет исчерпан за % раундов', v_rounds;
END $$;

-- ПРИМЕР 6: ПЕРЕНЕСТИ ДАННЫЕ О НЕАКТИВНЫХ КЛИЕНТАХ В АРХИВ
CREATE TABLE IF NOT EXISTS customer_archive (LIKE customer INCLUDING ALL);

CREATE OR REPLACE PROCEDURE archive_inactive_customers()
LANGUAGE plpgsql
AS $$
DECLARE
    v_count INT := 0;
BEGIN
    INSERT INTO customer_archive
    SELECT c.* FROM customer AS c
    WHERE NOT EXISTS (
        SELECT 1 FROM rental AS r
        WHERE r.customer_id = c.customer_id
          AND r.rental_date > '2006-08-19'::DATE - INTERVAL '1 year'
    );

    GET DIAGNOSTICS v_count = ROW_COUNT;
    COMMIT;

    RAISE NOTICE 'Архивировано клиентов: %', v_count;
END;
$$;

-- Проверка работы процедуры
CALL archive_inactive_customers();

SELECT *
FROM customer_archive;

SELECT *
FROM customer
WHERE customer_id = 428;

-- ПРИМЕР 7: СРЕДНЯЯ ПРОДОЛЖИТЕЛЬНОСТЬ АРЕНДЫ ФИЛЬМА С УЧЕТОМ ВОЗМОЖНОГО ОТСУТСТВИЯ ФИЛЬМА
DO $$
DECLARE
    v_film_id INT := 999; -- заведомо несуществующий ID
    v_duration INT;
BEGIN
    BEGIN
        SELECT rental_duration INTO STRICT v_duration
        FROM film
        WHERE film_id = v_film_id;

        RAISE NOTICE 'Длительность аренды: % дней', v_duration;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RAISE NOTICE 'Фильм с ID % не найден', v_film_id;
        WHEN TOO_MANY_ROWS THEN
            RAISE NOTICE 'Найдено больше одной записи — ошибка данных';
    END;
END $$;

-- ПРИМЕР 8: ПРЕДУПРЕДИТЬ О КЛИЕНТАХ, ЧЕЙ EMAIL НЕ ОТВЕЧАЕТ ПРОВЕРКЕ ФОРМАТА
DO $$
DECLARE
    rec RECORD;
BEGIN
    FOR rec IN SELECT customer_id, email FROM customer LOOP
        IF rec.email NOT LIKE '%@%.org' THEN
            RAISE WARNING 'Подозрительный email у клиента %: %', rec.customer_id, rec.email;
        END IF;
    END LOOP;

    RAISE NOTICE 'Проверка завершена';
END $$;