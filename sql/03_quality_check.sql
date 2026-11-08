SET search_path TO ecommerce;

-- 1. Date range of the data (are the earliest/latest months complete?)
SELECT MIN(order_purchase_timestamp) AS first_order,
       MAX(order_purchase_timestamp) AS last_order
FROM orders;

-- 2. Order status distribution
SELECT order_status,
       COUNT(*) AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM orders
GROUP BY order_status
ORDER BY orders DESC;

-- 3. NULL profile of key order columns, using FILTER
SELECT COUNT(*)                                                   AS total_orders,
       COUNT(*) FILTER (WHERE order_approved_at IS NULL)          AS null_approved,
       COUNT(*) FILTER (WHERE order_delivered_carrier_date IS NULL)  AS null_carrier,
       COUNT(*) FILTER (WHERE order_delivered_customer_date IS NULL) AS null_delivered
FROM orders;

-- 4. Logical inconsistencies: "delivered" orders with no delivery date
SELECT COUNT(*) AS delivered_but_no_date
FROM orders
WHERE order_status = 'delivered'
  AND order_delivered_customer_date IS NULL;

-- 5. Date logic errors: delivered before purchase / carrier before approval
SELECT COUNT(*) FILTER (WHERE order_delivered_customer_date < order_purchase_timestamp) AS delivered_before_purchase,
       COUNT(*) FILTER (WHERE order_delivered_carrier_date  < order_approved_at)        AS carrier_before_approval
FROM orders;

-- 6. Orphan check: orders with no items
SELECT o.order_status, COUNT(*) AS orders_without_items
FROM orders o
LEFT JOIN order_items oi ON oi.order_id = o.order_id
WHERE oi.order_id IS NULL
GROUP BY o.order_status
ORDER BY 2 DESC;

-- 7. Duplicate review_ids and orders with multiple reviews
WITH dup_reviews AS (
    SELECT review_id, COUNT(*) AS n
    FROM order_reviews
    GROUP BY review_id
    HAVING COUNT(*) > 1
),
multi_review_orders AS (
    SELECT order_id, COUNT(*) AS n
    FROM order_reviews
    GROUP BY order_id
    HAVING COUNT(*) > 1
)
SELECT (SELECT COUNT(*) FROM dup_reviews)          AS duplicated_review_ids,
       (SELECT COUNT(*) FROM multi_review_orders)  AS orders_with_multiple_reviews;

-- 8. Payment oddities: zero-value payments and undefined types
SELECT payment_type,
       COUNT(*) AS payments,
       COUNT(*) FILTER (WHERE payment_value = 0) AS zero_value
FROM order_payments
GROUP BY payment_type
ORDER BY payments DESC;

-- 9. Products with missing category, and categories missing a translation
SELECT COUNT(*) FILTER (WHERE product_category_name IS NULL) AS no_category,
       COUNT(*) FILTER (WHERE product_category_name IS NOT NULL
                        AND product_category_name NOT IN
                            (SELECT product_category_name FROM product_category_translation)) AS no_translation
FROM products;

-- 10. The customer_id vs customer_unique_id trap, quantified
SELECT COUNT(DISTINCT customer_id)        AS customer_ids,
       COUNT(DISTINCT customer_unique_id) AS real_customers
FROM customers;