SET search_path TO ecommerce;

-- 1. Headline KPIs (analysis window, delivered orders)
SELECT COUNT(*)                                   AS orders,
       COUNT(DISTINCT d.customer_unique_id)       AS customers,
       ROUND(SUM(r.item_revenue), 2)              AS revenue_brl,
       ROUND(SUM(r.item_revenue) / COUNT(*), 2)   AS avg_order_value,
       ROUND(SUM(r.freight), 2)                   AS freight_brl,
       ROUND(100.0 * SUM(r.freight) / SUM(r.item_revenue), 1) AS freight_pct_of_revenue,
       ROUND(AVG(r.items), 2)                     AS avg_items_per_order
FROM v_orders_delivered d
JOIN v_order_revenue r ON r.order_id = d.order_id
WHERE d.in_analysis_window;

-- 2. Monthly revenue with MoM %, YoY %, and cumulative revenue
WITH monthly AS (
    SELECT d.order_month,
           COUNT(*)            AS orders,
           SUM(r.item_revenue) AS revenue
    FROM v_orders_delivered d
    JOIN v_order_revenue r ON r.order_id = d.order_id
    WHERE d.in_analysis_window
    GROUP BY d.order_month
)
SELECT order_month,
       orders,
       ROUND(revenue, 2)                         AS revenue,
       ROUND(revenue / orders, 2)                AS aov,
       ROUND(100.0 * (revenue - LAG(revenue)     OVER w)
             / NULLIF(LAG(revenue)     OVER w, 0), 1) AS mom_pct,
       ROUND(100.0 * (revenue - LAG(revenue, 12) OVER w)
             / NULLIF(LAG(revenue, 12) OVER w, 0), 1) AS yoy_pct,
       ROUND(SUM(revenue) OVER (ORDER BY order_month), 2) AS cumulative_revenue
FROM monthly
WINDOW w AS (ORDER BY order_month)
ORDER BY order_month;

-- 3. Revenue by customer state: share and cumulative share (Pareto by geography)
WITH state_rev AS (
    SELECT d.customer_state,
           COUNT(*)                             AS orders,
           COUNT(DISTINCT d.customer_unique_id) AS customers,
           SUM(r.item_revenue)                  AS revenue
    FROM v_orders_delivered d
    JOIN v_order_revenue r ON r.order_id = d.order_id
    WHERE d.in_analysis_window
    GROUP BY d.customer_state
)
SELECT customer_state,
       orders,
       customers,
       ROUND(revenue, 2)                                   AS revenue,
       ROUND(revenue / orders, 2)                          AS aov,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)    AS pct_of_total,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC)
             / SUM(revenue) OVER (), 1)                    AS cumulative_pct
FROM state_rev
ORDER BY revenue DESC;

-- 4. Day-of-week pattern
SELECT EXTRACT(ISODOW FROM d.order_purchase_timestamp)::int AS dow,
       TO_CHAR(d.order_purchase_timestamp, 'Dy')            AS day_name,
       COUNT(*)                                             AS orders,
       ROUND(SUM(r.item_revenue), 2)                        AS revenue
FROM v_orders_delivered d
JOIN v_order_revenue r ON r.order_id = d.order_id
WHERE d.in_analysis_window
GROUP BY 1, 2
ORDER BY 1;

-- 5. Peak days (what happened around Nov 2017?)
SELECT d.order_purchase_timestamp::date AS day,
       COUNT(*)                         AS orders,
       ROUND(SUM(r.item_revenue), 2)    AS revenue
FROM v_orders_delivered d
JOIN v_order_revenue r ON r.order_id = d.order_id
WHERE d.in_analysis_window
GROUP BY 1
ORDER BY orders DESC
LIMIT 5;