# E-Commerce Sales & Customer Analysis

## 📌 Project Overview

This project analyzes the **Brazilian E-Commerce Public Dataset by Olist** using SQL to understand sales performance, customer behavior, product performance, and overall business trends.

The dataset contains approximately **100,000 orders** from an online marketplace in Brazil and is distributed across multiple related tables. The project focuses on transforming raw transactional data into meaningful business insights using SQL.

The analysis is designed from the perspective of a **Data Analyst supporting an e-commerce business**.

---

## 🎯 Business Objective

The primary objective of this project is to answer key business questions related to:

* Sales and revenue performance
* Order volume and purchasing trends
* Customer spending and repeat purchases
* Product and category performance
* Monthly revenue growth
* Payment behavior
* Geographic distribution of customers

The final goal is to translate SQL analysis into **clear business insights and actionable recommendations**.

---

## 📊 Dataset

**Dataset:** Brazilian E-Commerce Public Dataset by Olist
**Source:** Kaggle
**Period:** 2016–2018
**Records:** Approximately 100,000 orders

The dataset contains multiple interconnected tables covering customers, orders, products, sellers, payments, reviews, and other e-commerce information.

### Main Tables

| Table                               | Description                                        |
| ----------------------------------- | -------------------------------------------------- |
| `olist_customers_dataset`           | Customer information and location                  |
| `olist_orders_dataset`              | Order details, status, and timestamps              |
| `olist_order_items_dataset`         | Products purchased in each order                   |
| `olist_products_dataset`            | Product information and categories                 |
| `olist_order_payments_dataset`      | Payment methods and payment values                 |
| `olist_order_reviews_dataset`       | Customer reviews and ratings                       |
| `olist_sellers_dataset`             | Seller information and location                    |
| `olist_geolocation_dataset`         | Brazilian ZIP-code geographic data                 |
| `product_category_name_translation` | Portuguese-to-English product category translation |

---

## 🛠️ Tools & Technologies

* **SQL**
* **PostgreSQL / MySQL**
* **Git**
* **GitHub**
* **Excel / CSV** for initial data inspection

---

## 🧠 SQL Concepts Used

The project will demonstrate practical application of:

* SELECT & filtering
* WHERE and HAVING
* GROUP BY & aggregations
* INNER JOIN / LEFT JOIN
* Subqueries
* Common Table Expressions (CTEs)
* CASE statements
* Date and time functions
* Window functions
* `ROW_NUMBER()`
* `RANK()`
* `LAG()`
* Customer and product ranking
* Month-over-month growth analysis

---

## 🔍 Business Questions

### Sales Analysis

1. What is the total revenue generated?
2. How many orders were placed?
3. What is the average order value?
4. How does revenue change month over month?
5. Which months generated the highest revenue?
6. How does order volume change over time?

### Customer Analysis

1. How many unique customers are there?
2. Who are the highest-spending customers?
3. Which customers have placed multiple orders?
4. What is the average spending per customer?
5. Which states have the highest number of customers?
6. What proportion of revenue comes from repeat customers?

### Product Analysis

1. Which products generate the highest revenue?
2. Which product categories perform best?
3. Which categories have the highest order volume?
4. What are the top products within each category?
5. How does product price relate to sales performance?

### Payment Analysis

1. Which payment methods are most commonly used?
2. What is the total payment value by payment method?
3. What is the average payment value for each payment type?
4. How does payment behavior vary across customers?

---

## 📈 Key Metrics

The analysis will calculate metrics such as:

* Total Revenue
* Total Orders
* Unique Customers
* Average Order Value (AOV)
* Revenue by Month
* Month-over-Month Revenue Growth
* Customer Lifetime Spending
* Repeat Customer Rate
* Revenue by Product Category
* Top Products by Revenue
* Revenue by Payment Method

---

## 🗂️ Project Structure

```text
ecommerce-sales-customer-analysis/
│
├── data/
│   └── raw/
│       ├── olist_customers_dataset.csv
│       ├── olist_geolocation_dataset.csv
│       ├── olist_order_items_dataset.csv
│       ├── olist_order_payments_dataset.csv
│       ├── olist_order_reviews_dataset.csv
│       ├── olist_orders_dataset.csv
│       ├── olist_products_dataset.csv
│       ├── olist_sellers_dataset.csv
│       └── product_category_name_translation.csv
│
├── sql/
│   ├── 01_schema.sql
│   ├── 02_data_cleaning.sql
│   ├── 03_sales_analysis.sql
│   ├── 04_customer_analysis.sql
│   ├── 05_product_analysis.sql
│   └── 06_advanced_analysis.sql
│
├── insights/
│   └── business_insights.md
│
└── README.md
```

---

## 🔄 Project Workflow

```text
Raw Dataset
     ↓
Data Understanding
     ↓
Data Cleaning & Validation
     ↓
Database Schema Design
     ↓
Load Data into SQL Database
     ↓
Exploratory SQL Analysis
     ↓
Advanced SQL Analysis
     ↓
Business Insights
     ↓
Recommendations
```

---

## 💡 Expected Outcome

The project aims to demonstrate how SQL can be used to transform raw e-commerce transaction data into meaningful business information.

The final analysis will identify:

* Major sales trends
* High-value customers
* High-performing products and categories
* Customer purchasing patterns
* Revenue growth patterns
* Payment preferences
* Potential areas for business improvement

Actual findings and recommendations will be added after completing the analysis.

---

## 📚 Dataset Source

**Brazilian E-Commerce Public Dataset by Olist**

Dataset available on Kaggle:
https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce

---

## 👨‍💻 Author

**Shivam Kumar**

Aspiring Data Analyst | SQL | Python | Excel | Data Analysis

GitHub: https://github.com/Shivam-codes247


## Data Quality & Assumptions
- Revenue = sum of item price (excl. freight) on orders with status `delivered`.
- Trend analysis covers Jan 2017 – Aug 2018 (first/last months are partial).
- `customer_unique_id` is used for customer counts (99,441 order-level IDs → 96,096 real customers).
- 8 delivered orders lack a delivery date: kept in revenue, excluded from delivery metrics.
- "Late" means delivered on a later calendar date than the estimate. Estimates are midnight timestamps; comparing full timestamps overstated lateness (7,822 vs. 6,531 orders).
- Payment value is approximately item revenue + freight (reconciles within 0.02%); orders paid with several payment types are counted under each type.
- Database used: `postgres` (the database shown by the psql prompt).
- 1,359 orders have carrier pickup before approval: flagged, approval timestamps not used.
- 547 orders have multiple reviews: the latest review per order is used.
- 3 `not_defined` and 6 zero-value voucher payments excluded from payment analysis.
- 610 products lack a category: labeled `unknown`.
