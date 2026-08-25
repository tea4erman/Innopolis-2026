--==НАГРУЗОЧНОЕ ТЕСТИРОВАНИЕ==--
--1) Берем подготовленные сгенерированные БД по STI;
SELECT *
FROM sales_events_sti
WHERE customer_id = 5
AND event_type = 'merchandise'
LIMIT 5;

--2) В дереве объектов слева выбрать сервер
--Перейти на вкладку Dashboard
--Sessions — количество активных подключений
--Transactions per second (TPS) - количество операций в секунду
--Tuples in / Tuples out - сколько строк читается/записывается в секунду
--Block I/O - обращения к диску

--3) Создаем тестовый SQL сценарий и сохраняем его в отдельном файле query_test.sql
\set v_customer_id random(1, 599)
SELECT * FROM sales_events_sti
WHERE customer_id = :v_customer_id AND event_type = 'merchandise';

--4) Запускаем pgbench из терминала
--Копируем и запускаем команду pgbench -c 50 -j 4 -T 60 -f query_test.sql -d dvdrental

--5) Наблюдаем за нагрузкой в pgAdmin4 во время теста
-- Dashboard → Sessions — должно появиться ~50 активных подключений
-- Dashboard → Server Activity (вкладка ниже) — список активных запросов с полем state = active