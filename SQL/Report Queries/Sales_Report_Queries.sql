USE db_sales;

SELECT * FROM db_sales.leads;
SELECT * FROM db_sales.sales;
SELECT * FROM db_sales.targets;

ALTER TABLE targets MODIFY COLUMN target DECIMAL(10, 2);  -- changing 'target' column's dtype to DECIMAL type
ALTER TABLE targets RENAME COLUMN target TO target_amt;   -- renaming col name to be different from table name
ALTER TABLE leads DROP postal_code;  -- dropping redundant column

SELECT *
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'db_sales'
AND TABLE_NAME = 'sales';

-- Get info on table's columns
DESCRIBE leads;
DESCRIBE sales;

ALTER TABLE sales DROP cust_id;  -- dropped 'cust_id' col as it was not an ID, rather just a SL. No.

-- Since 'sales' table doesn't have 'cust_id' col in it now, and we need an ID for each
-- customer, create a new table 'new_sales' as follows:
CREATE TABLE new_sales AS
SELECT
    L.cust_id
    , S.cust_name
    , S.sp_assigned
    , S.category
    , S.order_date
    , S.sales_amt 
FROM leads L JOIN sales S ON L.cust_name = S.cust_name; -- joining on 'cust_name' as all 'cust_name' vals in tbl 'leads' are unique

DROP TABLE sales;  -- Drop the current 'sales' table
ALTER TABLE new_sales RENAME sales;  -- Rename the 'new_sales' table to 'sales' table

-- Now 'sales' table has correct 'cust_id' column that matches 'cust_name' correctly with that in 'leads' table

-- 1. Calculate the sales by state in each region and leads' conversion count by state in each region 
-- with rollup applied (i.e. summary rows included).
SELECT
    L.region
    , L.state
    , SUM(S.sales_amt) AS state_sales
    , COUNT(S.cust_id) AS state_conversion_count
FROM leads L JOIN sales S ON L.cust_id = S.cust_id
GROUP BY region, state
ORDER BY region, state 
WITH ROLLUP ;   -- ROLLUP

-- More elegant query (NULLs of above query's output replaced by ALL STATES/ALL REGIONS)
SELECT
    IF(GROUPING(L.region), "ALL REGIONS", L.region) AS REGIONS   -- GROUPING fn
    , IF(GROUPING(L.state), "ALL STATES", L.state) AS STATES
    , SUM(S.sales_amt) AS state_sales
    , COUNT(S.cust_id) AS state_conversion_count
FROM leads L JOIN sales S ON L.cust_id = S.cust_id
GROUP BY L.region, L.state
WITH ROLLUP;

-- 3. Trend of monthly leads generated

-- 4. Quota attainment per salesperson (i.e. sales target reached per salesperson)
-- 5. Salespersons who couldn't make a sale

-- 6. Write a REPORT QUERY to generate the following single report:
-- ---- GROUPED BY lead year, lead month ---> no. of leads generated, % growth of leads over the months
-- ---- GROUPED BY order year, order month ---> monthly sales, min sales amt, min sales' category, min sales' salesperson, min sales' city, min sales' state, min sales' region,
-- -------- max sales amt, max sales' category, max sales' salesperson, max sales' city, max sales' state, max sales' region

WITH CTE_main AS(
SELECT 
    l.cust_id AS cust_id
    , l.sp_assigned AS sp_assigned
    , l.city AS city
    , l.state AS state
    , l.region AS region
    , s.category AS category
    , s.sales_amt AS sales_amt        
    , l.lead_date AS lead_date        
    , YEAR(l.lead_date) AS lead_year
    , MONTH(l.lead_date) AS lead_month
    , s.order_date AS order_date
    , YEAR(s.order_date) AS order_year
    , MONTH(s.order_date) AS order_month
    , ROUND(AVG(sales_amt) OVER(PARTITION BY YEAR(s.order_date), MONTH(s.order_date), l.city), 2) AS avg_city_sales
    , ROUND(AVG(sales_amt) OVER(PARTITION BY YEAR(s.order_date), MONTH(s.order_date), l.state), 2) AS avg_state_sales
    , ROUND(AVG(sales_amt) OVER(PARTITION BY YEAR(s.order_date), MONTH(s.order_date), l.region), 2) AS avg_region_sales
    , MAX(s.sales_amt) OVER(PARTITION BY YEAR(s.order_date), MONTH(s.order_date)) AS max_sales_amt
    , MIN(s.sales_amt) OVER(PARTITION BY YEAR(s.order_date), MONTH(s.order_date)) AS min_sales_amt        
FROM leads l LEFT JOIN sales s ON l.cust_id = s.cust_id
),
CTE_lead_count AS (
SELECT
    lead_year
    , lead_month
    , COUNT(cust_id) AS num_leads
FROM CTE_main
GROUP BY lead_year, lead_month
ORDER BY lead_year, lead_month
),
CTE_lead_growth AS (
SELECT
    ROW_NUMBER() OVER() AS row_num
    , lc.lead_year
    , lc.lead_month
    , lc.num_leads
    , ROUND(COALESCE((lc.num_leads - LAG(lc.num_leads) OVER()) / LAG(lc.num_leads) OVER() * 100, 0), 2) AS pct_lead_growth
FROM CTE_lead_count lc LEFT JOIN CTE_main cm ON lc.lead_year = cm.lead_year AND lc.lead_month = cm.lead_month
GROUP BY lc.lead_year, lc.lead_month
),
CTE_sales AS (
SELECT
    ROW_NUMBER() OVER() AS row_num
    , order_year
    , order_month
    , SUM(sales_amt) AS monthly_sales
    , MIN(min_sales_amt) AS min_sales_amt
    , MAX(CASE WHEN sales_amt = min_sales_amt THEN category END) AS min_sales_cat
    , MAX(CASE WHEN sales_amt = min_sales_amt THEN sp_assigned END) AS min_sales_sp
    , MAX(CASE WHEN sales_amt = min_sales_amt THEN city END) AS min_sales_city
    , MAX(CASE WHEN sales_amt = min_sales_amt THEN state END) AS min_sales_state
    , MAX(CASE WHEN sales_amt = min_sales_amt THEN region END) AS min_sales_region
    , MAX(max_sales_amt) AS max_sales_amt
    , MAX(CASE WHEN sales_amt = max_sales_amt THEN category END) AS max_sales_cat
    , MAX(CASE WHEN sales_amt = max_sales_amt THEN sp_assigned END) AS max_sales_sp
    , MAX(CASE WHEN sales_amt = max_sales_amt THEN city END) AS max_sales_city    
    , MAX(CASE WHEN sales_amt = max_sales_amt THEN state END) AS max_sales_state	
    , MAX(CASE WHEN sales_amt = max_sales_amt THEN region END) AS max_sales_region
FROM CTE_main
WHERE order_year IS NOT NULL AND order_month IS NOT NULL
GROUP BY order_year, order_month
)
SELECT
    clg.lead_year
    , clg.lead_month
    , clg.num_leads
    , clg.pct_lead_growth
    , cs.order_year
    , cs.order_month
    , cs.monthly_sales
    , cs.min_sales_amt
    , cs.min_sales_cat
    , cs.min_sales_sp
    , cs.min_sales_city
    , cs.min_sales_state
    , cs.min_sales_region
    , cs.max_sales_amt
    , cs.max_sales_cat
    , cs.max_sales_sp
    , cs.max_sales_city
    , cs.max_sales_state
    , cs.max_sales_region
FROM CTE_lead_growth clg RIGHT JOIN CTE_sales cs ON clg.row_num = cs.row_num ;

-- OUTPUT: 
+-----------+------------+-----------+-----------------+------------+-------------+---------------+---------------+---------------+--------------+----------------+-----------------+------------------+---------------+---------------+--------------+----------------+-----------------+------------------+
| lead_year | lead_month | num_leads | pct_lead_growth | order_year | order_month | monthly_sales | min_sales_amt | min_sales_cat | min_sales_sp | min_sales_city | min_sales_state | min_sales_region | max_sales_amt | max_sales_cat | max_sales_sp | max_sales_city | max_sales_state | max_sales_region |
+-----------+------------+-----------+-----------------+------------+-------------+---------------+---------------+---------------+--------------+----------------+-----------------+------------------+---------------+---------------+--------------+----------------+-----------------+------------------+
|      2022 |          1 |       134 |            0.00 |       2022 |           1 |      11339.09 |        418.00 | Copy Paper    | Meredith     | Everett        | Massachusetts   | East             |       1326.01 | Envelopes     | Angela       | Henderson      | Kentucky        | South            |
|      2022 |          2 |       120 |          -10.45 |       2022 |           2 |      40083.99 |        400.00 | Envelopes     | Ryan         | Los Angeles    | California      | West             |       3743.46 | Copy Paper    | Dwight       | Columbia       | Tennessee       | South            |
|      2022 |          3 |       123 |            2.50 |       2022 |           3 |      46770.51 |        400.00 | Copy Paper    | Andy         | Dallas         | Texas           | Central          |       2229.53 | Envelopes     | Kelly        | San Francisco  | California      | West             |
|      2022 |          4 |       126 |            2.44 |       2022 |           4 |      48374.90 |        428.27 | Copy Paper    | Andy         | Los Angeles    | California      | West             |       7040.73 | Copy Paper    | Andy         | San Francisco  | California      | West             |
|      2022 |          5 |       157 |           24.60 |       2022 |           5 |      37508.64 |        403.00 | Copy Paper    | Kelly        | San Diego      | California      | West             |       2696.49 | Copy Paper    | Michael      | Philadelphia   | Pennsylvania    | East             |
|      2022 |          6 |       136 |          -13.38 |       2022 |           6 |      61564.99 |        402.00 | Copy Paper    | Toby         | Dearborn       | Michigan        | Central          |       8403.96 | Copy Paper    | Toby         | Louisville     | Kentucky        | South            |
|      NULL |       NULL |      NULL |            NULL |       2022 |           7 |      18040.85 |        418.82 | Envelopes     | Ryan         | San Francisco  | California      | West             |       2015.22 | Copy Paper    | Kelly        | Franklin       | Tennessee       | South            |
+-----------+------------+-----------+-----------------+------------+-------------+---------------+---------------+---------------+--------------+----------------+-----------------+------------------+---------------+---------------+--------------+----------------+-----------------+------------------+















