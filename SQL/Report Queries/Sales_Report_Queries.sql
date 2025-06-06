USE db_sales;

-- Loaded CSVs into respective table schemas using LOAD DATA INFILE command

-- Glancing at tables' content:
SELECT * FROM db_sales.leads;
SELECT * FROM db_sales.sales;
SELECT * FROM db_sales.targets;

ALTER TABLE targets MODIFY COLUMN target DECIMAL(10, 2);  -- changing 'target' column's dtype to DECIMAL type
ALTER TABLE targets RENAME COLUMN target TO target_amt;   -- renaming col name to be different from table name
ALTER TABLE leads DROP postal_code;  -- dropping redundant column

-- Querying the metadata info on 'sales' table
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
-- SELECT
--     L.region
--     , L.state
--     , SUM(S.sales_amt) AS state_sales
--     , COUNT(S.cust_id) AS state_conversion_count
-- FROM leads L JOIN sales S ON L.cust_id = S.cust_id
-- GROUP BY region, state
-- ORDER BY region, state 
-- WITH ROLLUP ;   -- ROLLUP

-- -- More elegant query (NULLs of above query's output replaced by ALL STATES/ALL REGIONS)
-- SELECT
--     IF(GROUPING(L.region), "ALL REGIONS", L.region) AS REGIONS   -- GROUPING fn
--     , IF(GROUPING(L.state), "ALL STATES", L.state) AS STATES
--     , SUM(S.sales_amt) AS state_sales
--     , COUNT(S.cust_id) AS state_conversion_count
-- FROM leads L JOIN sales S ON L.cust_id = S.cust_id
-- GROUP BY L.region, L.state
-- WITH ROLLUP;

-- 2. Write a query to generate the following sales report:
-- ---- GROUPED BY lead year, lead month ---> no. of leads generated, % growth of leads over the months
-- ---- GROUPED BY order year, order month ---> monthly sales, min sales amt, min sales' category, min sales' salesperson, min sales' city, min sales' state,
-- min sales' region, max sales amt, max sales' category, max sales' salesperson, max sales' city, max sales' state, max sales' region

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
    , COUNT(cust_id) AS num_leads             -- counting the number of leads acquired in each month
FROM CTE_main
GROUP BY lead_year, lead_month
ORDER BY lead_year, lead_month
),
CTE_lead_growth AS (
SELECT
    ROW_NUMBER() OVER() AS row_num            -- final SELECT will utilize this col as joining condition
    , lc.lead_year
    , lc.lead_month
    , lc.num_leads
    , ROUND(COALESCE((lc.num_leads - LAG(lc.num_leads) OVER()) / LAG(lc.num_leads) OVER() * 100, 0), 2) AS pct_lead_growth
FROM CTE_lead_count lc LEFT JOIN CTE_main cm ON lc.lead_year = cm.lead_year AND lc.lead_month = cm.lead_month
GROUP BY lc.lead_year, lc.lead_month
),
CTE_sales AS (
SELECT
    ROW_NUMBER() OVER() AS row_num            -- final SELECT will utilize this col as joining condition
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

    
-- 3. Prepare a sales report of total sales in each state's city, pivoted along months (i.e. months are columns).
WITH CTE AS (
	SELECT 
        l.city AS city
        , l.state AS state
        , l.region AS region
        , s.category AS category
        , s.sales_amt AS sales_amt        
        , s.order_date AS order_date
        , YEAR(s.order_date) AS order_year
	FROM leads l LEFT JOIN sales s ON l.cust_id = s.cust_id)
SELECT
	order_year
    , state
    , city
    , SUM(CASE WHEN MONTHNAME(order_date) = 'January' THEN sales_amt ELSE 0 END) AS January
    , SUM(CASE WHEN MONTHNAME(order_date) = 'February' THEN sales_amt ELSE 0 END) AS February
    , SUM(CASE WHEN MONTHNAME(order_date) = 'March' THEN sales_amt ELSE 0 END) AS March
    , SUM(CASE WHEN MONTHNAME(order_date) = 'April' THEN sales_amt ELSE 0 END) AS April
    , SUM(CASE WHEN MONTHNAME(order_date) = 'May' THEN sales_amt ELSE 0 END) AS May
    , SUM(CASE WHEN MONTHNAME(order_date) = 'June' THEN sales_amt ELSE 0 END) AS June
    , SUM(CASE WHEN MONTHNAME(order_date) = 'July' THEN sales_amt ELSE 0 END) AS July
FROM CTE 
WHERE order_year IS NOT NULL
GROUP BY order_year, state, city
ORDER BY state;

-- OUTPUT:
+------------+----------------------+------------------+---------+----------+---------+----------+---------+---------+---------+
| order_year | state                | city             | January | February | March   | April    | May     | June    | July    |
+------------+----------------------+------------------+---------+----------+---------+----------+---------+---------+---------+
|       2022 | Alabama              | Huntsville       |    0.00 |     0.00 |    0.00 |   557.57 |    0.00 |    0.00 |    0.00 |
|       2022 | Alabama              | Decatur          |    0.00 |     0.00 |  499.63 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Alabama              | Montgomery       |    0.00 |     0.00 |    0.00 |     0.00 |  482.53 |    0.00 |    0.00 |
|       2022 | Arizona              | Phoenix          |    0.00 |     0.00 |    0.00 |     0.00 | 1651.21 |    0.00 |  429.02 |
|       2022 | Arizona              | Mesa             |    0.00 |   446.11 |    0.00 |   443.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Arizona              | Tucson           |    0.00 |     0.00 |  446.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Arizona              | Glendale         |    0.00 |   436.29 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Arizona              | Gilbert          |    0.00 |     0.00 |    0.00 |   436.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Arizona              | Scottsdale       |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  566.55 |    0.00 |
|       2022 | California           | Los Angeles      |    0.00 |  1399.88 | 1564.46 |  2997.91 | 2887.00 | 6260.49 |    0.00 |
|       2022 | California           | Fresno           |    0.00 |   529.70 |  488.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Oceanside        |    0.00 |   439.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Vallejo          |    0.00 |     0.00 |    0.00 |     0.00 |  508.53 |    0.00 |    0.00 |
|       2022 | California           | San Diego        |    0.00 |     0.00 |    0.00 |     0.00 | 1904.28 | 1294.97 |  425.00 |
|       2022 | California           | Roseville        |    0.00 |   471.14 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Inglewood        |    0.00 |     0.00 | 1020.33 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Concord          |    0.00 |     0.00 |    0.00 |     0.00 |  878.20 |    0.00 |    0.00 |
|       2022 | California           | Santa Ana        |    0.00 |     0.00 |  809.44 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Long Beach       |    0.00 |     0.00 |    0.00 |   961.36 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | La Quinta        |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |  471.77 |
|       2022 | California           | Escondido        |    0.00 |     0.00 |    0.00 |     0.00 |  470.44 |    0.00 |    0.00 |
|       2022 | California           | San Francisco    | 1520.53 |   566.79 | 3624.37 | 11542.23 | 1678.63 | 2149.33 | 1869.03 |
|       2022 | California           | Stockton         |    0.00 |     0.00 |    0.00 |     0.00 | 1411.82 |    0.00 |    0.00 |
|       2022 | California           | Pasadena         |    0.00 |     0.00 |    0.00 |     0.00 |  867.00 |  927.00 |    0.00 |
|       2022 | California           | Salinas          |    0.00 |   414.75 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Mission Viejo    |    0.00 |     0.00 |  447.88 |   460.00 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Redlands         |    0.00 |     0.00 |    0.00 |  1447.14 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Laguna Niguel    |    0.00 |     0.00 |  526.11 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | California           | Pico Rivera      |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  420.64 |    0.00 |
|       2022 | Colorado             | Parker           |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  955.54 |    0.00 |
|       2022 | Colorado             | Denver           |    0.00 |     0.00 |  623.16 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Colorado             | Pueblo           |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  516.70 |    0.00 |
|       2022 | Colorado             | Aurora           |  506.89 |     0.00 |    0.00 |     0.00 |    0.00 |  480.00 |    0.00 |
|       2022 | Colorado             | Louisville       |    0.00 |     0.00 |  975.18 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Connecticut          | Fairfield        |    0.00 |  1453.08 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Connecticut          | Norwich          |    0.00 |     0.00 |  549.21 |     0.00 |  426.00 |    0.00 |    0.00 |
|       2022 | Connecticut          | Manchester       |    0.00 |     0.00 |  949.91 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Delaware             | Dover            |    0.00 |     0.00 |    0.00 |   680.84 |    0.00 |  760.43 |    0.00 |
|       2022 | Delaware             | Wilmington       |    0.00 |  1797.06 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Delaware             | Newark           |    0.00 |   604.38 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | District of Columbia | Washington       |    0.00 |     0.00 |  512.84 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Florida              | Pembroke Pines   |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 | 1369.21 |
|       2022 | Florida              | Miami            |    0.00 |     0.00 |    0.00 |  1020.97 |    0.00 |    0.00 |    0.00 |
|       2022 | Florida              | Jacksonville     |    0.00 |   730.90 |  812.47 |   512.25 |  854.00 |  431.00 |    0.00 |
|       2022 | Florida              | Melbourne        |    0.00 |     0.00 |    0.00 |     0.00 |  551.88 |    0.00 |    0.00 |
|       2022 | Florida              | Fort Lauderdale  |    0.00 |     0.00 |    0.00 |     0.00 |  576.65 |    0.00 |    0.00 |
|       2022 | Florida              | Saint Petersburg |    0.00 |   911.74 |    0.00 |     0.00 |    0.00 |    0.00 |  521.38 |
|       2022 | Florida              | Boynton Beach    |    0.00 |     0.00 |    0.00 |   987.30 |    0.00 |    0.00 |    0.00 |
|       2022 | Georgia              | Roswell          |    0.00 |     0.00 |    0.00 |  1385.93 |  489.00 |    0.00 |    0.00 |
|       2022 | Georgia              | Atlanta          |    0.00 |     0.00 | 1083.23 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Georgia              | Smyrna           |    0.00 |     0.00 |  501.44 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Georgia              | Columbus         |    0.00 |     0.00 |    0.00 |   552.62 |    0.00 |    0.00 |    0.00 |
|       2022 | Illinois             | Park Ridge       |    0.00 |     0.00 |    0.00 |     0.00 |  978.14 |    0.00 |    0.00 |
|       2022 | Illinois             | Aurora           |    0.00 |   513.20 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Illinois             | Naperville       |    0.00 |     0.00 |  637.13 |     0.00 |  470.13 |    0.00 |    0.00 |
|       2022 | Illinois             | Highland Park    |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  456.22 |    0.00 |
|       2022 | Illinois             | Quincy           |    0.00 |   871.70 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Illinois             | Chicago          |    0.00 |     0.00 | 2546.26 |  1066.82 |    0.00 | 3106.94 |  487.35 |
|       2022 | Illinois             | Peoria           |    0.00 |   506.50 |  997.92 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Indiana              | La Porte         |    0.00 |     0.00 |  526.25 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Indiana              | New Albany       |  500.77 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Indiana              | Indianapolis     |  429.87 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Iowa                 | Des Moines       |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  512.51 |    0.00 |
|       2022 | Kentucky             | Murray           |    0.00 |     0.00 |    0.00 |     0.00 |  690.04 |    0.00 |    0.00 |
|       2022 | Kentucky             | Henderson        | 1326.01 |     0.00 |    0.00 |     0.00 |    0.00 |  485.44 |    0.00 |
|       2022 | Kentucky             | Richmond         |    0.00 |     0.00 |    0.00 |   483.78 |    0.00 | 1571.46 |    0.00 |
|       2022 | Kentucky             | Bowling Green    |  447.31 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Kentucky             | Louisville       |    0.00 |     0.00 |  432.00 |     0.00 |    0.00 | 8403.96 |    0.00 |
|       2022 | Louisiana            | Monroe           |    0.00 |   509.93 |    0.00 |     0.00 | 1479.50 |    0.00 |    0.00 |
|       2022 | Maryland             | Clinton          |    0.00 |   689.91 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Maryland             | Columbia         |    0.00 |     0.00 |    0.00 |     0.00 |  467.63 |    0.00 |    0.00 |
|       2022 | Massachusetts        | Quincy           |    0.00 |     0.00 |  535.55 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Massachusetts        | Lawrence         |    0.00 |   490.30 |  920.72 |  1044.06 |    0.00 |    0.00 |    0.00 |
|       2022 | Massachusetts        | Lowell           |    0.00 |     0.00 |    0.00 |     0.00 | 1089.80 |    0.00 |    0.00 |
|       2022 | Massachusetts        | Everett          |  418.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Michigan             | Westland         |    0.00 |     0.00 |    0.00 |   781.24 |    0.00 |    0.00 |    0.00 |
|       2022 | Michigan             | Dearborn         |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  402.00 |    0.00 |
|       2022 | Michigan             | Detroit          |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  410.21 |    0.00 |
|       2022 | Michigan             | Lincoln Park     |    0.00 |     0.00 |    0.00 |     0.00 |  424.92 |    0.00 |    0.00 |
|       2022 | Michigan             | Saginaw          |    0.00 |     0.00 | 2037.64 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Michigan             | Rochester Hills  |    0.00 |   534.41 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Minnesota            | Rochester        |    0.00 |     0.00 |    0.00 |     0.00 | 1170.26 |    0.00 |    0.00 |
|       2022 | Minnesota            | Minneapolis      |    0.00 |   475.76 |    0.00 |     0.00 |  483.00 |  454.87 |    0.00 |
|       2022 | Mississippi          | Jackson          |    0.00 |     0.00 |  415.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Missouri             | Independence     |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  967.10 |    0.00 |
|       2022 | Missouri             | Saint Louis      |    0.00 |     0.00 |  402.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Missouri             | Springfield      |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  515.18 |    0.00 |
|       2022 | New Hampshire        | Concord          |    0.00 |     0.00 |  531.68 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New Jersey           | Perth Amboy      |    0.00 |   962.82 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New Jersey           | Lakewood         |    0.00 |   410.85 |    0.00 |     0.00 |    0.00 |    0.00 | 1011.95 |
|       2022 | New Jersey           | Westfield        |    0.00 |     0.00 | 1315.57 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New Jersey           | Linden           |    0.00 |   459.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New Mexico           | Albuquerque      |    0.00 |   436.00 |  585.72 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New York             | Watertown        |    0.00 |     0.00 | 1134.40 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New York             | Buffalo          |    0.00 |   451.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New York             | Long Beach       |    0.00 |     0.00 |    0.00 |   484.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New York             | Rochester        |    0.00 |   453.48 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | New York             | Auburn           |    0.00 |  1000.92 |    0.00 |   453.88 |    0.00 |    0.00 |    0.00 |
|       2022 | New York             | New York City    |    0.00 |  2750.29 | 3683.33 |  2981.27 | 1430.93 | 7331.83 | 2844.71 |
|       2022 | New York             | Oceanside        |    0.00 |     0.00 |    0.00 |  1511.35 |    0.00 |    0.00 | 1337.97 |
|       2022 | North Carolina       | Raleigh          |    0.00 |     0.00 |    0.00 |     0.00 |  519.92 |    0.00 |    0.00 |
|       2022 | North Carolina       | Cary             |    0.00 |   416.61 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | North Carolina       | Burlington       |    0.00 |     0.00 |  745.56 |  3330.36 |    0.00 |    0.00 |    0.00 |
|       2022 | North Carolina       | Charlotte        |    0.00 |     0.00 |    0.00 |  1389.39 |    0.00 |    0.00 |    0.00 |
|       2022 | North Carolina       | Concord          |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |  494.49 |
|       2022 | North Carolina       | Wilmington       |    0.00 |   492.04 |  473.53 |     0.00 |  481.14 |    0.00 |    0.00 |
|       2022 | North Carolina       | Monroe           |    0.00 |     0.00 |    0.00 |   490.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Ohio                 | Lorain           |  607.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Ohio                 | Cincinnati       |    0.00 |   482.37 |    0.00 |   667.75 |    0.00 |  488.00 |    0.00 |
|       2022 | Ohio                 | Toledo           |  518.06 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Ohio                 | Springfield      |    0.00 |     0.00 |    0.00 |   905.21 |    0.00 |    0.00 |    0.00 |
|       2022 | Ohio                 | Hamilton         |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 | 1585.33 |    0.00 |
|       2022 | Ohio                 | Akron            |    0.00 |  1331.00 |  985.25 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Ohio                 | Kent             |    0.00 |     0.00 | 1078.96 |   518.63 |    0.00 |    0.00 |    0.00 |
|       2022 | Ohio                 | Lancaster        |    0.00 |     0.00 |    0.00 |     0.00 |  466.59 |    0.00 |    0.00 |
|       2022 | Ohio                 | Columbus         |    0.00 |     0.00 |  630.04 |     0.00 |    0.00 |  943.06 |    0.00 |
|       2022 | Ohio                 | Cleveland        |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |  759.97 |
|       2022 | Ohio                 | Newark           |    0.00 |     0.00 |    0.00 |   558.71 |    0.00 |    0.00 |    0.00 |
|       2022 | Ohio                 | Dublin           |    0.00 |     0.00 |    0.00 |     0.00 | 2402.42 |    0.00 |    0.00 |
|       2022 | Oklahoma             | Oklahoma City    |    0.00 |     0.00 |  476.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Oregon               | Portland         |    0.00 |     0.00 |    0.00 |   994.54 |    0.00 |    0.00 |    0.00 |
|       2022 | Pennsylvania         | Philadelphia     |    0.00 |  1871.81 |  530.79 |  1885.55 | 3829.02 | 6197.69 | 2478.70 |
|       2022 | Pennsylvania         | Chester          |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  519.14 |    0.00 |
|       2022 | Rhode Island         | Cranston         |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  408.02 |    0.00 |
|       2022 | Tennessee            | Columbia         |    0.00 |  3743.46 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Tennessee            | Franklin         |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 | 2015.22 |
|       2022 | Tennessee            | Murfreesboro     |  973.12 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Tennessee            | Bristol          |    0.00 |     0.00 | 1994.38 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Texas                | Amarillo         |    0.00 |   642.77 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Texas                | Tyler            |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  509.64 |    0.00 |
|       2022 | Texas                | Brownsville      |  552.08 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Texas                | Huntsville       |    0.00 |   447.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Texas                | Dallas           |  441.30 |     0.00 | 1061.77 |  1827.62 |    0.00 | 2091.33 |    0.00 |
|       2022 | Texas                | Grand Prairie    |    0.00 |     0.00 | 1840.23 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Texas                | Arlington        |    0.00 |     0.00 |  913.33 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Texas                | San Antonio      |    0.00 |  1410.18 |    0.00 |     0.00 |    0.00 |  439.00 |    0.00 |
|       2022 | Texas                | Grapevine        |    0.00 |     0.00 |  538.68 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Texas                | Austin           |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  488.97 |    0.00 |
|       2022 | Texas                | Houston          |    0.00 |  1295.24 |  586.94 |   432.00 |  941.28 |    0.00 |    0.00 |
|       2022 | Texas                | Richardson       |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |  495.86 |
|       2022 | Texas                | Pasadena         |    0.00 |     0.00 |    0.00 |   852.78 |    0.00 |    0.00 |  427.31 |
|       2022 | Texas                | Carrollton       |    0.00 |  2979.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Utah                 | Salt Lake City   |    0.00 |   825.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Utah                 | Orem             |    0.00 |   537.68 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Utah                 | West Jordan      |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  409.00 |    0.00 |
|       2022 | Virginia             | Suffolk          |    0.00 |   495.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Virginia             | Springfield      |    0.00 |     0.00 | 1467.40 |     0.00 |    0.00 |  464.00 |    0.00 |
|       2022 | Virginia             | Arlington        |  559.19 |     0.00 |    0.00 |  1292.87 |    0.00 |    0.00 |    0.00 |
|       2022 | Washington           | Spokane          |  518.34 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Washington           | Des Moines       | 1104.35 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Washington           | Seattle          |  916.27 |  1397.94 |  404.82 |     0.00 | 3687.45 | 7030.53 |    0.00 |
|       2022 | Washington           | Olympia          |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |  610.91 |    0.00 |
|       2022 | Washington           | Vancouver        |    0.00 |     0.00 |    0.00 |     0.00 |    0.00 |    0.00 |  601.91 |
|       2022 | Wisconsin            | Kenosha          |    0.00 |     0.00 |    0.00 |   437.97 |  438.92 |    0.00 |    0.00 |
|       2022 | Wisconsin            | Franklin         |    0.00 |     0.00 |  908.00 |     0.00 |    0.00 |    0.00 |    0.00 |
|       2022 | Wisconsin            | Milwaukee        |    0.00 |     0.00 |    0.00 |     0.00 |  420.38 |    0.00 |    0.00 |
+------------+----------------------+------------------+---------+----------+---------+----------+---------+---------+---------+














