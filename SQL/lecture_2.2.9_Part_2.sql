-- ПРИМЕР 1: ТРИГГЕР ВАЛИДАЦИИ EMAIL ЧЕРЕЗ РЕГУЛЯРНОЕ ВЫРАЖЕНИЕ--
-- Запретить сохранение клиента (customer) с некорректным форматом email до того, как запись попадет в таблицу

-- Удалить, если уже существует
-- DROP FUNCTION IF EXISTS validate_customer_email;

CREATE OR REPLACE FUNCTION validate_customer_email()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.email !~* '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$' THEN
        RAISE EXCEPTION 'Некорректный формат email: %', NEW.email;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Удалить, если уже существует
-- DROP TRIGGER IF EXISTS trg_customer_validate_email ON customer;

CREATE TRIGGER trg_customer_validate_email
BEFORE INSERT OR UPDATE OF email ON customer
FOR EACH ROW
EXECUTE FUNCTION validate_customer_email();

-- Проверка работы триггера
-- Некорректный email — сработает RAISE EXCEPTION, транзакция отменится
INSERT INTO customer (store_id, first_name, last_name, email, address_id)
VALUES (1, 'Петр', 'Николаев', 'petr-at-mail', 5);

-- Корректный email — вставка проходит успешно
INSERT INTO customer (store_id, first_name, last_name, email, address_id)
VALUES (1, 'Петр', 'Николаев', 'petr.nikolaev@example.com', 5);

SELECT *
FROM customer
ORDER BY customer_id DESC;

-- Попытка испортить email существующему клиенту
UPDATE customer SET email = 'broken-email' WHERE customer_id = 1;

-- ПРИМЕР 2: АВТОМАТИЧЕСКОЕ ОБНОВЛЕНИЕ LAST UPDATE
-- Почти у каждой таблицы есть поле last_update
-- Нужно, чтобы оно всегда автоматически проставлялось в текущее время при любом изменении строки

-- Удалить, если уже существует
-- DROP FUNCTION set_last_update;

CREATE OR REPLACE FUNCTION set_last_update()
RETURNS TRIGGER AS $$
BEGIN
    NEW.last_update := NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Удалить, если уже существует
-- DROP TRIGGER IF EXISTS trg_customer_last_update ON customer;

CREATE TRIGGER trg_customer_last_update
BEFORE UPDATE ON customer
FOR EACH ROW
EXECUTE FUNCTION set_last_update();

-- Проверка работы триггера
UPDATE customer SET email = 'petr.nikolaev@example.ru' WHERE customer_id = 609;

-- ПРИМЕР 3: ЗАПРЕТ ПРОКАТА ПРИ ОТСУТСТВИИ СВОБОДНЫХ КОПИЙ ФИЛЬМА
-- Одна и та же копия фильма (inventory_id) не может быть выдана в прокат дважды одновременно
-- Запретить INSERT в rental, если выбранная копия уже находится на руках у другого клиента
-- Есть незакрытая запись rental с тем же inventory_id

-- Удалить, если уже существует
-- DROP FUNCTION IF EXISTS prevent_double_rental;

CREATE OR REPLACE FUNCTION prevent_double_rental()
RETURNS TRIGGER AS $$
DECLARE
    v_already_rented BOOLEAN;
BEGIN
    SELECT EXISTS (
        SELECT 1 FROM rental
        WHERE inventory_id = NEW.inventory_id
          AND return_date IS NULL
    ) INTO v_already_rented;

    IF v_already_rented THEN
        RAISE EXCEPTION 'Копия фильма (inventory_id = %) уже выдана и не возвращена',
            NEW.inventory_id;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Удалить, если уже существует
-- DROP TRIGGER IF EXISTS trg_rental_prevent_double_booking ON rental;
CREATE TRIGGER trg_rental_prevent_double_booking
BEFORE INSERT ON rental
FOR EACH ROW
EXECUTE FUNCTION prevent_double_rental();

-- Проверка работы триггера
-- inventory_id = 2047 уже выдан в исходных данных dvdrental и не возвращен
INSERT INTO rental (rental_date, inventory_id, customer_id, staff_id) VALUES (NOW(), 2047, 5, 1);

-- ПРИМЕР 4: ЗАПРЕТ ИЗМЕНЕНИЯ rental_rate ФИЛЬМА НИЖЕ replacement_cost
-- Запретить изменение rental_rate фильма ниже 10% от восстановительной стоимости 

SELECT *
FROM film
ORDER BY film_id DESC
LIMIT 10;

-- Удалить, если уже существует
-- DROP FUNCTION IF EXISTS validate_film_rental_rate;
CREATE OR REPLACE FUNCTION validate_film_rental_rate()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.rental_rate < NEW.replacement_cost * 0.1 THEN
        RAISE EXCEPTION 
            'Цена проката % слишком мала при стоимости замены % (минимум %)',
            NEW.rental_rate, NEW.replacement_cost, 
            ROUND(NEW.replacement_cost * 0.1, 2);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Удалить, если уже существует
-- DROP TRIGGER IF EXISTS trg_film_validate_rental_rate ON film;
CREATE TRIGGER trg_film_validate_rental_rate
BEFORE INSERT OR UPDATE OF rental_rate, replacement_cost ON film
FOR EACH ROW
EXECUTE FUNCTION validate_film_rental_rate();

-- Пробуем внести запись о фильме с указанием некорректного rental_rate
INSERT INTO film (title, description, release_year, language_id, rental_rate, replacement_cost) VALUES ('new_film', 'description of the new film', 2026, 1, 0.99, 20);

-- Пробуем внести корректную запись
INSERT INTO film (title, description, release_year, language_id, rental_rate, replacement_cost) VALUES ('new_film', 'description of the new film', 2026, 1, 2.99, 20);

-- DELETE FROM film WHERE film_id = 1002
