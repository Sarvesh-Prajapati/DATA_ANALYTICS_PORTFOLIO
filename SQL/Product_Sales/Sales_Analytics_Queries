
-- 1. Find the dataset's shape (# of rows, # of columns)
SELECT
	'# Records' AS Info
	, FORMAT(COUNT(*), 0) AS 'Value' 
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
UNION ALL
SELECT '# Attributes', (SELECT MAX(ORDINAL_POSITION) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'products') + ((SELECT MAX(ORDINAL_POSITION) FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_NAME = 'sales') ) ;
+--------------+--------+
| Info         | Value  |
+--------------+--------+
| # Records    | 60,398 |
| # Attributes | 20     |
+--------------+--------+

-- 2. Remove the leading & trailing spaces around the hyphen in values of column 'product_name'
SELECT REGEXP_REPLACE(product_name, "\\s*-\\s*", '-') AS product_name FROM products;  -- first 5 records shown below
-- REPLACE (as in query ahead) performs only literal, fixed-string substitutions. It cannot match variable whitespaces.
-- SELECT REPLACE(REPLACE(product_name, ' -', '-'), '- ', '-') AS product_name  -- handles only single leading/trailing space (or as many instances of spaces as will be specified)
-- FROM products;
+---------------------------+------------------------+
| product_name              | product_name           |
+---------------------------+------------------------+
| HL Road Frame - Black- 58 | HL Road Frame-Black-58 |
| HL Road Frame - Red- 58   | HL Road Frame-Red-58   |
| Mountain-100 Black- 38    | Mountain-100 Black-38  |
| Mountain-100 Black- 42    | Mountain-100 Black-42  |
| Mountain-100 Black- 44    | Mountain-100 Black-44  |
+---------------------------+------------------------+

-- 3. Shift the 'price' column beside 'due_date' and then 'quantity' column beside 'price' column
SELECT * FROM datawarehouse.sales;                         -- check column order
ALTER TABLE sales MODIFY COLUMN price INT AFTER due_date;  -- shift column
SELECT * FROM sales;                                       -- check column order again
ALTER TABLE sales MODIFY COLUMN quantity INT AFTER price;  -- shift column
SELECT * FROM sales;                                       -- check column order again (columns will be found re-ordered)

-- 4. In 'products' table, fetch details of all red-colored products (product 'Taillights - Battery-Powered' shouldn't be in o/p even though it has 'red' in it)
SELECT product_name FROM products WHERE product_name REGEXP "^.*Red.*" COLLATE utf8mb4_bin; -- COLLATE makes comparison case-sensitive, 'product_name' having 'Tailored' is not returned
SELECT product_name FROM products WHERE product_name LIKE "%Red%" COLLATE utf8mb4_bin;

-- ----------------------------------------
-- 5. Count the number of NULL/NA values in each column of table products
SELECT 'p_product_key' AS 'Column_Header', SUM(CASE WHEN p_product_key IS NULL OR p_product_key = 'NA' THEN 1 ELSE 0 END) AS NULLS_Count FROM products UNION ALL
SELECT 'product_id', SUM(CASE WHEN product_id IS NULL OR product_id = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'product_number', SUM(CASE WHEN product_number IS NULL OR product_number = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'product_name', SUM(CASE WHEN product_name IS NULL OR product_name = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'category_id', SUM(CASE WHEN category_id IS NULL OR category_id = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'category', SUM(CASE WHEN category IS NULL OR category = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'subcategory', SUM(CASE WHEN subcategory IS NULL OR subcategory = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'maintenance', SUM(CASE WHEN maintenance IS NULL OR maintenance = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'cost', SUM(CASE WHEN cost IS NULL OR cost = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'product_line', SUM(CASE WHEN product_line IS NULL OR product_line = 'NA' THEN 1 ELSE 0 END) FROM products UNION ALL
SELECT 'start_date', SUM(CASE WHEN start_date IS NULL THEN 1 ELSE 0 END) FROM products 
ORDER BY NULLS_Count DESC;

-- A dynamic query can be written which will generate the above statements (except the ORDER BY at the end) for copy-paste-run
SET SESSION group_concat_max_len = 10000;  -- otherwise GROUP_CONCAT's result in output will be limited to first 1024 bytes
SELECT GROUP_CONCAT(
  CONCAT(
    "SELECT ", COLUMN_NAME, " AS column_name, ",
    "SUM(CASE WHEN ", COLUMN_NAME, " IS NULL OR ", COLUMN_NAME, " = 'NA' THEN 1 ELSE 0 END) AS null_na_count ",
    "FROM products"
  )
  SEPARATOR " UNION ALL\n"
) AS generated_sql
FROM INFORMATION_SCHEMA.COLUMNS
WHERE LOWER(TABLE_NAME) = 'products' AND TABLE_SCHEMA = 'datawarehouse';
+----------------+-------------+
| Column_Header  | NULLS_Count |
+----------------+-------------+
| product_line   |          17 |
| category       |           7 |
| subcategory    |           7 |
| maintenance    |           7 |
| cost           |           2 |
| p_product_key  |           0 |
| product_id     |           0 |
| product_number |           0 |
| product_name   |           0 |
| category_id    |           0 |
| start_date     |           0 |
+----------------+-------------+

-- ------------------------------------------

-- 6. Fetch those dates of the calendar on which there was zero sales.
SELECT MIN(order_date), MAX(order_date) FROM sales INTO @min_dt, @max_dt;  -- 2010-12-29,  2014-01-28
SET @@cte_max_recursion_depth = 1500;
WITH RECURSIVE CTE_Dates AS (
    SELECT DATE(@min_dt) AS daily_date
    UNION ALL
    SELECT daily_date + INTERVAL 1 DAY FROM CTE_Dates
    WHERE daily_date < @max_dt
) 
SELECT
	daily_date AS zero_sales_dates
FROM CTE_Dates d LEFT JOIN sales s ON d.daily_date = s.order_date
WHERE s.order_date IS NULL;
-- ---------- Date range as a temporary table (CTE expires with query run; temp table remains till session end (or dropped) so can be queried by many SELECTs)
-- CREATE TEMPORARY TABLE date_range AS
-- WITH RECURSIVE CTE_Dates AS (
--     SELECT DATE(@min_dt) AS daily_date
--     UNION ALL
--     SELECT daily_date + INTERVAL 1 DAY FROM CTE_Dates
--     WHERE daily_date < @max_dt
-- ) SELECT * FROM CTE_Dates;
-- DROP TEMPORARY TABLE IF EXISTS date_range;  -- Keyword TEMPORARY is optional, makes intent clear though
+------------------+
| zero_sales_dates |
+------------------+
| 2011-02-13       |
| 2011-04-23       |
| 2011-03-11       |
+------------------+

-- 7. Which category hasn't been classified into any of the product lines?
SELECT DISTINCT category FROM products WHERE product_line = 'NA' ;
+------------+
| category   |
+------------+
| Components |
+------------+

-- 8. Range of sales for each sub-category during 2013
SELECT
	subcategory
	, FORMAT(MIN(sales_amount), 2) AS min_sales_amt
	, FORMAT(MAX(sales_amount), 2) AS max_sales_amt
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE YEAR(order_date) = 2013
GROUP BY subcategory ;
+-------------------+---------------+---------------+
| subcategory       | min_sales_amt | max_sales_amt |
+-------------------+---------------+---------------+
| Mountain Bikes    | 540.00        | 2,320.00      |
| Bottles and Cages | 0.00          | 10.00         |
| Road Bikes        | 540.00        | 2,443.00      |
| Jerseys           | 50.00         | 100.00        |
| Tires and Tubes   | 2.00          | 75.00         |
| Cleaners          | 0.00          | 8.00          |
| Helmets           | 0.00          | 35.00         |
| Gloves            | 24.00         | 24.00         |
| Fenders           | 22.00         | 22.00         |
| Touring Bikes     | 742.00        | 2,384.00      |
| Caps              | 9.00          | 9.00          |
| Vests             | 64.00         | 256.00        |
| Hydration Packs   | 55.00         | 55.00         |
| Socks             | 9.00          | 9.00          |
| Bike Racks        | 120.00        | 120.00        |
| Shorts            | 70.00         | 70.00         |
| Bike Stands       | 159.00        | 159.00        |
+-------------------+---------------+---------------+

-- 9. Rolling average sales of each category (window: 2 previous months and current month)
WITH CTE_Monthly_Sales AS (
SELECT
	DISTINCT category, MONTH(order_date) AS 'Month', ROUND(SUM(sales_amount), 2) AS sales
FROM products p LEFT JOIN sales s ON p.p_product_key = s.s_product_key
WHERE category IS NOT NULL AND order_date IS NOT NULL
GROUP BY category, MONTH(order_date)
ORDER BY category, 'Month'
)
SELECT *
	, ROUND(AVG(sales) OVER(PARTITION BY category ORDER BY 'Month' ROWS BETWEEN 2 PRECEDING AND CURRENT ROW), 2) AS prev_3_months_avg_sales
FROM CTE_Monthly_Sales ;
+-------------+-------+---------+-------------------------+
| category    | Month | sales   | prev_3_months_avg_sales |
+-------------+-------+---------+-------------------------+
| Accessories |     1 |   49275 |                49275.00 |
| Accessories |     2 |   46186 |                47730.50 |
| Accessories |     3 |   55280 |                50247.00 |
| Accessories |     4 |   51661 |                51042.33 |
| Accessories |     5 |   57854 |                54931.67 |
| Accessories |     6 |   62459 |                57324.67 |
| Accessories |     7 |   57944 |                59419.00 |
| Accessories |     8 |   59355 |                59919.33 |
| Accessories |     9 |   58466 |                58588.33 |
| Accessories |    10 |   66103 |                61308.00 |
| Accessories |    11 |   67198 |                63922.33 |
| Accessories |    12 |   67863 |                67054.67 |
| Bikes       |     1 | 1795001 |              1795001.00 |
| Bikes       |     2 | 1677034 |              1736017.50 |
| Bikes       |     3 | 1826336 |              1766123.67 |
| Bikes       |     4 | 1871194 |              1791521.33 |
| Bikes       |     5 | 2120578 |              1939369.33 |
| Bikes       |     6 | 2844032 |              2278601.33 |
| Bikes       |     7 | 2325334 |              2429981.33 |
| Bikes       |     8 | 2595180 |              2588182.00 |
| Bikes       |     9 | 2450441 |              2456985.00 |
| Bikes       |    10 | 2816603 |              2620741.33 |
| Bikes       |    11 | 2881799 |              2716281.00 |
| Bikes       |    12 | 3108125 |              2935509.00 |
| Clothing    |     1 |   24033 |                24033.00 |
| Clothing    |     2 |   21281 |                22657.00 |
| Clothing    |     3 |   26759 |                24024.33 |
| Clothing    |     4 |   25371 |                24470.33 |
| Clothing    |     5 |   26537 |                26222.33 |
| Clothing    |     6 |   29392 |                27100.00 |
| Clothing    |     7 |   29560 |                28496.33 |
| Clothing    |     8 |   29778 |                29576.67 |
| Clothing    |     9 |   27613 |                28983.67 |
| Clothing    |    10 |   33844 |                30411.67 |
| Clothing    |    11 |   30116 |                30524.33 |
| Clothing    |    12 |   35408 |                33122.67 |
+-------------+-------+---------+-------------------------+

-- 10. Count of mountain bikes and road bikes ordered from Apr 2012 till Mar 2013.
SELECT
	subcategory AS Subcategory
	, COUNT(*) AS Units
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE subcategory IN ('Road Bikes', 'Mountain Bikes') AND order_date BETWEEN '2012-04-01' AND '2013-03-31'
GROUP BY subcategory ;
+----------------+-------+
| Subcategory    | Units |
+----------------+-------+
| Road Bikes     |  2316 |
| Mountain Bikes |  1499 |
+----------------+-------+

-- 11. Cumulative sales of products over all the months of 2011 and 2012.
WITH CTE_Monthly_Sales AS (
SELECT
	YEAR(order_date) AS order_year, product_number, product_name, MONTH(order_date) AS 'Month', SUM(sales_amount) AS sales
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE order_date IS NOT NULL AND YEAR(order_date) IN (2011, 2012)
GROUP BY YEAR(order_date), product_number, product_name, MONTH(order_date)
ORDER BY sales DESC 
)
SELECT *
	, SUM(sales) OVER(PARTITION BY order_year, product_name ORDER BY order_year, Month) AS cumulative_sales
FROM CTE_Monthly_Sales ;
-- Showing first 5 records:
+------------+----------------+------------------------+-------+-------+------------------+
| order_year | product_number | product_name           | Month | sales | cumulative_sales |
+------------+----------------+------------------------+-------+-------+------------------+
|       2011 | BK-M82B-38     | Mountain-100 Black- 38 |     1 | 10125 |            10125 |
|       2011 | BK-M82B-38     | Mountain-100 Black- 38 |     2 | 10125 |            20250 |
|       2011 | BK-M82B-38     | Mountain-100 Black- 38 |     3 |  3375 |            23625 |
|       2011 | BK-M82B-38     | Mountain-100 Black- 38 |     4 |  6750 |            30375 |
|       2011 | BK-M82B-38     | Mountain-100 Black- 38 |     5 | 13500 |            43875 |
+------------+----------------+------------------------+-------+-------+------------------+

-- 12. Which red-colored products were never sold ?
SELECT 
	product_id, product_number, product_name, order_date, sales_amount
FROM products p LEFT JOIN sales s ON p.p_product_key = s.s_product_key
WHERE product_name LIKE '% Red%' AND sales_amount IS NULL
ORDER BY product_id ;
+------------+----------------+-------------------------+------------+--------------+
| product_id | product_number | product_name            | order_date | sales_amount |
+------------+----------------+-------------------------+------------+--------------+
|        211 | FR-R92R-58     | HL Road Frame - Red- 58 | NULL       |         NULL |
|        240 | FR-R92R-62     | HL Road Frame - Red- 62 | NULL       |         NULL |
|        243 | FR-R92R-44     | HL Road Frame - Red- 44 | NULL       |         NULL |
|        246 | FR-R92R-48     | HL Road Frame - Red- 48 | NULL       |         NULL |
|        249 | FR-R92R-52     | HL Road Frame - Red- 52 | NULL       |         NULL |
|        252 | FR-R92R-56     | HL Road Frame - Red- 56 | NULL       |         NULL |
|        263 | FR-R38R-44     | LL Road Frame - Red- 44 | NULL       |         NULL |
|        265 | FR-R38R-48     | LL Road Frame - Red- 48 | NULL       |         NULL |
|        267 | FR-R38R-52     | LL Road Frame - Red- 52 | NULL       |         NULL |
|        269 | FR-R38R-58     | LL Road Frame - Red- 58 | NULL       |         NULL |
|        271 | FR-R38R-60     | LL Road Frame - Red- 60 | NULL       |         NULL |
|        273 | FR-R38R-62     | LL Road Frame - Red- 62 | NULL       |         NULL |
|        274 | FR-R72R-44     | ML Road Frame - Red- 44 | NULL       |         NULL |
|        275 | FR-R72R-48     | ML Road Frame - Red- 48 | NULL       |         NULL |
|        276 | FR-R72R-52     | ML Road Frame - Red- 52 | NULL       |         NULL |
|        277 | FR-R72R-58     | ML Road Frame - Red- 58 | NULL       |         NULL |
|        278 | FR-R72R-60     | ML Road Frame - Red- 60 | NULL       |         NULL |
|        315 | BK-R68R-58     | Road-450 Red- 58        | NULL       |         NULL |
|        316 | BK-R68R-60     | Road-450 Red- 60        | NULL       |         NULL |
|        317 | BK-R68R-44     | Road-450 Red- 44        | NULL       |         NULL |
|        318 | BK-R68R-48     | Road-450 Red- 48        | NULL       |         NULL |
|        319 | BK-R68R-52     | Road-450 Red- 52        | NULL       |         NULL |
+------------+----------------+-------------------------+------------+--------------+

-- 13. List the subcategories of each category
SELECT
	DISTINCT category AS Categories
	, GROUP_CONCAT(DISTINCT subcategory SEPARATOR ', ') AS Subcategories
FROM products WHERE category IS NOT NULL
GROUP BY category ;
+-------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
| Categories  | Subcategories                                                                                                                                       |
+-------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+
| Accessories | Bike Racks, Bike Stands, Bottles and Cages, Cleaners, Fenders, Helmets, Hydration Packs, Lights, Locks, Panniers, Pumps, Tires and Tubes            |
| Bikes       | Mountain Bikes, Road Bikes, Touring Bikes                                                                                                           |
| Clothing    | Bib-Shorts, Caps, Gloves, Jerseys, Shorts, Socks, Tights, Vests                                                                                     |
| Components  | Bottom Brackets, Brakes, Chains, Cranksets, Derailleurs, Forks, Handlebars, Headsets, Mountain Frames, Road Frames, Saddles, Touring Frames, Wheels |
+-------------+-----------------------------------------------------------------------------------------------------------------------------------------------------+

-- 14. Percentage contribution of each category's sales to overall sales
WITH CTE_Category_Sales AS (
SELECT
    category
    , COALESCE(ROUND(SUM(sales_amount), 2), 0.00) AS sales
FROM products p LEFT JOIN sales s ON p.p_product_key = s.s_product_key
WHERE category IS NOT NULL
GROUP BY category
)
SELECT 
    category
    , FORMAT(sales, 2) AS sales
    , FORMAT(SUM(sales) OVER(), 2) AS overall_sales
    , CONCAT(ROUND(sales/SUM(sales) OVER() * 100, 1), '%') AS '%_of_overall_sales'
FROM CTE_Category_Sales ;
+-------------+---------------+---------------+--------------------+
| category    | sales         | overall_sales | %_of_overall_sales |
+-------------+---------------+---------------+--------------------+
| Bikes       | 28,316,272.00 | 29,355,985.00 | 96.5%              |
| Accessories | 699,997.00    | 29,355,985.00 | 2.4%               |
| Clothing    | 339,716.00    | 29,355,985.00 | 1.2%               |
| Components  | 0.00          | 29,355,985.00 | 0.0%               |
+-------------+---------------+---------------+--------------------+

-- 15. Average price for each product line in 2012
WITH CTE_avg_price AS (
	SELECT
		product_line, price
	FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
	WHERE YEAR(order_date) = 2012
) 
SELECT
	product_line
	, ROUND(AVG(price), 2) AS line_2012_avg_price
FROM CTE_avg_price
GROUP BY product_line ;
+--------------+---------------------+
| product_line | line_2012_avg_price |
+--------------+---------------------+
| Road         |             1625.66 |
| Mountain     |             2015.77 |
| Touring      |             1262.24 |
| Other Sales  |               24.89 |
+--------------+---------------------+

-- 16. Lowest revenue generating subcategory for each category for last quarter of 2013
WITH CTE_lowest_revenue AS (
SELECT
	p.category
	, p.subcategory
        , SUM(sales_amount) AS total_sales
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE QUARTER(order_date) = 4
GROUP BY p.category, p.subcategory
ORDER BY category
)
SELECT
	category
	, subcategory
FROM (
		SELECT *
			, DENSE_RANK() OVER(PARTITION BY category ORDER BY total_sales ASC) AS rnk
		FROM CTE_lowest_revenue
) temp
WHERE rnk = 1 ;
+-------------+---------------+
| category    | subcategory   |
+-------------+---------------+
| Accessories | Cleaners      |
| Bikes       | Touring Bikes |
| Clothing    | Socks         |
+-------------+---------------+

-- 17. Net sales on weekends during the years 2011, 2012 and 2013?
SELECT
	order_year, FORMAT(SUM(total_sales), 2) AS net_weekend_sales
FROM (
	SELECT
		YEAR(s.order_date) AS order_year
		, WEEKDAY(s.order_date) AS order_weekday   -- Monday: 0, Sunday: 6
		, DAYNAME(s.order_date) AS order_dayname
		, SUM(s.sales_amount) AS total_sales
	FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
	WHERE YEAR(s.order_date) IN (2011, 2012, 2013) AND DAYNAME(s.order_date) IN ('Saturday', 'Sunday')
	GROUP BY YEAR(s.order_date), WEEKDAY(s.order_date), DAYNAME(s.order_date)
	) temp 
GROUP BY order_year ;
+------------+-------------------+
| order_year | net_weekend_sales |
+------------+-------------------+
|       2011 | 2,063,746.00      |
|       2012 | 1,743,293.00      |
|       2013 | 4,416,966.00      |
+------------+-------------------+

-- 18. Each sub-category's annual sales, prev year sales, sales difference from prev year, sales change factor
WITH CTE_Annual_Sales AS (
SELECT
	DISTINCT YEAR(order_date) AS order_year
	, subcategory
        , SUM(sales_amount) OVER(PARTITION BY subcategory ORDER BY YEAR(order_date)) AS sales_annual
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE subcategory LIKE '%Bikes%' AND order_date IS NOT NULL 
)
SELECT
    order_year AS 'year'
    , subcategory
    , FORMAT(sales_annual, 2) AS sales_annual
    , FORMAT(LAG(sales_annual) OVER(PARTITION BY subcategory ORDER BY order_year), 2) AS sales_prev_year
    , FORMAT(sales_annual - LAG(sales_annual) OVER(PARTITION BY subcategory ORDER BY order_year), 2) AS sales_diff
    , ROUND((sales_annual - LAG(sales_annual) OVER(PARTITION BY subcategory ORDER BY order_year))/LAG(sales_annual) OVER(PARTITION BY subcategory ORDER BY order_year), 1) AS sales_growth_factor
FROM CTE_Annual_Sales ;
+------+----------------+---------------+-----------------+--------------+---------------------+
| year | subcategory    | sales_annual  | sales_prev_year | sales_diff   | sales_growth_factor |
+------+----------------+---------------+-----------------+--------------+---------------------+
| 2010 | Mountain Bikes | 16,975.00     | NULL            | NULL         |                NULL |
| 2011 | Mountain Bikes | 1,349,343.00  | 16,975.00       | 1,332,368.00 |                78.5 |
| 2012 | Mountain Bikes | 3,612,491.00  | 1,349,343.00    | 2,263,148.00 |                 1.7 |
| 2013 | Mountain Bikes | 9,947,639.00  | 3,612,491.00    | 6,335,148.00 |                 1.8 |
| 2010 | Road Bikes     | 26,444.00     | NULL            | NULL         |                NULL |
| 2011 | Road Bikes     | 5,769,164.00  | 26,444.00       | 5,742,720.00 |               217.2 |
| 2012 | Road Bikes     | 9,324,069.00  | 5,769,164.00    | 3,554,905.00 |                 0.6 |
| 2013 | Road Bikes     | 14,519,438.00 | 9,324,069.00    | 5,195,369.00 |                 0.6 |
| 2012 | Touring Bikes  | 21,390.00     | NULL            | NULL         |                NULL |
| 2013 | Touring Bikes  | 3,844,580.00  | 21,390.00       | 3,823,190.00 |               178.7 |
+------+----------------+---------------+-----------------+--------------+---------------------+

-- 19. How many categories do not belong to any product line?
-- SELECT * FROM products where product_line = 'NA';  -- 17 records
SELECT
	COUNT(DISTINCT category) AS cat_sans_prod_line
FROM products WHERE product_line = 'NA' ;  -- 1  (only 'Components' category)
+--------------------+
| cat_sans_prod_line |
+--------------------+
|                  1 |
+--------------------+

-- 20. Fetch the details of the products that remained unsold over the years
SELECT * FROM products WHERE p_product_key NOT IN (SELECT s_product_key FROM sales) ;   -- 165 rows
-- Here are the first 5 records as examples:
+---------------+------------+----------------+---------------------------+-------------+------------+-------------+-------------+------+--------------+------------+
| p_product_key | product_id | product_number | product_name              | category_id | category   | subcategory | maintenance | cost | product_line | start_date |
+---------------+------------+----------------+---------------------------+-------------+------------+-------------+-------------+------+--------------+------------+
|             1 |        210 | FR-R92B-58     | HL Road Frame - Black- 58 | CO_RF       | Components | Road Frames | Yes         |    0 | Road         | 2003-07-01 |
|             2 |        211 | FR-R92R-58     | HL Road Frame - Red- 58   | CO_RF       | Components | Road Frames | Yes         |    0 | Road         | 2003-07-01 |
|            11 |        317 | BK-R68R-44     | Road-450 Red- 44          | BI_RB       | Bikes      | Road Bikes  | Yes         |  885 | Road         | 2011-07-01 |
|            12 |        318 | BK-R68R-48     | Road-450 Red- 48          | BI_RB       | Bikes      | Road Bikes  | Yes         |  885 | Road         | 2011-07-01 |
|            13 |        319 | BK-R68R-52     | Road-450 Red- 52          | BI_RB       | Bikes      | Road Bikes  | Yes         |  885 | Road         | 2011-07-01 |
+---------------+------------+----------------+---------------------------+-------------+------------+-------------+-------------+------+--------------+------------+

-- 21. Which subcategories that went unsold between January 01, 2011 and December 31, 2013 ?
SELECT 
	COUNT(DISTINCT subcategory) AS '# Unsold', GROUP_CONCAT(DISTINCT subcategory SEPARATOR ', ') AS 'Unsold SubCategories' 
FROM products
WHERE subcategory NOT IN ( 
SELECT
	DISTINCT subcategory
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE order_date BETWEEN '2011-01-01' AND '2013-12-31') ;
+----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
| # Unsold | Unsold SubCategories                                                                                                                                                                                    |
+----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+
|       19 | Bib-Shorts, Bottom Brackets, Brakes, Chains, Cranksets, Derailleurs, Forks, Handlebars, Headsets, Lights, Locks, Mountain Frames, Panniers, Pumps, Road Frames, Saddles, Tights, Touring Frames, Wheels |
+----------+---------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+

-- 22. Find the sales of S, M, L or XL-sleeved clothing over the years
WITH CTE_Sleeved_Sales AS (
	SELECT
		product_name
		, sales_amount
		, order_date
	FROM products p LEFT JOIN sales s ON p.p_product_key = s.s_product_key
	WHERE product_name LIKE '%Sleeve%'
)
SELECT 
    DISTINCT product_name AS Product
    , FORMAT(SUM(CASE WHEN YEAR(order_date) = 2012 THEN sales_amount ELSE 0 END), 2) AS '2012_Sales'
    , FORMAT(SUM(CASE WHEN YEAR(order_date) = 2013 THEN sales_amount ELSE 0 END), 2) AS '2013_Sales'
    , FORMAT(SUM(CASE WHEN YEAR(order_date) = 2014 THEN sales_amount ELSE 0 END), 2) AS '2014_Sales'
FROM CTE_Sleeved_Sales
GROUP BY product_name
ORDER BY Product ;
+---------------------------------+------------+------------+------------+
| Product                         | 2012_Sales | 2013_Sales | 2014_Sales |
+---------------------------------+------------+------------+------------+
| Long-Sleeve Logo Jersey- L      | 150.00     | 21,550.00  | 950.00     |
| Long-Sleeve Logo Jersey- M      | 50.00      | 20,850.00  | 1,200.00   |
| Long-Sleeve Logo Jersey- S      | 0.00       | 20,350.00  | 1,100.00   |
| Long-Sleeve Logo Jersey- XL     | 0.00       | 19,850.00  | 850.00     |
| Short-Sleeve Classic Jersey- L  | 108.00     | 19,764.00  | 324.00     |
| Short-Sleeve Classic Jersey- M  | 54.00      | 20,790.00  | 1,134.00   |
| Short-Sleeve Classic Jersey- S  | 54.00      | 21,384.00  | 486.00     |
| Short-Sleeve Classic Jersey- XL | 0.00       | 21,168.00  | 918.00     |
+---------------------------------+------------+------------+------------+

-- 23. Quantities of subcategories ordered in each month during 2013
SELECT
    subcategory AS 'Sub-Cat_Ordered'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'January' THEN 1 ELSE 0 END) AS 'Jan #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'February' THEN 1 ELSE 0 END) AS 'Feb #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'March' THEN 1 ELSE 0 END) AS 'Mar #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'April' THEN 1 ELSE 0 END) AS 'Apr #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'May' THEN 1 ELSE 0 END) AS 'May #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'June' THEN 1 ELSE 0 END) AS 'Jun #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'July' THEN 1 ELSE 0 END) AS 'Jul #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'August' THEN 1 ELSE 0 END) AS 'Aug #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'September' THEN 1 ELSE 0 END) AS 'Sep #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'October' THEN 1 ELSE 0 END) AS 'Oct #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'November' THEN 1 ELSE 0 END) AS 'Nov #'
    , SUM(CASE WHEN MONTHNAME(order_date) = 'December' THEN 1 ELSE 0 END) AS 'Dec #'
FROM sales s
LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE YEAR(order_date) = 2013
GROUP BY subcategory
ORDER BY subcategory ;
+-------------------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
| Sub-Cat_Ordered   | Jan # | Feb # | Mar # | Apr # | May # | Jun # | Jul # | Aug # | Sep # | Oct # | Nov # | Dec # |
+-------------------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+
| Bike Racks        |    13 |    21 |    35 |    18 |    25 |    26 |    20 |    25 |    27 |    28 |    38 |    31 |
| Bike Stands       |     8 |    16 |    20 |    26 |    24 |    24 |    17 |    18 |    18 |    31 |    23 |    12 |
| Bottles and Cages |   270 |   491 |   567 |   563 |   602 |   766 |   672 |   759 |   711 |   777 |   728 |   811 |
| Caps              |    62 |   149 |   160 |   149 |   163 |   198 |   183 |   215 |   193 |   200 |   192 |   235 |
| Cleaners          |    30 |    60 |    73 |    68 |    69 |    84 |    94 |    77 |    61 |    70 |    88 |    95 |
| Fenders           |    65 |   135 |   151 |   169 |   170 |   192 |   201 |   163 |   166 |   193 |   210 |   207 |
| Gloves            |    35 |    88 |   115 |   109 |   109 |   122 |   120 |   134 |    96 |   142 |   144 |   148 |
| Helmets           |   165 |   417 |   478 |   447 |   523 |   602 |   514 |   548 |   559 |   621 |   651 |   648 |
| Hydration Packs   |    26 |    43 |    64 |    56 |    56 |    58 |    64 |    70 |    67 |    55 |    70 |    79 |
| Jerseys           |    98 |   200 |   261 |   235 |   259 |   300 |   302 |   286 |   276 |   315 |   307 |   350 |
| Mountain Bikes    |   190 |   152 |   222 |   208 |   260 |   350 |   293 |   316 |   310 |   351 |   397 |   421 |
| Road Bikes        |   225 |   220 |   274 |   262 |   322 |   416 |   314 |   373 |   353 |   427 |   442 |   452 |
| Shorts            |    13 |    76 |    95 |    84 |    82 |    87 |    78 |    85 |    79 |   108 |    75 |   101 |
| Socks             |     7 |    44 |    47 |    48 |    52 |    48 |    53 |    49 |    42 |    50 |    48 |    53 |
| Tires and Tubes   |   354 |  1232 |  1383 |  1358 |  1472 |  1474 |  1504 |  1471 |  1398 |  1628 |  1523 |  1563 |
| Touring Bikes     |    82 |    82 |   112 |   134 |   167 |   238 |   190 |   206 |   207 |   238 |   236 |   262 |
| Vests             |    19 |    27 |    30 |    45 |    44 |    40 |    52 |    53 |    53 |    64 |    52 |    52 |
+-------------------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+-------+

-- 24. Find the top-5 product names by average sales in each category for the year 2013 (if more than one product name in top-5 have same avg sales, include all of them)
WITH CTE_Avg_Sales AS (
	SELECT
		category
		, product_name
	    , ROUND(AVG(sales_amount), 2) AS avg_sales
	FROM products p LEFT JOIN sales s ON p.p_product_key = s.s_product_key
	WHERE YEAR(order_date) = 2013
	GROUP BY 1, 2 
	ORDER BY category, avg_sales DESC 
),
CTE_Ranking AS (
	SELECT *
		, DENSE_RANK() OVER(PARTITION BY category ORDER BY avg_sales DESC) AS avg_sales_rank
	FROM CTE_Avg_Sales
)
SELECT
    category
    , GROUP_CONCAT(DISTINCT product_name SEPARATOR ', ') AS same_rank_products
    , avg_sales_rank AS 'rank'
FROM CTE_Ranking
WHERE avg_sales_rank BETWEEN 1 AND 5 
GROUP BY category, avg_sales_rank ;
+-------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+------+
| category    | same_rank_products                                                                                                                                                                             | rank |
+-------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+------+
| Accessories | All-Purpose Bike Stand                                                                                                                                                                         |    1 |
| Accessories | Hitch Rack - 4-Bike                                                                                                                                                                            |    2 |
| Accessories | Hydration Pack - 70 oz.                                                                                                                                                                        |    3 |
| Accessories | HL Mountain Tire                                                                                                                                                                               |    4 |
| Accessories | Sport-100 Helmet- Red                                                                                                                                                                          |    5 |
| Bikes       | Road-250 Black- 44, Road-250 Black- 48, Road-250 Black- 52, Road-250 Black- 58, Road-250 Red- 58                                                                                               |    1 |
| Bikes       | Touring-1000 Blue- 46, Touring-1000 Blue- 50, Touring-1000 Blue- 54, Touring-1000 Blue- 60, Touring-1000 Yellow- 46, Touring-1000 Yellow- 50, Touring-1000 Yellow- 54, Touring-1000 Yellow- 60 |    2 |
| Bikes       | Mountain-200 Silver- 38, Mountain-200 Silver- 42, Mountain-200 Silver- 46                                                                                                                      |    3 |
| Bikes       | Mountain-200 Black- 38, Mountain-200 Black- 42, Mountain-200 Black- 46                                                                                                                         |    4 |
| Bikes       | Road-350-W Yellow- 40, Road-350-W Yellow- 42, Road-350-W Yellow- 44, Road-350-W Yellow- 48                                                                                                     |    5 |
| Clothing    | Women's Mountain Shorts- L, Women's Mountain Shorts- M, Women's Mountain Shorts- S                                                                                                             |    1 |
| Clothing    | Classic Vest- S                                                                                                                                                                                |    2 |
| Clothing    | Classic Vest- L, Classic Vest- M                                                                                                                                                               |    3 |
| Clothing    | Short-Sleeve Classic Jersey- L, Short-Sleeve Classic Jersey- M, Short-Sleeve Classic Jersey- S, Short-Sleeve Classic Jersey- XL                                                                |    4 |
| Clothing    | Long-Sleeve Logo Jersey- XL                                                                                                                                                                    |    5 |
+-------------+------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------+------+

-- 25. Create the following report query (for business metrics as shown in the output).
SELECT 'Total Revenue' AS Item, FORMAT(ROUND(SUM(sales_amount), 2), 2) AS Value FROM datawarehouse.sales
UNION ALL
SELECT 'Average Price', ROUND(AVG(price), 2) FROM datawarehouse.sales
UNION ALL
SELECT 'Total Units Sold', SUM(quantity) FROM datawarehouse.sales
UNION ALL
SELECT 'Max Sales Order ID', order_number
FROM (SELECT order_number
	  FROM datawarehouse.sales
      WHERE sales_amount = (SELECT MAX(sales_amount) FROM sales)
      ORDER BY order_number DESC LIMIT 1) temp
UNION ALL
SELECT 'Min Sales Order ID', order_number
FROM (SELECT order_number
	  FROM datawarehouse.sales
      WHERE sales_amount = (SELECT MIN(sales_amount) FROM sales)
      ORDER BY order_number DESC LIMIT 1) temp
UNION ALL
SELECT 'Highest Sales Date', order_date
FROM (SELECT order_date
	  FROM datawarehouse.sales
      WHERE sales_amount = (SELECT MAX(sales_amount) FROM sales)
      ORDER BY order_date DESC LIMIT 1) temp
UNION ALL
SELECT 'Lowest Sales Date', order_date
FROM (SELECT order_date
	  FROM datawarehouse.sales
      WHERE sales_amount = (SELECT MIN(sales_amount) FROM sales)
      ORDER BY order_date DESC LIMIT 1) temp
UNION ALL
SELECT
	DISTINCT 'Highest Sales Category'
	, GROUP_CONCAT(DISTINCT p.category SEPARATOR '\r, ')
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE sales_amount = (SELECT MAX(sales_amount) FROM sales)
UNION ALL
SELECT
	DISTINCT 'Lowest Sales Category'
	, GROUP_CONCAT(DISTINCT p.subcategory SEPARATOR '\r, ')
FROM sales s LEFT JOIN products p ON p.p_product_key = s.s_product_key
WHERE sales_amount = (SELECT MIN(sales_amount) FROM sales);
+------------------------+----------------------------------------+
| Item                   | Value                                  |
+------------------------+----------------------------------------+
| Total Revenue          | 29,355,985.00                          |
| Average Price          | 486.04                                 |
| Total Units Sold       | 60423                                  |
| Max Sales Order ID     | SO46602                                |
| Min Sales Order ID     | SO52187                                |
| Highest Sales Date     | 2011-12-28                             |
| Lowest Sales Date      | 2013-02-03                             |
| Highest Sales Category | Bikes                                  |
| Lowest Sales Category  | Bottles and Cages, Cleaners, Helmets   |
+------------------------+----------------------------------------+

	
