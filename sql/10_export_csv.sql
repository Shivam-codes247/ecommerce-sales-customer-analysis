-- Export every dashboard view to outputs/*.csv.
-- Run from the repository root with psql so the relative output paths resolve.
SET search_path TO ecommerce;

\copy (SELECT * FROM x_monthly_sales ORDER BY order_month) TO 'outputs/monthly_sales.csv' CSV HEADER
\copy (SELECT * FROM x_state_sales ORDER BY revenue DESC) TO 'outputs/state_sales.csv' CSV HEADER
\copy (SELECT * FROM x_category_pareto ORDER BY rnk) TO 'outputs/category_pareto.csv' CSV HEADER
\copy (SELECT * FROM x_category_scorecard ORDER BY avg_score) TO 'outputs/category_scorecard.csv' CSV HEADER
\copy (SELECT * FROM x_lateness_vs_reviews ORDER BY bucket) TO 'outputs/lateness_vs_reviews.csv' CSV HEADER
\copy (SELECT * FROM x_monthly_delivery ORDER BY order_month) TO 'outputs/monthly_delivery.csv' CSV HEADER
\copy (SELECT * FROM x_rfm_segments ORDER BY segment) TO 'outputs/rfm_segments.csv' CSV HEADER