/* -----------------------------------------------------------
   ШАГ 1. СОЗДАНИЕ БАЗОВЫХ ТАБЛИЦ
  
   customer, product (сырая), orders, order_items
----------------------------------------------------------- */

CREATE TABLE IF NOT EXISTS orders (
    order_id      INTEGER PRIMARY KEY,  -- ID транзакции
    customer_id   INTEGER,              -- ID клиента
    order_date    DATE,                 -- Дата транзакции
    online_order  BOOLEAN,              -- Индикатор онлайн-заказа
    order_status  VARCHAR(10) NOT NULL  -- Статус: Approved / Cancelled
);

CREATE TABLE IF NOT EXISTS product (
    product_id     INTEGER PRIMARY KEY,     -- ID продукта
    brand          VARCHAR(30),             -- Бренд
    product_line   VARCHAR(20),             -- Линейка продуктов
    product_class  VARCHAR(6),              -- Класс продукта
    product_size   VARCHAR(6),              -- Размер продукта
    list_price     NUMERIC(10,2) NOT NULL,  -- Цена
    standard_cost  NUMERIC(10,2)            -- Стандартная стоимость
);

CREATE TABLE IF NOT EXISTS order_items (
    order_item_id              INTEGER,          -- ID позиции в заказе
    order_id                   INTEGER NOT NULL  REFERENCES orders(order_id),
    product_id                 INTEGER NOT NULL  REFERENCES product(product_id),
    quantity                   INTEGER NOT NULL, -- Количество продукта в заказе
    item_list_price_at_sale    NUMERIC(10,2) NOT NULL, -- Цена продукта в момент продажи
    item_standard_cost_at_sale NUMERIC(10,2)           -- Ст-ть продукта в момент продажи
);

CREATE TABLE IF NOT EXISTS customer (
    customer_id          INTEGER PRIMARY KEY, -- ID клиента
    first_name           VARCHAR(30),         -- Имя
    last_name            VARCHAR(30),         -- Фамилия
    gender               VARCHAR(10),         -- Пол
    DOB                  DATE,                -- Дата рождения
    job_title            TEXT,                -- Профессия
    job_industry_category TEXT,              -- Сфера деятельности
    wealth_segment       VARCHAR(20),         -- Сегмент благосостояния
    deceased_indicator   VARCHAR(1) NOT NULL, -- Индикатор актуального клиента
    owns_car             VARCHAR(3) NOT NULL, -- Наличие автомобиля
    address              TEXT NOT NULL,       -- Адрес проживания
    postcode             INTEGER NOT NULL,    -- Почтовый индекс
    state                VARCHAR(30) NOT NULL,-- Штат
    country              VARCHAR(20) NOT NULL,-- Страна
    property_valuation   INTEGER NOT NULL     -- Оценка имущества
);


/* -----------------------------------------------------------
   ШАГ 1.1. УДАЛЕНИЕ ОГРАНИЧЕНИЙ, МЕШАЮЩИХ ДЕДУБЛИКАЦИИ PRODUCT
   В исходных данных product есть дубликаты product_id,
   поэтому FK и PK временно снимаем.
----------------------------------------------------------- */

ALTER TABLE order_items
    DROP CONSTRAINT IF EXISTS order_items_product_id_fkey;

ALTER TABLE product
    DROP CONSTRAINT IF EXISTS product_pkey;


/* -----------------------------------------------------------
   ШАГ 1.2. ДЕДУБЛИКАЦИЯ ТАБЛИЦЫ PRODUCT
   Создаём таблицу products на основе product:
   для каждого product_id оставляем одну строку с максимальной list_price.
   product остаётся как "сырая" таблица для истории.
----------------------------------------------------------- */

CREATE TABLE products AS
SELECT *
FROM (
    SELECT
        p.*,
        ROW_NUMBER() OVER (
            PARTITION BY product_id
            ORDER BY list_price DESC
        ) AS rn
    FROM product p
) t
WHERE rn = 1;

-- Техническая колонка rn больше не нужна в итоговой таблице
ALTER TABLE products DROP COLUMN rn;


/* -----------------------------------------------------------
   ШАГ 1.3. ПРОВЕРКИ КАЧЕСТВА ДАННЫХ
   1) проверка уникальности ключей и наличия NULL
   2) проверка составного ключа (order_id, product_id)
   3) поиск "висячих" ссылок
   Эти SELECT'ы служат для диагностики, их результаты приложены скриншотами.
----------------------------------------------------------- */

-- 1.1. Уникальность order_id в orders
SELECT COUNT(*) AS rows_all,
       COUNT(DISTINCT order_id) AS rows_distinct
FROM orders;

-- 1.2. Отсутствие NULL в order_id
SELECT COUNT(*) AS null_order_id
FROM orders
WHERE order_id IS NULL;

-- 1.3. Уникальность customer_id в customer
SELECT COUNT(*) AS rows_all,
       COUNT(DISTINCT customer_id) AS rows_distinct
FROM customer;

-- 1.4. Отсутствие NULL в customer_id
SELECT COUNT(*) AS null_customer_id
FROM customer
WHERE customer_id IS NULL;

-- 1.5. Уникальность product_id в products (уже после дедупликации)
SELECT COUNT(*) AS rows_all,
       COUNT(DISTINCT product_id) AS rows_distinct
FROM products;

-- 1.6. Отсутствие NULL в product_id
SELECT COUNT(*) AS null_product_id
FROM products
WHERE product_id IS NULL;

-- 2.1. Уникальность order_item_id в order_items
SELECT COUNT(*) AS rows_all,
       COUNT(DISTINCT order_item_id) AS rows_distinct
FROM order_items;

-- 2.2. Отсутствие NULL в order_item_id
SELECT COUNT(*) AS null_order_item_id
FROM order_items
WHERE order_item_id IS NULL;

-- 2.3. Уникальность order_id в order_items
SELECT COUNT(*) AS rows_all,
       COUNT(DISTINCT order_id) AS rows_distinct
FROM order_items;

-- 2.4. Отсутствие NULL в order_id в order_items
SELECT COUNT(*) AS null_order_id
FROM order_items
WHERE order_id IS NULL;

-- 2.5. Уникальность product_id в order_items
SELECT COUNT(*) AS rows_all,
       COUNT(DISTINCT product_id) AS rows_distinct
FROM order_items;

-- 2.6. Отсутствие NULL в product_id
SELECT COUNT(*) AS null_product_id
FROM order_items
WHERE product_id IS NULL;

-- 2.7. Уникальна ли пара (order_id, product_id) в order_items
SELECT COUNT(*) AS rows_all,
       COUNT(DISTINCT (order_id, product_id)) AS rows_distinct
FROM order_items;


-- 3.1. Висячие ссылки order_items → orders
SELECT COUNT(*) AS orphan_order_items_orders
FROM order_items oi
LEFT JOIN orders o ON oi.order_id = o.order_id
WHERE o.order_id IS NULL;

-- 3.2. Висячие ссылки order_items → products
SELECT COUNT(*) AS orphan_order_items_products
FROM order_items oi
LEFT JOIN products p ON oi.product_id = p.product_id
WHERE p.product_id IS NULL;

-- 3.3. Висячие ссылки orders → customer
SELECT COUNT(*) AS missing_customers
FROM orders o
LEFT JOIN customer c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Детальный вывод заказов без клиентов
SELECT 
    o.order_id,
    o.customer_id,
    o.order_date,
    o.order_status
FROM orders o
LEFT JOIN customer c ON o.customer_id = c.customer_id
WHERE c.customer_id IS NULL;

-- Количество позиций в проблемных заказах
SELECT 
    oi.order_id,
    COUNT(*) AS items_count
FROM order_items oi
WHERE oi.order_id IN (
    SELECT o.order_id
    FROM orders o
    LEFT JOIN customer c ON o.customer_id = c.customer_id
    WHERE c.customer_id IS NULL
)
GROUP BY oi.order_id;


/* -----------------------------------------------------------
   ШАГ 1.4. УДАЛЕНИЕ ПРОБЛЕМНЫХ ЗАКАЗОВ
   В ходе проверки обнаружено, что в customer отсутствует клиент 5034,
   а в orders есть 3 заказа с этим customer_id.
   Сначала удаляем строки из order_items, потом сами заказы.
----------------------------------------------------------- */

DELETE FROM order_items
WHERE order_id IN (8708, 16701, 17469);

DELETE FROM orders
WHERE order_id IN (8708, 16701, 17469);


/* -----------------------------------------------------------
   ШАГ 1.5. ФИНАЛЬНАЯ УСТАНОВКА PK/FK
   Восстанавливаем ключи и связи.
----------------------------------------------------------- */

-- Первичный ключ для products
ALTER TABLE products
    ADD PRIMARY KEY (product_id);

-- Первичный ключ для order_items
ALTER TABLE order_items
    ADD PRIMARY KEY (order_item_id);

-- Внешний ключ orders → customer
ALTER TABLE orders
    ADD CONSTRAINT orders_customer_id_fkey
    FOREIGN KEY (customer_id)
    REFERENCES customer(customer_id);

-- Внешний ключ order_items → products
ALTER TABLE order_items
    ADD CONSTRAINT order_items_product_id_fkey
    FOREIGN KEY (product_id)
    REFERENCES products(product_id);

-- Финальная проверка: дубликаты позиций в заказе
SELECT order_id, product_id, COUNT(*) AS cnt
FROM order_items
GROUP BY order_id, product_id
HAVING COUNT(*) > 1;
