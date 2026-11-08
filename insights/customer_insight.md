# Customer Insights (Jan 2017 – Aug 2018, unique customers)

1. 97.0% of 93,104 customers bought once; 3.0% repeated. 29.7% of repeaters ordered
   again on the same day, so the true repeat rate is about 2.1%.
2. Repeat customers average R$260 lifetime revenue vs R$138 for one-time buyers
   (1.9x), but account for only 5.5% of revenue.
3. Revenue concentration is basket-driven: the top 10% of customers hold 41.1% of
   revenue (avg R$582); the bottom 50% hold 16.7%.
4. Cohort retention is below 1% at months 1, 3 and 6 for every cohort, including the
   Nov 2017 Black Friday cohort (7,061 customers).
5. 58% of revenue comes from one-time higher-spend customers: 14,441 recent ("new big
   spenders") and 13,745 inactive for ~13 months ("at risk").
6. Median time to second order is 29 days (p90: 245 days).

**Recommendations**
- Trigger a post-purchase campaign within 30 days for high-basket first-time buyers
  (the 14,441 "new big spenders" group), before they drift into "at risk".
- Run a small A/B reactivation test on the 13,745 at-risk customers before scaling.
- Illustrative sizing: each +1 pp of repeat rate is ~931 customers; at the ~R$122
  lifetime-revenue gap between repeat and one-time buyers, that is ~R$114k (~0.9% of
  revenue). This is correlational, so treat it as an order-of-magnitude estimate.

*Limitations:* cohorts near the end of the window had less time to return (censoring);
2016 customers appear as "new" in 2017; cohort percentages rest on very small counts;
one person using several accounts would be counted as several customers.

**Method notes**
- Customer analysis uses `customer_unique_id`; RFM recency is measured from the last order in the data (not today's date).
- Frequency scoring is rule-based (1, 2, 3+ orders) because 97% of customers have a single order.
- 827 repeat customers placed same-day second orders; the true repeat rate is ~2.1%.