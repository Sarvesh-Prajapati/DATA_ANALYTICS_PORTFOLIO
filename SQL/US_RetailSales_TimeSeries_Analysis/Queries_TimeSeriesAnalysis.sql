-- SCHEMA ON LOCAL MACHINE : 'sql_forda'  
-- TABLE NAME : 'c3_retail_sales'

-- Get table's columns' info
SHOW FIELDS FROM sql_forda.c3_retail_sales;

-- Glance at table's content
SELECT * FROM c3_retail_sales;

-- -------------------------------------------------------------------------------------------------------

-- 1. Trend of total retail and food services sales every year

SELECT 
  YEAR(sales_month) AS sales_year
  , SUM(sales) AS total_sales
FROM c3_retail_sales 
WHERE kind_of_business = 'Retail and food services sales, total'
GROUP BY 1;

-- -------------------------------------------------------------------------------------------------------

-- 2. Compare yearly sales trend for categories associated with leisure activities, like book stores, sporting goods stores, and hobby stores.

SELECT 
  YEAR(sales_month) AS sales_year
  , kind_of_business, 
  , SUM(sales) AS total_sales
FROM c3_retail_sales 
WHERE kind_of_business in ('Book stores' ,'Sporting goods stores','Hobby, toy, and game stores')
GROUP BY 1, 2;

-- -------------------------------------------------------------------------------------------------------

-- 3. Sales trend of men's clothing stores and women's clothing stores?

SELECT 
  YEAR(sales_month) AS 'year'
  , kind_of_business, 
  , SUM(sales) AS total_sales
FROM c3_retail_sales 
WHERE kind_of_business in ('Men''s clothing stores', 'Women''s clothing stores') 
GROUP BY 1, 2;

-- -------------------------------------------------------------------------------------------------------

-- 4. Gap between sales of women's clothing stores' and of men's clothing stores over the years

SELECT
  YEAR(sales_month) AS sales_year
  , SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) AS womens_sales,
  , SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) AS mens_sales
FROM c3_retail_sales 
WHERE kind_of_business in ('Men''s clothing stores', 'Women''s clothing stores')
GROUP BY 1;

-- Using the above query as building block, we now calculate the difference between women's sales and men's sales.

SELECT 
  sales_year
  , womens_sales - mens_sales AS womens_minus_mens, 
  , mens_sales - womens_sales AS mens_minus_womens
FROM
(
	SELECT 
    YEAR(sales_month) AS sales_year
    , SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) AS womens_sales
    , SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) AS mens_sales
  FROM c3_retail_sales 
  WHERE kind_of_business IN ('Men''s clothing stores' , 'Women''s clothing stores') AND sales_month <= '2019-12-01'
  GROUP BY 1
) tmp;

-- We can also find the ratio of 'womens_sales' to 'mens_sales'

SELECT
  sales_year
  , womens_sales/mens_sales AS womens_times_of_mens
FROM
(
	SELECT YEAR(sales_month) AS sales_year
	, SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) AS womens_sales
  , SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) AS mens_sales
  FROM c3_retail_sales
  WHERE kind_of_business IN ('Men''s clothing stores' , 'Women''s clothing stores') AND sales_month <= '2019-12-01'
  GROUP BY 1
) tmp;

-- Building upon the above query, we can calculate % difference between sales at women’s and men’s clothing stores:

SELECT
  sales_year
  , (womens_sales / mens_sales -1) * 100 AS womens_pct_of_mens
FROM
(
	SELECT
    YEAR(sales_month) AS sales_year
    , SUM(CASE WHEN kind_of_business = 'Women''s clothing stores' THEN sales END) AS womens_sales
    , SUM(CASE WHEN kind_of_business = 'Men''s clothing stores' THEN sales END) AS mens_sales
  FROM c3_retail_sales
  WHERE kind_of_business IN ('Men''s clothing stores' , 'Women''s clothing stores') AND sales_month <= '2019-12-01'
  GROUP BY 1
) tmp;

-- -------------------------------------------------------------------------------------------------------

-- 5. For each year's total sales, find % share each of men's stores sales & women's stores sales to that year's total sales (using only self-join)

SELECT
  sales_month
  , kind_of_business
  , sales * 100 / total_sales AS pct_total_sales
FROM
(
	SELECT
    a.sales_month
    , a.kind_of_business
    , a.sales
    , SUM(b.sales) AS total_sales 
  FROM c3_retail_sales a
  JOIN c3_retail_sales b ON a.sales_month = b.sales_month AND b.kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores')
  WHERE a.kind_of_business in ('Men''s clothing stores' , 'Women''s clothing stores')
  GROUP BY 1, 2, 3
) tmp;

-- -------------------------------------------------------------------------------------------------------

-- 6. Use window functions to find the trend in percentage of total sales in women's stores sales and men's stores sales over the period.

SELECT
  sales_month
  , kind_of_business
  , sales
  , SUM(sales) OVER(PARTITION BY sales_month) AS total_sales
  , sales * 100 / sum(sales) OVER (PARTITION BY sales_month) AS pct_total
FROM c3_retail_sales
WHERE kind_of_business IN ('Men''s clothing stores', 'Women''s clothing stores');

-- -------------------------------------------------------------------------------------------------------

-- 7. Percent of yearly sales each month contributes to total sales for the men's stores sales and women's stores sales

SELECT
  sales_month
  , kind_of_business
  , sales
  , SUM(sales) OVER (PARTITION BY YEAR(sales_month), kind_of_business) AS yearly_sales
  , sales * 100 / SUM(sales) OVER (PARTITION BY YEAR(sales_month), kind_of_business) AS pct_yearly
FROM c3_retail_sales
WHERE kind_of_business in ('Men''s clothing stores', 'Women''s clothing stores');

-- -------------------------------------------------------------------------------------------------------

-- 8. Percentage change in women's stores sales year by year considering 1992 as base year

SELECT 
    sales_year 
    , sales 
    , FIRST_VALUE(sales) OVER(ORDER BY sales_year) AS base_year_sales 
    , (sales / FIRST_VALUE(sales) OVER(ORDER BY sales_year) - 1) * 100 AS pct_from_base 
FROM 
(   SELECT 
        YEAR(sales_month) AS sales_year 
        , SUM(sales) AS sales 
    FROM retail_sales 
    WHERE kind_of_business = 'Women''s clothing stores' 
    GROUP BY 1 
) tmp; 

-- -------------------------------------------------------------------------------------------------------

-- 9. Moving average sales for women's stores taking a window size of 12 months (i.e. date starts from 1993-01-01)

SELECT 
    a.sales_month 
    , a.sales 
    , AVG(b.sales) AS moving_avg 
    , COUNT(b.sales) AS records_count 
FROM retail_sales a 
JOIN retail_sales b ON a.kind_of_business = b.kind_of_business AND b.sales_month BETWEEN a.sales_month - INTERVAL 11 MONTH AND a.sales_month AND b.kind_of_business = 'Women''s clothing stores' 
WHERE a.kind_of_business = 'Women''s clothing stores' AND a.sales_month >= '1993-01-01' 
GROUP BY 1, 2; 

-- -------------------------------------------------------------------------------------------------------

-- 10. Implement the previous query using window functions

SELECT 
    sales_month 
    , AVG(sales) OVER(ORDER BY sales_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS moving_avg 
    , COUNT(sales) OVER(ORDER BY sales_month ROWS BETWEEN 11 PRECEDING AND CURRENT ROW) AS records_count 
FROM retail_sales 
WHERE kind_of_business = 'Women''s clothing stores'; 

-- -------------------------------------------------------------------------------------------------------

-- 11. Calculate the cumulative women's stores sales over the period.

SELECT 
    sales_month
    , sales
    , SUM(sales) OVER(ORDER BY YEAR(sales_month) ORDER BY sales_month) AS sales_ytd 
FROM retail_sales 
WHERE kind_of_business = 'Women''s clothing stores'; 

-- -------------------------------------------------------------------------------------------------------

-- 12. Percent change trend in the sales between previous month & current month for all 'book stores' businesses in the dataset

SELECT 
    kind_of_business 
    , sales_month 
    , LAG(sales_month) OVER(PARTITION BY kind_of_business ORDER BY sales_month) AS prev_month 
    , LAG(sales) OVER(PARTITION BY kind_of_business ORDER BY sales_month) AS prev_month_sales 
    , (sales / LAG(sales) OVER(PARTITION BY kind_of_business ORDER BY sales_month) - 1) * 100 AS pct_growth_from_previous 
FROM retail_sales 
WHERE kind_of_business = 'Book stores'; 

-- -------------------------------------------------------------------------------------------------------

-- 13. Extract the YoY percentage change over the period for book store sales.

SELECT 
    sales_year 
    , yearly_sales 
    , LAG(yearly_sales) OVER(ORDER BY sales_year) AS prev_year_sales 
    , (sales / LAG(yearly_sales) OVER(ORDER BY sales_year) - 1) * 100 AS pct_growth_from_previous 
FROM 
(   SELECT 
        YEAR(sales_month) AS sales_year 
        , SUM(sales) AS yearly_sales 
    FROM retail_sales 
    WHERE kind_of_business = 'Book stores' 
    GROUP BY 1 
) tmp; 

-- -------------------------------------------------------------------------------------------------------

-- 14. Compare the sales for book stores for current month this year to current month the previous year.

SELECT 
    sales_month 
    , sales 
    , LAG(sales_month) OVER(PARTITION BY MONTH(sales_month) ORDER BY sales_month) AS prev_year_month 
    , LAG(sales) OVER(PARTITION BY MONTH(sales_month) ORDER BY sales_month) AS prev_year_sales 
FROM retail_sales 
WHERE kind_of_business = 'Book stores'; 

-- -------------------------------------------------------------------------------------------------------

-- 15. Create a result set that has a row for each month number and month name, and a maximum sales column for each of the years 1992, 1993 and 1994. The kind of business is 'Book stores'.

SELECT
  MONTH(sales_month) AS month_number
  , MONTHNAME(sales_month) AS month_name
  , MAX(CASE WHEN YEAR(sales_month) = 1992 THEN sales END) AS sales_1992
  , MAX(CASE WHEN YEAR(sales_month) = 1993 THEN sales END) AS sales_1993
  , MAX(CASE WHEN YEAR(sales_month) = 1994 THEN sales END) AS sales_1994
FROM c3_retail_sales 
WHERE kind_of_business = 'Book stores' AND sales_month BETWEEN '1992-01-01' AND '1994-12-01' 
GROUP BY 1, 2;

-- -------------------------------------------------------------------------------------------------------

-- 16. Compare the percent of the rolling average of book stores sales over 3 prior years.

SELECT
  sales_month
  , sales
  , sales / ((prev_sales_1 + prev_sales_2 + prev_sales_3) / 3) * 100 AS pct_of_3_prev
FROM
(
	SELECT
    sales_month
    , sales
    , LAG(sales, 1) OVER (PARTITION BY MONTH(sales_month) ORDER BY sales_month) AS prev_sales_1
    , LAG(sales, 2) OVER (PARTITION BY MONTH(sales_month) ORDER BY sales_month) AS prev_sales_2
	  , LAG(sales, 3) OVER (PARTITION BY MONTH(sales_month) ORDER BY sales_month) AS prev_sales_3
  FROM c3_retail_sales
  WHERE kind_of_business = 'Book stores'
) tmp;

-- Above query re-written compactly as follows:

SELECT 
  sales_month
  , sales
  , sales / AVG(sales) OVER (PARTITION BY MONTH(sales_month) ORDER BY sales_month ROWS BETWEEN 3 PRECEDING AND 1 PRECEDING) AS pct_of_prev_3
FROM c3_retail_sales 
WHERE kind_of_business = 'Book stores';
