-- ============================================================
-- Retail analytics queries (MySQL 8+). Run schema.sql, seed.sql, then these.
-- Revenue = qty * sell_price ; Margin = qty * (sell_price - cost_price)
-- ============================================================

-- Q1. Total revenue, bills and average bill value (ABV) per store
SELECT s.store_name,
       COUNT(DISTINCT b.bill_id)                                   AS bills,
       ROUND(SUM(l.qty * l.sell_price), 2)                          AS revenue,
       ROUND(SUM(l.qty * l.sell_price) / COUNT(DISTINCT b.bill_id), 2) AS avg_bill_value
FROM bills b
JOIN stores s     ON s.store_id = b.store_id
JOIN sale_lines l ON l.bill_id  = b.bill_id
GROUP BY s.store_name
ORDER BY revenue DESC;

-- Q2. Monthly revenue trend
SELECT DATE_FORMAT(b.bill_date, '%Y-%m') AS month,
       ROUND(SUM(l.qty * l.sell_price), 2) AS revenue
FROM bills b JOIN sale_lines l ON l.bill_id = b.bill_id
GROUP BY DATE_FORMAT(b.bill_date, '%Y-%m')
ORDER BY month;

-- Q3. Month-over-month growth % (window function LAG)
WITH m AS (
  SELECT DATE_FORMAT(b.bill_date, '%Y-%m') AS month,
         SUM(l.qty * l.sell_price) AS revenue
  FROM bills b JOIN sale_lines l ON l.bill_id = b.bill_id
  GROUP BY DATE_FORMAT(b.bill_date, '%Y-%m')
)
SELECT month,
       ROUND(revenue, 2) AS revenue,
       ROUND((revenue - LAG(revenue) OVER (ORDER BY month)) / LAG(revenue) OVER (ORDER BY month) * 100, 1) AS mom_growth_pct
FROM m
ORDER BY month;

-- Q4. Year-over-year revenue by category
SELECT p.category,
       ROUND(SUM(CASE WHEN YEAR(b.bill_date) = 2024 THEN l.qty * l.sell_price ELSE 0 END), 2) AS rev_2024,
       ROUND(SUM(CASE WHEN YEAR(b.bill_date) = 2025 THEN l.qty * l.sell_price ELSE 0 END), 2) AS rev_2025,
       ROUND((SUM(CASE WHEN YEAR(b.bill_date) = 2025 THEN l.qty * l.sell_price ELSE 0 END)
            / NULLIF(SUM(CASE WHEN YEAR(b.bill_date) = 2024 THEN l.qty * l.sell_price ELSE 0 END), 0) - 1) * 100, 1) AS yoy_pct
FROM bills b
JOIN sale_lines l ON l.bill_id = b.bill_id
JOIN products p   ON p.product_id = l.product_id
GROUP BY p.category
ORDER BY rev_2025 DESC;

-- Q5. Gross margin % by category
SELECT p.category,
       ROUND(SUM(l.qty * (l.sell_price - p.cost_price)), 2) AS margin,
       ROUND(SUM(l.qty * (l.sell_price - p.cost_price)) / SUM(l.qty * l.sell_price) * 100, 1) AS margin_pct
FROM sale_lines l JOIN products p ON p.product_id = l.product_id
GROUP BY p.category
ORDER BY margin_pct DESC;

-- Q6. Top 3 products per store by revenue (DENSE_RANK)
WITH r AS (
  SELECT s.store_name, p.name,
         SUM(l.qty * l.sell_price) AS revenue,
         DENSE_RANK() OVER (PARTITION BY s.store_name ORDER BY SUM(l.qty * l.sell_price) DESC) AS rnk
  FROM bills b
  JOIN stores s     ON s.store_id = b.store_id
  JOIN sale_lines l ON l.bill_id  = b.bill_id
  JOIN products p   ON p.product_id = l.product_id
  GROUP BY s.store_name, p.name
)
SELECT store_name, rnk, name, ROUND(revenue, 2) AS revenue
FROM r WHERE rnk <= 3
ORDER BY store_name, rnk;

-- Q7. Products sold below MRP — discount leakage
SELECT p.name,
       SUM(l.qty)                                   AS discounted_units,
       ROUND(SUM(l.qty * (p.mrp - l.sell_price)), 2) AS discount_given
FROM sale_lines l JOIN products p ON p.product_id = l.product_id
WHERE l.sell_price < p.mrp
GROUP BY p.name
ORDER BY discount_given DESC
LIMIT 10;

-- Q8. Payment mode mix per store (% of bills)
SELECT s.store_name, b.payment,
       COUNT(*) AS bills,
       ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (PARTITION BY s.store_name), 1) AS pct_of_store
FROM bills b JOIN stores s ON s.store_id = b.store_id
GROUP BY s.store_name, b.payment
ORDER BY s.store_name, bills DESC;

-- Q9. Basket size: average items and lines per bill
SELECT ROUND(AVG(items), 2) AS avg_items_per_bill,
       ROUND(AVG(line_count), 2) AS avg_lines_per_bill
FROM (SELECT bill_id, SUM(qty) AS items, COUNT(*) AS line_count
      FROM sale_lines GROUP BY bill_id) t;

-- Q10. Running (cumulative) revenue per store within 2025
SELECT s.store_name,
       DATE_FORMAT(b.bill_date, '%Y-%m') AS month,
       ROUND(SUM(l.qty * l.sell_price), 2) AS revenue,
       ROUND(SUM(SUM(l.qty * l.sell_price)) OVER (PARTITION BY s.store_name ORDER BY DATE_FORMAT(b.bill_date, '%Y-%m')), 2) AS running_revenue
FROM bills b
JOIN stores s     ON s.store_id = b.store_id
JOIN sale_lines l ON l.bill_id  = b.bill_id
WHERE YEAR(b.bill_date) = 2025
GROUP BY s.store_name, DATE_FORMAT(b.bill_date, '%Y-%m')
ORDER BY s.store_name, month;

-- Q11. Products with NO sales in the last 60 days of data (dead stock check)
SELECT p.product_id, p.name, p.category
FROM products p
WHERE NOT EXISTS (
  SELECT 1 FROM sale_lines l JOIN bills b ON b.bill_id = l.bill_id
  WHERE l.product_id = p.product_id
    AND b.bill_date >= (SELECT DATE_SUB(MAX(bill_date), INTERVAL 60 DAY) FROM bills)
);

-- Q12. Pareto: categories contributing to 80% of revenue
WITH c AS (
  SELECT p.category, SUM(l.qty * l.sell_price) AS revenue
  FROM sale_lines l JOIN products p ON p.product_id = l.product_id
  GROUP BY p.category
)
SELECT category, ROUND(revenue, 2) AS revenue,
       ROUND(SUM(revenue) OVER (ORDER BY revenue DESC) / SUM(revenue) OVER () * 100, 1) AS cumulative_pct
FROM c
ORDER BY revenue DESC;

-- Q13. Best weekday per store (by revenue)
WITH d AS (
  SELECT s.store_name, DAYNAME(b.bill_date) AS weekday, SUM(l.qty * l.sell_price) AS revenue
  FROM bills b
  JOIN stores s     ON s.store_id = b.store_id
  JOIN sale_lines l ON l.bill_id  = b.bill_id
  GROUP BY s.store_name, DAYNAME(b.bill_date)
)
SELECT store_name, weekday, ROUND(revenue, 2) AS revenue
FROM (SELECT d.*, ROW_NUMBER() OVER (PARTITION BY store_name ORDER BY revenue DESC) AS rn FROM d) x
WHERE rn = 1;

-- Q14. Store revenue vs company average (above / below)
WITH sr AS (
  SELECT b.store_id, SUM(l.qty * l.sell_price) AS revenue
  FROM bills b JOIN sale_lines l ON l.bill_id = b.bill_id
  GROUP BY b.store_id
)
SELECT s.store_name, ROUND(sr.revenue, 2) AS revenue,
       CASE WHEN sr.revenue >= AVG(sr.revenue) OVER () THEN 'Above avg' ELSE 'Below avg' END AS vs_average
FROM sr JOIN stores s ON s.store_id = sr.store_id
ORDER BY revenue DESC;

-- Q15. Products frequently bought together (pairs in the same bill)
SELECT p1.name AS product_a, p2.name AS product_b, COUNT(*) AS bills_together
FROM sale_lines a
JOIN sale_lines b2 ON b2.bill_id = a.bill_id AND b2.product_id > a.product_id
JOIN products p1   ON p1.product_id = a.product_id
JOIN products p2   ON p2.product_id = b2.product_id
GROUP BY p1.name, p2.name
ORDER BY bills_together DESC
LIMIT 10;
