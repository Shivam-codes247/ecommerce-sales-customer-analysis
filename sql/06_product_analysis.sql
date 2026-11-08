SET search_path TO ecommerce;

-- View: one row per order x category (delivered orders only)
CREATE OR REPLACE VIEW v_order_category AS
SELECT oi.order_id,
       p.category,
       d.order_month,
       d.in_analysis_window,
       COUNT(*)                AS units,
       SUM(oi.price)           AS revenue,
       SUM(oi.freight_value)   AS freight
FROM order_items oi
JOIN v_orders_delivered d ON d.order_id = oi.order_id
JOIN v_products_clean   p ON p.product_id = oi.product_id
GROUP BY oi.order_id, p.category, d.order_month, d.in_analysis_window;

-- 0. Reconciliation: must equal 13181027.13
SELECT ROUND(SUM(revenue), 2) AS total_revenue
FROM v_order_category
WHERE in_analysis_window;

-- 1. Category Pareto (80/20)
WITH cat AS (
    SELECT category,
           COUNT(*)     AS orders,
           SUM(units)   AS units,
           SUM(revenue) AS revenue
    FROM v_order_category
    WHERE in_analysis_window
    GROUP BY category
)
SELECT ROW_NUMBER() OVER (ORDER BY revenue DESC, category) AS rnk,
       category,
       orders,
       units,
       ROUND(revenue, 2)                                   AS revenue,
       ROUND(revenue / units, 2)                           AS avg_unit_price,
       ROUND(100.0 * revenue / SUM(revenue) OVER (), 1)    AS pct_of_total,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, category
                                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(revenue) OVER (), 1)                    AS cumulative_pct
FROM cat
ORDER BY revenue DESC, category;

-- 2. Category scorecard: revenue, freight burden, and customer satisfaction
--    (categories with fewer than 200 orders are excluded: averages on tiny samples mislead)
SELECT vc.category,
       COUNT(*)                                        AS orders,
       ROUND(SUM(vc.revenue), 2)                       AS revenue,
       ROUND(SUM(vc.revenue) / SUM(vc.units), 2)       AS avg_unit_price,
       ROUND(100.0 * SUM(vc.freight) / SUM(vc.revenue), 1) AS freight_pct,
       ROUND(AVG(rv.review_score), 2)                  AS avg_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rv.review_score <= 2)
             / NULLIF(COUNT(rv.review_score), 0), 1)   AS pct_low_reviews
FROM v_order_category vc
LEFT JOIN v_reviews_latest rv ON rv.order_id = vc.order_id
WHERE vc.in_analysis_window
GROUP BY vc.category
HAVING COUNT(*) >= 200
ORDER BY avg_score ASC;

-- 3. High volume but below-average satisfaction (categories to fix first)
WITH stats AS (
    SELECT vc.category,
           COUNT(*)                  AS orders,
           SUM(vc.revenue)           AS revenue,
           AVG(rv.review_score)      AS avg_score
    FROM v_order_category vc
    LEFT JOIN v_reviews_latest rv ON rv.order_id = vc.order_id
    WHERE vc.in_analysis_window
    GROUP BY vc.category
    HAVING COUNT(*) >= 200
),
med AS (
    SELECT PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY orders) AS median_orders
    FROM stats
),
overall AS (
    SELECT AVG(rl.review_score) AS avg_score
    FROM v_reviews_latest rl
    JOIN v_orders_delivered d ON d.order_id = rl.order_id
    WHERE d.in_analysis_window
)
SELECT s.category,
       s.orders,
       ROUND(s.revenue, 2)      AS revenue,
       ROUND(s.avg_score, 2)    AS avg_score,
       ROUND(o.avg_score, 2)    AS overall_avg
FROM stats s
CROSS JOIN med m
CROSS JOIN overall o
WHERE s.orders >= m.median_orders
  AND s.avg_score < o.avg_score
ORDER BY s.orders DESC;

-- 4. Long tail: how many products produce 80% of revenue?
WITH prod AS (
    SELECT oi.product_id, SUM(oi.price) AS revenue
    FROM order_items oi
    JOIN v_orders_delivered d ON d.order_id = oi.order_id
    WHERE d.in_analysis_window
    GROUP BY oi.product_id
),
ranked AS (
    SELECT product_id,
           revenue,
           SUM(revenue) OVER (ORDER BY revenue DESC, product_id
                              ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW) - revenue AS rev_before,
           SUM(revenue) OVER () AS total
    FROM prod
)
SELECT COUNT(*)                                              AS total_products,
       COUNT(*) FILTER (WHERE rev_before < 0.8 * total)      AS products_for_80pct,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rev_before < 0.8 * total)
             / COUNT(*), 1)                                  AS pct_of_products
FROM ranked;

-- 5. Top 10 products by revenue
SELECT oi.product_id,
       p.category,
       COUNT(*)                   AS units,
       ROUND(SUM(oi.price), 2)    AS revenue
FROM order_items oi
JOIN v_orders_delivered d ON d.order_id = oi.order_id
JOIN v_products_clean   p ON p.product_id = oi.product_id
WHERE d.in_analysis_window
GROUP BY oi.product_id, p.category
ORDER BY revenue DESC
LIMIT 10;