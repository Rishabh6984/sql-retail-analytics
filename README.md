# 🛒 SQL Retail Analytics

A small **supermarket data model** with ~2 years of demo bills and **15 analytical SQL queries** — the
questions an MIS team answers every week: store performance, MoM / YoY growth, margins, discount
leakage, payment mix, basket size, dead stock and product affinity.

## Data model

```
stores (store_id, store_name, city, opened_on)
products (product_id, name, category, cost_price, mrp)
bills (bill_id, store_id → stores, bill_date, payment)
sale_lines (bill_id → bills, product_id → products, qty, sell_price)
```
3 stores · 20 products · 6 categories · ~2,100 bills · ~6,500 sale lines (2024–2025)

## Queries (`queries.sql`)

| # | Question | Concepts |
|---|---|---|
| 1 | Revenue, bills & average bill value per store | JOIN, GROUP BY |
| 2 | Monthly revenue trend | DATE_FORMAT |
| 3 | Month-over-month growth % | CTE, `LAG()` |
| 4 | Year-over-year revenue by category | conditional aggregation |
| 5 | Gross margin % by category | derived metrics |
| 6 | Top 3 products per store | `DENSE_RANK() OVER (PARTITION BY …)` |
| 7 | Discount leakage (sold below MRP) | filtering + aggregation |
| 8 | Payment mode mix per store | window over aggregate |
| 9 | Basket size (items / lines per bill) | subquery |
| 10 | Running revenue per store | cumulative `SUM() OVER` |
| 11 | Dead stock — no sales in last 60 days | `NOT EXISTS`, `DATE_SUB` |
| 12 | Pareto: categories making 80% of revenue | cumulative % |
| 13 | Best weekday per store | `ROW_NUMBER()` |
| 14 | Store vs company average | `AVG() OVER ()` |
| 15 | Products bought together | self-join (market basket) |

## Run it (MySQL 8+)

```bash
mysql -u root -p -e "CREATE DATABASE retail; USE retail; SOURCE schema.sql; SOURCE seed.sql;"
mysql -u root -p retail < queries.sql
```
Works in MySQL Workbench too: open each file and run.

## Tech
MySQL 8 · CTEs · window functions · joins · conditional aggregation
