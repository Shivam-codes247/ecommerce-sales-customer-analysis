SET search_path TO ecommerce;

-- View: one row per delivered order in the analysis window, keyed by REAL customer
CREATE OR REPLACE VIEW v_customer_orders AS
SELECT d.customer_unique_id,
       d.order_id,
       d.order_purchase_timestamp,
       d.order_month,
       r.item_revenue AS revenue
FROM v_orders_delivered d
JOIN v_order_revenue r ON r.order_id = d.order_id
WHERE d.in_analysis_window;

-- 0. Reconciliation: expect 96211 orders, 93104 customers, 13181027.13 revenue
SELECT COUNT(*) AS orders,
       COUNT(DISTINCT customer_unique_id) AS customers,
       ROUND(SUM(revenue), 2) AS revenue
FROM v_customer_orders;

-- 1. Repeat rate, CLV, and the revenue share of repeat customers
WITH c AS (
    SELECT customer_unique_id, COUNT(*) AS orders, SUM(revenue) AS revenue
    FROM v_customer_orders
    GROUP BY customer_unique_id
)
SELECT COUNT(*)                                             AS customers,
       COUNT(*) FILTER (WHERE orders > 1)                   AS repeat_customers,
       ROUND(100.0 * COUNT(*) FILTER (WHERE orders > 1) / COUNT(*), 2) AS repeat_rate_pct,
       ROUND(AVG(orders), 3)                                AS avg_orders_per_customer,
       ROUND(AVG(revenue), 2)                               AS avg_clv,
       ROUND(AVG(revenue) FILTER (WHERE orders > 1), 2)     AS avg_clv_repeat,
       ROUND(AVG(revenue) FILTER (WHERE orders = 1), 2)     AS avg_clv_onetime,
       ROUND(100.0 * SUM(revenue) FILTER (WHERE orders > 1) / SUM(revenue), 1) AS revenue_share_repeat
FROM c;

-- 2. Distribution: how many customers placed 1, 2, 3+ orders?
WITH c AS (
    SELECT customer_unique_id, COUNT(*) AS orders
    FROM v_customer_orders
    GROUP BY customer_unique_id
)
SELECT LEAST(orders, 4) AS orders_bucket,   -- 4 means "4 or more"
       COUNT(*)         AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct
FROM c
GROUP BY 1
ORDER BY 1;

-- 3. Customer value deciles (decile 1 = top 10% of customers by lifetime revenue)
WITH c AS (
    SELECT customer_unique_id, SUM(revenue) AS revenue
    FROM v_customer_orders
    GROUP BY customer_unique_id
),
d AS (
    SELECT *, NTILE(10) OVER (ORDER BY revenue DESC, customer_unique_id) AS decile
    FROM c
)
SELECT decile,
       COUNT(*)                         AS customers,
       ROUND(SUM(revenue), 2)           AS revenue,
       ROUND(AVG(revenue), 2)           AS avg_revenue,
       ROUND(100.0 * SUM(revenue) / SUM(SUM(revenue)) OVER (), 1) AS pct_of_revenue
FROM d
GROUP BY decile
ORDER BY decile;

-- 4. RFM segmentation
--    Frequency is rule-based (not NTILE) because most customers have exactly 1 order,
--    so quintiles of frequency would be meaningless.
WITH ref AS (
    SELECT MAX(order_purchase_timestamp)::date + 1 AS ref_date FROM v_customer_orders
),
base AS (
    SELECT co.customer_unique_id,
           (SELECT ref_date FROM ref) - MAX(co.order_purchase_timestamp)::date AS recency_days,
           COUNT(*)         AS frequency,
           SUM(co.revenue)  AS monetary
    FROM v_customer_orders co
    GROUP BY co.customer_unique_id
),
scored AS (
    SELECT *,
           NTILE(5) OVER (ORDER BY recency_days DESC, customer_unique_id) AS r,  -- 5 = most recent
           NTILE(5) OVER (ORDER BY monetary, customer_unique_id)          AS m,  -- 5 = biggest spender
           CASE WHEN frequency = 1 THEN 1 WHEN frequency = 2 THEN 2 ELSE 3 END AS f
    FROM base
),
segmented AS (
    SELECT *,
           CASE
               WHEN f >= 2 AND r >= 4              THEN '1. Active repeat buyers'
               WHEN f >= 2                         THEN '2. Lapsing repeat buyers'
               WHEN r >= 4 AND m >= 4              THEN '3. New big spenders'
               WHEN r >= 4                         THEN '4. New customers'
               WHEN r <= 2 AND m >= 4              THEN '5. At risk: high value one-timers'
               WHEN r <= 2                         THEN '6. Lost one-timers'
               ELSE                                     '7. Mid one-timers'
           END AS segment
    FROM scored
)
SELECT segment,
       COUNT(*)                                          AS customers,
       ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_customers,
       ROUND(SUM(monetary), 2)                           AS revenue,
       ROUND(100.0 * SUM(monetary) / SUM(SUM(monetary)) OVER (), 1) AS pct_revenue,
       ROUND(AVG(monetary), 2)                           AS avg_revenue,
       ROUND(AVG(recency_days), 0)                       AS avg_recency_days
FROM segmented
GROUP BY segment
ORDER BY segment;

-- 5. Cohort retention (share of each monthly cohort that orders again N months later)
--    NULL = that month hasn't happened yet in the data (censored), not 0%.
WITH first_order AS (
    SELECT customer_unique_id,
           DATE_TRUNC('month', MIN(order_purchase_timestamp))::date AS cohort
    FROM v_customer_orders
    GROUP BY customer_unique_id
),
activity AS (
    SELECT DISTINCT
           f.cohort,
           f.customer_unique_id,
           ((EXTRACT(YEAR  FROM co.order_month) - EXTRACT(YEAR  FROM f.cohort)) * 12
           + EXTRACT(MONTH FROM co.order_month) - EXTRACT(MONTH FROM f.cohort))::int AS months_since
    FROM v_customer_orders co
    JOIN first_order f ON f.customer_unique_id = co.customer_unique_id
),
cohort_size AS (
    SELECT cohort, COUNT(*) AS n FROM first_order GROUP BY cohort
)
SELECT a.cohort,
       s.n AS cohort_size,
       CASE WHEN a.cohort + INTERVAL '1 month'  <= DATE '2018-08-01'
            THEN ROUND(100.0 * COUNT(*) FILTER (WHERE a.months_since = 1) / s.n, 2) END AS m1_pct,
       CASE WHEN a.cohort + INTERVAL '3 months' <= DATE '2018-08-01'
            THEN ROUND(100.0 * COUNT(*) FILTER (WHERE a.months_since = 3) / s.n, 2) END AS m3_pct,
       CASE WHEN a.cohort + INTERVAL '6 months' <= DATE '2018-08-01'
            THEN ROUND(100.0 * COUNT(*) FILTER (WHERE a.months_since = 6) / s.n, 2) END AS m6_pct
FROM activity a
JOIN cohort_size s ON s.cohort = a.cohort
GROUP BY a.cohort, s.n
ORDER BY a.cohort;

-- 6. Time to second purchase (repeat customers only)
WITH ordered AS (
    SELECT customer_unique_id,
           order_purchase_timestamp AS ts,
           LAG(order_purchase_timestamp) OVER w AS prev_ts,
           ROW_NUMBER() OVER w                  AS rn
    FROM v_customer_orders
    WINDOW w AS (PARTITION BY customer_unique_id ORDER BY order_purchase_timestamp, order_id)
),
gaps AS (
    SELECT ts::date - prev_ts::date AS days_to_second
    FROM ordered
    WHERE rn = 2
)
SELECT COUNT(*)                                                   AS repeat_customers,
       COUNT(*) FILTER (WHERE days_to_second = 0)                 AS same_day_second_order,
       ROUND(AVG(days_to_second), 1)                              AS avg_days,
       PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY days_to_second) AS median_days,
       PERCENTILE_CONT(0.9) WITHIN GROUP (ORDER BY days_to_second) AS p90_days
FROM gaps;