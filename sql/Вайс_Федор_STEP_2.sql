-- Задание 1.
-- Логика: нам нужны бренды, которые одновременно:
-- 1) имеют хотя бы один дорогой продукт (standard_cost > 1500),
-- 2) и в сумме продали не менее 1000 единиц любых своих товаров.
-- Поэтому агрегация идет на уровне бренда.

-- ВЕРСИЯ 1
SELECT
    p.brand
FROM order_items oi
JOIN orders   o ON oi.order_id   = o.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY
    p.brand
HAVING
    SUM(oi.quantity) >= 1000      -- общий объем продаж бренда
    AND MAX(p.standard_cost) > 1500  -- хотя бы один товар дороже 1500
ORDER BY
    p.brand DESC;

--ВЕРСИЯ 2
-- Альтернативная трактовка задания.
-- Здесь условия применяются НЕ к бренду в целом, а к каждому продукту отдельно.
-- То есть мы ищем продукты с ценой >1500 и продажами >=1000.
-- Выводим соответствующие бренды и эти продукты.

SELECT  
    p.brand
    --p.product_id,
    --SUM(oi.quantity) AS total_product_sales,
    --MAX(p.standard_cost) AS product_standard_cost
FROM order_items oi
JOIN orders   o ON oi.order_id   = o.order_id
JOIN products p ON oi.product_id = p.product_id
GROUP BY
    p.brand,
    p.product_id
HAVING
    SUM(oi.quantity) >= 1000          -- продажи именно этого продукта
    AND MAX(p.standard_cost) > 1500   -- этот же продукт стоит дороже 1500
ORDER BY
    p.brand DESC,
    p.product_id;


-- 2. Для каждого дня в диапазоне с 2017-04-01 по 2017-04-09 включительно вывести 
-- количество подтвержденных онлайн-заказов и количество уникальных клиентов, совершивших эти заказы.
    
SELECT
    o.order_date,
    COUNT(DISTINCT o.order_id)     AS approved_online_orders,
    COUNT(DISTINCT o.customer_id ) AS approved_online_customers
FROM orders o
WHERE
    o.order_date BETWEEN '2017-04-01' AND '2017-04-09'
    AND o.online_order IS TRUE
    AND o.order_status = 'Approved'
GROUP BY
    o.order_date
ORDER BY
    o.order_date ASC;
   
  
-- 3. Вывести профессии клиентов:
-- 		из сферы IT, чья профессия job_title начинается с Senior;
-- 		из сферы Financial Services, чья профессия job_title начинается с Lead.
-- Для обеих групп учитывать только клиентов старше 35 лет dob. Объединить выборки с помощью UNION ALL.
    
 
SELECT
    c.job_title
FROM customer c
WHERE EXTRACT(YEAR FROM age(CURRENT_DATE, c.dob)) > 35
    AND c.job_title LIKE 'Senior%'
    AND c.job_industry_category = 'IT'
   
UNION ALL

SELECT
    c.job_title
FROM customer c
WHERE 
    EXTRACT(YEAR FROM age(CURRENT_DATE, c.dob)) > 35
    AND c.job_title LIKE 'Lead%'
    AND c.job_industry_category = 'Financial Services';



-- 4. Вывести бренды, которые были куплены клиентами из сферы job_industry_category Financial Services, 
--    но не были куплены клиентами из сферы IT.
-- бренды, которые купили Financial Services
SELECT DISTINCT
    p.brand
FROM order_items oi
JOIN orders   o ON oi.order_id   = o.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN customer c ON o.customer_id = c.customer_id
WHERE c.job_industry_category = 'Financial Services'

EXCEPT

-- бренды, которые купили IT
SELECT DISTINCT
    p.brand
FROM order_items oi
JOIN orders   o ON oi.order_id   = o.order_id
JOIN products p ON oi.product_id = p.product_id
JOIN customer c ON o.customer_id = c.customer_id
WHERE c.job_industry_category = 'IT'
ORDER BY brand;
 

-- 5.Вывести TOP-10 клиентов (ID, имя, фамилия), которые совершили 
--   наибольшее количество онлайн-заказов (в штуках) MAX(COUNT(o.order_id))
--   брендов p.brand Giant Bicycles, Norco Bicycles, Trek Bicycles, при условии, 
--   что они активны и имеют оценку имущества (property_valuation) выше среднего 
--   среди клиентов из того же штата.
WITH state_avg AS (
    SELECT 
        state,
        AVG(property_valuation) AS mean_state_valuation
    FROM customer
    GROUP BY state
),
customer_stats AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        c.state,
        COUNT(DISTINCT o.order_id) AS online_orders,
        c.property_valuation,
        s.mean_state_valuation
    FROM customer c
    JOIN state_avg s ON s.state = c.state
    JOIN orders o ON o.customer_id = c.customer_id
    JOIN order_items oi ON oi.order_id = o.order_id
    JOIN products p ON p.product_id = oi.product_id
    WHERE 
        o.online_order = TRUE
        AND p.brand IN ('Giant Bicycles', 'Norco Bicycles', 'Trek Bicycles')
        AND c.deceased_indicator = 'N'
    GROUP BY
        c.customer_id, c.first_name, c.last_name, 
        c.state, c.property_valuation, s.mean_state_valuation
)
SELECT
    customer_id,
    first_name,
    last_name,
    online_orders
FROM customer_stats
WHERE property_valuation > mean_state_valuation
ORDER BY online_orders DESC
LIMIT 10;


--6. Вывести всех клиентов (ID, имя, фамилия), у которых нет 
--   подтвержденных онлайн-заказов за последний год, 
--   но при этом они владеют автомобилем c.owns_car = 'Yes' 
--   и их сегмент благосостояния не Mass Customer c.wealth_segment <> 'Mass Customer'.

SELECT
    c.customer_id,
    c.first_name,
    c.last_name
FROM customer c
WHERE 
    c.owns_car = 'Yes'
    AND c.wealth_segment <> 'Mass Customer'
    AND NOT EXISTS (
        SELECT 1
        FROM orders o
        WHERE 
            o.customer_id = c.customer_id
            AND o.online_order = TRUE
            AND o.order_status = 'Approved'
            AND o.order_date >= DATE '2017-01-01'
    )
ORDER BY c.customer_id;

--7. Вывести всех клиентов из сферы 'IT' (ID, имя, фамилия), 
--   которые купили 2 из 5 продуктов с самой высокой list_price в продуктовой линейке Road.

WITH top5_road AS (
    SELECT
        p.product_id
    FROM products p
    WHERE p.product_line = 'Road'
    ORDER BY p.list_price DESC
    LIMIT 5
),

it_customers_top5 AS (
    SELECT
        c.customer_id,
        c.first_name,
        c.last_name,
        COUNT(DISTINCT oi.product_id) AS cnt_top5_products
    FROM order_items oi
    JOIN orders   o ON oi.order_id   = o.order_id
    JOIN customer c ON o.customer_id = c.customer_id
    JOIN top5_road t ON oi.product_id = t.product_id
    WHERE
        c.job_industry_category = 'IT'
    GROUP BY
        c.customer_id,
        c.first_name,
        c.last_name
)

SELECT
    customer_id,
    first_name,
    last_name
FROM it_customers_top5
WHERE cnt_top5_products = 2
ORDER BY customer_id;


-- 8. Вывести клиентов (ID, имя, фамилия, сфера деятельности) из сфер IT или Health, 
--    которые совершили не менее 3 подтвержденных заказов в период 2017-01-01 по 2017-03-01, 
--    и при этом их общий доход от этих заказов превышает 10 000 долларов.
--    Разделить вывод на две группы (IT и Health) с помощью UNION.

-- Клиенты из IT
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.job_industry_category       AS industry,
    COUNT(DISTINCT o.order_id)    AS orders_count,
    SUM(oi.quantity * oi.item_list_price_at_sale) AS total_revenue
FROM customer c
JOIN orders o
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
WHERE
    c.job_industry_category = 'IT'
    AND o.order_status = 'Approved'
    AND o.order_date BETWEEN DATE '2017-01-01' AND DATE '2017-03-01'
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    c.job_industry_category
HAVING
    COUNT(DISTINCT o.order_id) >= 3
    AND SUM(oi.quantity * oi.item_list_price_at_sale) > 10000

UNION

-- Клиенты из Health
SELECT
    c.customer_id,
    c.first_name,
    c.last_name,
    c.job_industry_category       AS industry,
    COUNT(DISTINCT o.order_id)    AS orders_count,
    SUM(oi.quantity * oi.item_list_price_at_sale) AS total_revenue
FROM customer c
JOIN orders o
    ON o.customer_id = c.customer_id
JOIN order_items oi
    ON oi.order_id = o.order_id
WHERE
    c.job_industry_category = 'Health'
    AND o.order_status = 'Approved'
    AND o.order_date BETWEEN DATE '2017-01-01' AND DATE '2017-03-01'
GROUP BY
    c.customer_id,
    c.first_name,
    c.last_name,
    c.job_industry_category
HAVING
    COUNT(DISTINCT o.order_id) >= 3
    AND SUM(oi.quantity * oi.item_list_price_at_sale) > 10000
ORDER BY
    industry,
    total_revenue DESC;
