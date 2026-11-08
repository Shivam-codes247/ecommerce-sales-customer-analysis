-- Export-ready dashboard datasets; run after the cleaning and analysis views exist.
SET search_path TO ecommerce;

CREATE OR REPLACE VIEW x_monthly_sales AS
WITH m AS (
    SELECT d.order_month, COUNT(*) AS orders, SUM(r.item_revenue) AS revenue
    FROM v_orders_delivered d
    JOIN v_order_revenue r ON r.order_id = d.order_id
    WHERE d.in_analysis_window
    GROUP BY d.order_month
)
SELECT order_month,
       orders,
       ROUND(revenue, 2)          AS revenue,
       ROUND(revenue / orders, 2) AS aov,
       ROUND(100.0 * (revenue - LAG(revenue) OVER w)
             / NULLIF(LAG(revenue) OVER w, 0), 1) AS mom_pct
FROM m
WINDOW w AS (ORDER BY order_month);

CREATE OR REPLACE VIEW x_state_sales AS
SELECT d.customer_state,
       COUNT(*)                       AS orders,
       ROUND(SUM(r.item_revenue), 2)  AS revenue,
       ROUND(AVG(d.delivery_days), 1) AS avg_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE d.is_late)
             / NULLIF(COUNT(d.is_late), 0), 1) AS late_pct,
       ROUND(AVG(rv.review_score), 2) AS avg_score
FROM v_orders_delivered d
JOIN v_order_revenue r ON r.order_id = d.order_id
LEFT JOIN v_reviews_latest rv ON rv.order_id = d.order_id
WHERE d.in_analysis_window
GROUP BY d.customer_state;

CREATE OR REPLACE VIEW x_category_pareto AS
WITH cat AS (
    SELECT category, SUM(units) AS units, SUM(revenue) AS revenue
    FROM v_order_category
    WHERE in_analysis_window
    GROUP BY category
)
SELECT ROW_NUMBER() OVER (ORDER BY revenue DESC, category) AS rnk,
       category,
       units,
       ROUND(revenue, 2) AS revenue,
       ROUND(100.0 * SUM(revenue) OVER (ORDER BY revenue DESC, category
                                        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)
             / SUM(revenue) OVER (), 1) AS cumulative_pct
FROM cat;

CREATE OR REPLACE VIEW x_category_scorecard AS
SELECT vc.category,
       COUNT(*)                        AS orders,
       ROUND(SUM(vc.revenue), 2)       AS revenue,
       ROUND(AVG(rv.review_score), 2)  AS avg_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE d.is_late)
             / NULLIF(COUNT(d.is_late), 0), 1) AS late_pct,
       ROUND(AVG(d.delivery_days), 1)  AS avg_delivery_days
FROM v_order_category vc
JOIN v_orders_delivered d ON d.order_id = vc.order_id
LEFT JOIN v_reviews_latest rv ON rv.order_id = vc.order_id
WHERE vc.in_analysis_window
GROUP BY vc.category
HAVING COUNT(*) >= 200;

CREATE OR REPLACE VIEW x_lateness_vs_reviews AS
WITH x AS (
    SELECT order_id,
           CASE WHEN days_late <= 0  THEN '1. On time or early'
                WHEN days_late <= 3  THEN '2. 1-3 days late'
                WHEN days_late <= 7  THEN '3. 4-7 days late'
                WHEN days_late <= 14 THEN '4. 8-14 days late'
                ELSE                      '5. 15+ days late' END AS bucket
    FROM v_orders_delivered
    WHERE in_analysis_window AND order_delivered_customer_date IS NOT NULL
)
SELECT x.bucket,
       COUNT(*)                       AS orders,
       ROUND(AVG(rv.review_score), 2) AS avg_score,
       ROUND(100.0 * COUNT(*) FILTER (WHERE rv.review_score <= 2)
             / NULLIF(COUNT(rv.review_score), 0), 1) AS pct_low
FROM x
LEFT JOIN v_reviews_latest rv ON rv.order_id = x.order_id
GROUP BY x.bucket;

CREATE OR REPLACE VIEW x_monthly_delivery AS
SELECT order_month,
       COUNT(*)                       AS orders,
       ROUND(AVG(delivery_days), 1)   AS avg_delivery_days,
       ROUND(100.0 * COUNT(*) FILTER (WHERE is_late)
             / NULLIF(COUNT(is_late), 0), 1) AS late_pct
FROM v_orders_delivered
WHERE in_analysis_window
GROUP BY order_month;