SET search_path TO ecommerce;

-- Orders: delivered only, joined to real customer identity
CREATE OR REPLACE VIEW v_orders_delivered AS
SELECT o.order_id,
       o.customer_id,
       c.customer_unique_id,
       c.customer_city,
       c.customer_state,
       o.order_purchase_timestamp,
       o.order_delivered_customer_date,
       o.order_estimated_delivery_date,
       DATE_TRUNC('month', o.order_purchase_timestamp)::date AS order_month,
       (o.order_delivered_customer_date::date - o.order_purchase_timestamp::date) AS delivery_days,
       (o.order_delivered_customer_date::date > o.order_estimated_delivery_date::date) AS is_late,
       -- flag for the reliable, complete-month window
       (o.order_purchase_timestamp >= '2017-01-01'
        AND o.order_purchase_timestamp <  '2018-09-01')                           AS in_analysis_window,
       (o.order_delivered_customer_date::date - o.order_estimated_delivery_date::date) AS days_late
FROM orders o
JOIN customers c ON c.customer_id = o.customer_id
WHERE o.order_status = 'delivered';

-- Items aggregated to ONE ROW PER ORDER (prevents fan-out)
CREATE OR REPLACE VIEW v_order_revenue AS
SELECT order_id,
       COUNT(*)           AS items,
       SUM(price)         AS item_revenue,
       SUM(freight_value) AS freight,
       SUM(price + freight_value) AS gross_value
FROM order_items
GROUP BY order_id;

-- Payments aggregated to one row per order, excluding junk rows
CREATE OR REPLACE VIEW v_order_payments AS
SELECT order_id,
       SUM(payment_value)       AS paid_value,
       MAX(payment_installments) AS max_installments,
       COUNT(*)                 AS payment_rows
FROM order_payments
WHERE payment_type <> 'not_defined'
  AND payment_value > 0
GROUP BY order_id;

-- One review per order: keep the most recent
CREATE OR REPLACE VIEW v_reviews_latest AS
SELECT order_id, review_score, review_creation_date
FROM (
    SELECT order_id, review_score, review_creation_date,
           ROW_NUMBER() OVER (PARTITION BY order_id
                              ORDER BY review_answer_timestamp DESC NULLS LAST,
                                       review_creation_date DESC) AS rn
    FROM order_reviews
) r
WHERE rn = 1;

-- Products with English category names and sensible fallbacks
CREATE OR REPLACE VIEW v_products_clean AS
SELECT p.product_id,
       COALESCE(t.product_category_name_english,
                p.product_category_name,
                'unknown') AS category,
       p.product_weight_g
FROM products p
LEFT JOIN product_category_translation t
       ON t.product_category_name = p.product_category_name;