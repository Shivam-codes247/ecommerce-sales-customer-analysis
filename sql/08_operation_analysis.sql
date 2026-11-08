SET search_path TO ecommerce;

-- 0. Why the fix matters: timestamp vs date definition of "late"
SELECT COUNT(*) FILTER (WHERE order_estimated_delivery_date::time <> TIME '00:00:00') AS non_midnight_estimates,
       COUNT(*) FILTER (WHERE order_delivered_customer_date > order_estimated_delivery_date) AS late_by_timestamp,
       COUNT(*) FILTER (WHERE order_delivered_customer_date::date > order_estimated_delivery_date::date) AS late_by_date
FROM orders
WHERE order_status = 'delivered'
  AND order_purchase_timestamp >= '2017-01-01'
  AND order_purchase_timestamp <  '2018-09-01';

-- 1. Delivery KPIs
SELECT COUNT(*)                                                         AS orders,
       ROUND(AVG(delivery_days), 1)                                     AS avg_delivery_days,
       ROUND((PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY delivery_days))::numeric, 1) AS median_days,
       ROUND((PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY delivery_days))::numeric, 1) AS p90_days,
       ROUND(AVG(order_estimated_delivery_date::date - order_purchase_timestamp::date), 1) AS avg_promised_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 2)     AS late_pct,
       ROUND(AVG(days_late) FILTER (WHERE is_late), 1)                  AS avg_days_late_when_late
FROM v_orders_delivered
WHERE in_analysis_window
  AND order_delivered_customer_date IS NOT NULL;

-- 2. Monthly delivery performance
SELECT order_month,
       COUNT(*)                                                     AS orders,
       ROUND(AVG(delivery_days), 1)                                 AS avg_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late) / COUNT(*), 1) AS late_pct
FROM v_orders_delivered
WHERE in_analysis_window
  AND order_delivered_customer_date IS NOT NULL
GROUP BY order_month
ORDER BY order_month;

-- 3. Does lateness hurt reviews?
WITH x AS (
    SELECT order_id,
           CASE WHEN days_late <= 0  THEN '1. On time or early'
                WHEN days_late <= 3  THEN '2. 1-3 days late'
                WHEN days_late <= 7  THEN '3. 4-7 days late'
                WHEN days_late <= 14 THEN '4. 8-14 days late'
                ELSE                      '5. 15+ days late' END AS bucket
    FROM v_orders_delivered
    WHERE in_analysis_window
      AND order_delivered_customer_date IS NOT NULL
)
SELECT x.bucket,
       COUNT(*)                                   AS orders,
       COUNT(rv.review_score)                     AS reviewed,
       ROUND(AVG(rv.review_score), 2)             AS avg_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rv.review_score <= 2) / NULLIF(COUNT(rv.review_score), 0), 1) AS pct_low,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rv.review_score = 5)  / NULLIF(COUNT(rv.review_score), 0), 1) AS pct_5star
FROM x
LEFT JOIN v_reviews_latest rv ON rv.order_id = x.order_id
GROUP BY x.bucket
ORDER BY x.bucket;

-- 4. Delivery performance by category (tests the office_furniture / bed_bath_table hypothesis)
--    Note: "orders" = order x category rows, so don't sum across categories.
SELECT vc.category,
       COUNT(*)                                                     AS orders,
       ROUND(AVG(d.delivery_days), 1)                               AS avg_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE d.is_late) / COUNT(*), 1) AS late_pct,
       ROUND(AVG(rv.review_score), 2)                               AS avg_score
FROM v_order_category vc
JOIN v_orders_delivered d ON d.order_id = vc.order_id
LEFT JOIN v_reviews_latest rv ON rv.order_id = vc.order_id
WHERE vc.in_analysis_window
  AND d.order_delivered_customer_date IS NOT NULL
GROUP BY vc.category
HAVING COUNT(*) >= 200
ORDER BY late_pct DESC;

-- 5. Delivery experience by customer state
SELECT d.customer_state,
       COUNT(*)                                                     AS orders,
       ROUND(AVG(d.delivery_days), 1)                               AS avg_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE d.is_late) / COUNT(*), 1) AS late_pct,
       ROUND(100.0 * SUM(r.freight) / SUM(r.item_revenue), 1)       AS freight_pct,
       ROUND(AVG(rv.review_score), 2)                               AS avg_score
FROM v_orders_delivered d
JOIN v_order_revenue r ON r.order_id = d.order_id
LEFT JOIN v_reviews_latest rv ON rv.order_id = d.order_id
WHERE d.in_analysis_window
  AND d.order_delivered_customer_date IS NOT NULL
GROUP BY d.customer_state
ORDER BY avg_delivery_days DESC;

-- 6. Payment mix (payment_value includes freight and any installment interest,
--    so it will NOT equal item revenue)
SELECT p.payment_type,
       COUNT(DISTINCT p.order_id)                                   AS orders,
       ROUND(SUM(p.payment_value), 2)                               AS paid_value,
       ROUND(100.0 * SUM(p.payment_value) / SUM(SUM(p.payment_value)) OVER (), 1) AS pct_of_value,
       ROUND(AVG(p.payment_value), 2)                               AS avg_payment
FROM order_payments p
JOIN v_orders_delivered d ON d.order_id = p.order_id
WHERE d.in_analysis_window
  AND p.payment_type <> 'not_defined'
  AND p.payment_value > 0
GROUP BY p.payment_type
ORDER BY paid_value DESC;

-- 7. Credit-card installments vs order value (association, not causation)
WITH cc AS (
    SELECT p.order_id,
           MAX(p.payment_installments) AS inst,
           SUM(p.payment_value)        AS paid
    FROM order_payments p
    JOIN v_orders_delivered d ON d.order_id = p.order_id
    WHERE d.in_analysis_window
      AND p.payment_type = 'credit_card'
      AND p.payment_value > 0
    GROUP BY p.order_id
)
SELECT CASE WHEN inst <= 1  THEN '1 (paid in full)'
            WHEN inst <= 3  THEN '2-3'
            WHEN inst <= 6  THEN '4-6'
            WHEN inst <= 10 THEN '7-10'
            ELSE                 '11+' END                          AS installments,
       COUNT(*)                                                     AS orders,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)           AS pct_orders,
       ROUND(AVG(paid), 2)                                          AS avg_paid
FROM cc
GROUP BY 1
ORDER BY MIN(inst);