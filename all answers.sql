1.SELECT DISTINCT(market) from dim_customer where customer='Atliq Exclusive' and region= 'APAC';
2.
WITH unique_products AS (
    SELECT 
        fiscal_year, 
        COUNT(DISTINCT Product_code) as unique_products 
    FROM 
        fact_gross_price 
    GROUP BY 
        fiscal_year
)
SELECT 
    up_2020.unique_products as unique_products_2020,
    up_2021.unique_products as unique_products_2021,
    round((up_2021.unique_products - up_2020.unique_products)/up_2020.unique_products * 100,2) as percentage_change
FROM 
    unique_products up_2020
CROSS JOIN 
    unique_products up_2021
WHERE 
    up_2020.fiscal_year = 2020 
    AND up_2021.fiscal_year = 2021;

3.SELECT segment, count(distinct product_code) as product_count
FROM dim_product
GROUP BY segment
ORDER BY product_count DESC

4.-- Step 1: Get 2020 product counts by segment
WITH product_2020 AS (
    SELECT 
        dp.segment, 
        COUNT(DISTINCT fgp.product_code) AS product_count_2020
    FROM 
        fact_gross_price fgp
    JOIN 
        dim_product dp 
        ON fgp.product_code = dp.product_code
    WHERE 
        fgp.fiscal_year = 2020
    GROUP BY 
        dp.segment
),

-- Step 2: Get 2021 product counts by segment
product_2021 AS (
    SELECT 
        dp.segment, 
        COUNT(DISTINCT fgp.product_code) AS product_count_2021
    FROM 
        fact_gross_price fgp
    JOIN 
        dim_product dp 
        ON fgp.product_code = dp.product_code
    WHERE 
        fgp.fiscal_year = 2021
    GROUP BY 
        dp.segment
)

-- Step 3: CROSS JOIN and filter matching segments
SELECT 
    p20.segment,
    p20.product_count_2020,
    p21.product_count_2021,
    p21.product_count_2021 - p20.product_count_2020 AS difference
FROM 
    product_2020 p20
CROSS JOIN 
    product_2021 p21
WHERE 
    p20.segment = p21.segment
ORDER BY 
    difference DESC;

5.WITH ranked_costs AS (
    SELECT 
        p.product_code,
        p.product,
        f.manufacturing_cost,
        RANK() OVER (ORDER BY f.manufacturing_cost ASC) AS lowest_rank,
        RANK() OVER (ORDER BY f.manufacturing_cost DESC) AS highest_rank
    FROM 
        fact_manufacturing_cost f
    JOIN 
        dim_product p 
        ON f.product_code = p.product_code
)
SELECT 
    product_code,
    product,
    manufacturing_cost
FROM 
    ranked_costs
WHERE 
    lowest_rank = 1
    OR highest_rank = 1
ORDER BY
	manufacturing_cost DESC;
6.SELECT 
    s.customer_code,
    c.customer,
    ROUND(AVG(s.pre_invoice_discount_pct), 4) AS average_discount_percentage
FROM 
    fact_pre_invoice_deductions  s
JOIN 
    dim_customer c 
    ON s.customer_code = c.customer_code
WHERE 
    s.fiscal_year = 2021
    AND c.market = 'India'
GROUP BY 
    s.customer_code,
    c.customer
ORDER BY 
    average_discount_percentage DESC
LIMIT 5;
7.WITH temp_table AS (
    SELECT 
        c.customer,
        MONTHNAME(s.date) AS month_name,
        MONTH(s.date) AS month_number,
        YEAR(s.date) AS year,
        (s.sold_quantity * g.gross_price) AS gross_sales
    FROM 
        fact_sales_monthly s
    JOIN 
        fact_gross_price g ON s.product_code = g.product_code
    JOIN 
        dim_customer c ON s.customer_code = c.customer_code
    WHERE 
        c.customer = 'Atliq Exclusive'
)
SELECT 
    month_name AS months,
    year,
    CONCAT(ROUND(SUM(gross_sales)/1000000, 2), 'M') AS gross_sales
FROM 
    temp_table
GROUP BY 
    year, month_number, month_name
ORDER BY 
    year, month_number;

8.WITH Output AS (
  SELECT 
    C.channel,
    ROUND(SUM(G.gross_price * FS.sold_quantity) / 1000000, 2) AS gross_sales_mln
  FROM 
    fact_sales_monthly FS
  JOIN 
    dim_customer C ON FS.customer_code = C.customer_code
  JOIN 
    fact_gross_price G ON FS.product_code = G.product_code
  WHERE 
    FS.fiscal_year = 2021
  GROUP BY 
    C.channel
),
total_sales AS (
  SELECT SUM(gross_sales_mln) AS total FROM Output
)
SELECT 
  o.channel,
  CONCAT(o.gross_sales_mln, ' M') AS gross_sales_mln,
  CONCAT(ROUND(o.gross_sales_mln * 100 / t.total, 2), ' %') AS percentage
FROM 
  Output o
CROSS JOIN 
  total_sales t
ORDER BY 
  o.gross_sales_mln DESC;


SELECT 
CASE
    WHEN date BETWEEN '2019-09-01' AND '2019-11-01' then CONCAT('[Q1] ',MONTHNAME(date))  
    WHEN date BETWEEN '2019-12-01' AND '2020-02-01' then CONCAT('[Q2] ',MONTHNAME(date))
    WHEN date BETWEEN '2020-03-01' AND '2020-05-01' then CONCAT('[Q3] ',MONTHNAME(date))
    WHEN date BETWEEN '2020-06-01' AND '2020-08-01' then CONCAT('[Q4] ',MONTHNAME(date))
    END AS Quarters,
    CONCAT(ROUND(SUM(sold_quantity)/1000000, 2), 'M') AS total_sold_quantity
FROM fact_sales_monthly
WHERE fiscal_year = 2020
GROUP BY Quarters

9.WITH Output AS (
  SELECT 
    C.channel,
    ROUND(SUM(G.gross_price * FS.sold_quantity) / 1000000, 2) AS gross_sales_mln
  FROM 
    fact_sales_monthly FS
  JOIN 
    dim_customer C ON FS.customer_code = C.customer_code
  JOIN 
    fact_gross_price G ON FS.product_code = G.product_code
  WHERE 
    FS.fiscal_year = 2021
  GROUP BY 
    C.channel
),
total_sales AS (
  SELECT SUM(gross_sales_mln) AS total FROM Output
)
SELECT 
  o.channel,
  CONCAT(o.gross_sales_mln, ' M') AS gross_sales_mln,
  CONCAT(ROUND(o.gross_sales_mln * 100 / t.total, 4), ' %') AS percentage
FROM 
  Output o
CROSS JOIN 
  total_sales t
ORDER BY 
  o.gross_sales_mln DESC;
10.WITH ranked_products AS (
  SELECT
    p.division,
    p.product_code,
    CONCAT(p.product, ' [', p.variant, ']') AS product,
    SUM(s.sold_quantity) AS total_sold_quantity,
    RANK() OVER (
      PARTITION BY p.division 
      ORDER BY SUM(s.sold_quantity) DESC
    ) AS rank_order
  FROM 
    fact_sales_monthly s
  JOIN 
    dim_product p ON s.product_code = p.product_code
  WHERE 
    s.fiscal_year = 2021
  GROUP BY 
    p.division,
    p.product_code,
    CONCAT(p.product, ' [', p.variant, ']')
)
SELECT 
  division,
  product_code,
  product,
  total_sold_quantity,
  rank_order
FROM 
  ranked_products
WHERE 
  rank_order <= 3
ORDER BY 
  division,
  rank_order;
