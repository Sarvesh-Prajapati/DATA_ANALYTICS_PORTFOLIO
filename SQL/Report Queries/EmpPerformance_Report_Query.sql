USE sql_forda;  -- database

-- ----------------------- REPORT QUERY  -----------------------
-- ---------------Tables used : ab_employees, ab_salary_history -------------

-- --------- Create ab_employees table
CREATE TABLE ab_employees (employee_id INT PRIMARY KEY, emp_name VARCHAR(10) NOT NULL, join_date DATE NOT NULL, department VARCHAR(10) NOT NULL);
-- --------- Insert sample data
INSERT INTO ab_employees(employee_id, emp_name, join_date, department)
VALUES (1, 'Alice', '2018-06-15', 'IT'),(2, 'Bob', '2019-02-10', 'Finance'),(3, 'Charlie', '2017-09-20', 'HR'),
(4, 'David', '2020-01-05', 'IT'),(5, 'Eve', '2016-07-30', 'Finance'),(6, 'Sumit', '2016-06-30', 'Finance');
-- --------- Create ab_salary_history table
CREATE TABLE ab_salary_history (employee_id INT,change_date DATE NOT NULL,salary DECIMAL(10,2) NOT NULL,promotion VARCHAR(3));
-- --------- Insert sample data
INSERT INTO ab_salary_history (employee_id, change_date, salary, promotion)
VALUES(1, '2018-06-15', 50000, 'No'),(1, '2019-08-20', 55000, 'No'),(1, '2021-02-10', 70000, 'Yes'),(2, '2019-02-10', 48000, 'No'),
    (2, '2020-05-15', 52000, 'Yes'),(2, '2023-01-25', 68000, 'Yes'),(3, '2017-09-20', 60000, 'No'),(3, '2019-12-10', 65000, 'No'),
    (3, '2022-06-30', 72000, 'Yes'),(4, '2020-01-05', 45000, 'No'),(4, '2021-07-18', 49000, 'No'),(5, '2016-07-30', 55000, 'No'),
    (5, '2018-11-22', 62000, 'Yes'),(5, '2021-09-10', 75000, 'Yes'),(6, '2016-06-30', 55000, 'No'),(6, '2017-11-22', 50000, 'No'),
    (6, '2018-11-22', 40000, 'No'),(6, '2021-09-10', 75000, 'Yes');

select * from ab_employees;
select * from ab_salary_history;

-- Create a report for the following requirements:

-- 1. Find the latest salary for each employee.
-- 2. Calculate total number of promotion each employee has received.
-- 3. Determine the max salary hike percentage between any two consecutive salary changes for each employee.
-- 4. Identify employees whose salary has never decreased over time.
-- 5. Find the avg time (in months) between salary changes for each employee.
-- 6. Rank employees by their salary growth rate (from 1st to last recorded salary), break ties by earliest join date.

WITH CTE_dateRanked AS
(SELECT *
    , RANK() OVER(PARTITION BY employee_id ORDER BY change_date DESC) AS rnk_dsc
    , RANK() OVER(PARTITION BY employee_id ORDER BY change_date ASC) AS rnk_asc
FROM ab_salary_history ),
CTE_latest_salary AS (SELECT employee_id, salary FROM CTE_dateRanked WHERE rnk_dsc = 1),
CTE_promotions AS (SELECT employee_id, COUNT(promotion) AS count_promo FROM CTE_dateRanked WHERE promotion = 'Yes' GROUP BY employee_id),
CTE_prev_salary AS
(SELECT
    *
    , LEAD(salary) OVER(PARTITION BY employee_id ORDER BY change_date DESC) AS prev_salary 
    , LEAD(change_date) OVER(PARTITION BY employee_id ORDER BY change_date DESC) AS prev_change_date
FROM CTE_dateRanked),
CTE_salary_growth AS (SELECT employee_id, MAX(ROUND((salary - prev_salary)/prev_salary * 100.00, 2)) AS max_salary_growth FROM CTE_prev_salary GROUP BY 1),
CTE_salary_decreased AS (SELECT DISTINCT employee_id, 'N' AS never_decreased FROM CTE_prev_salary WHERE salary < prev_salary),
CTE_avg_months AS
(SELECT
	employee_id
	, AVG(TIMESTAMPDIFF(month, prev_change_date, change_date)) AS avg_months_between_changes 
FROM CTE_prev_salary
GROUP BY employee_id),
CTE_salary_ratio AS
(SELECT
	employee_id
	, MAX(CASE WHEN rnk_dsc = 1 THEN salary END) / MAX(CASE WHEN rnk_asc = 1 THEN salary END) AS salary_growth_ratio
    	, MIN(change_date) AS emp_join_date
FROM CTE_dateRanked GROUP BY employee_id),
CTE_salary_growth_ranked AS (SELECT employee_id, RANK() OVER(ORDER BY salary_growth_ratio DESC, emp_join_date ASC) AS rnk_by_growth FROM CTE_salary_ratio)
SELECT
    e.employee_id
    , e.emp_name
    , s.salary
    , COALESCE(p.count_promo, 0) AS count_promo
    , msg.max_salary_growth AS max_salary_growth
    , COALESCE(sd.never_decreased, 'Y') AS never_decreased
    , am.avg_months_between_changes
    , rbg.rnk_by_growth
FROM ab_employees e 
LEFT JOIN CTE_latest_salary s ON e.employee_id = s.employee_id
LEFT JOIN CTE_promotions p ON e.employee_id = p.employee_id
LEFT JOIN CTE_salary_growth msg ON e.employee_id = msg.employee_id
LEFT JOIN CTE_salary_decreased sd ON e.employee_id = sd.employee_id
LEFT JOIN CTE_avg_months am ON e.employee_id = am.employee_id
LEFT JOIN CTE_salary_growth_ranked rbg ON e.employee_id = rbg.employee_id ;

-- -------------- OPTIMIZING ABOVE QUERY TO RUN FASTER (REMOVAL OF REDUNDANT CTEs)

WITH
CTE_dateRanked AS
	(SELECT *
		, RANK() OVER(PARTITION BY employee_id ORDER BY change_date DESC) AS rnk_dsc
		, RANK() OVER(PARTITION BY employee_id ORDER BY change_date ASC) AS rnk_asc
		, LEAD(salary) OVER(PARTITION BY employee_id ORDER BY change_date DESC) AS prev_salary 
		, LEAD(change_date) OVER(PARTITION BY employee_id ORDER BY change_date DESC) AS prev_change_date
	FROM ab_salary_history),
CTE_salary_ratio AS
	(SELECT employee_id
		, MAX(CASE WHEN rnk_dsc = 1 THEN salary END) / MAX(CASE WHEN rnk_asc = 1 THEN salary END) AS salary_growth_ratio
		, MIN(change_date) AS emp_join_date
	FROM CTE_dateRanked 
    GROUP BY employee_id)
SELECT 
	cte.employee_id
	, MAX(CASE WHEN rnk_dsc = 1 THEN salary END) AS latest_salary
    , SUM(CASE WHEN promotion = 'Yes' THEN 1 ELSE 0 END) AS count_promo
    , MAX(ROUND((salary - prev_salary)/prev_salary * 100.00, 2)) AS max_salary_growth
    , CASE WHEN (MAX(CASE WHEN salary < prev_salary THEN 1 ELSE 0 END)) = 0 THEN 'Y' ELSE 'N' END AS never_decreased
    , AVG(TIMESTAMPDIFF(month, prev_change_date, change_date)) AS avg_months_between_changes
    , RANK() OVER(ORDER BY sr.salary_growth_ratio DESC, sr.emp_join_date ASC) AS rnk_by_growth
FROM CTE_dateRanked cte
LEFT JOIN CTE_salary_ratio sr ON cte.employee_id = sr.employee_id
GROUP BY cte.employee_id, sr.salary_growth_ratio, sr.emp_join_date
ORDER BY cte.employee_id;









-- SELECT LENGTH("APPLE") - LENGTH(REGEXP_REPLACE("APPLE", '[aeiouAEIOU]', ''));  -- Counting the no. of vowels in a word (2)
-- SELECT LENGTH("APPLE") - LENGTH(REGEXP_REPLACE("APPLE", '[^aeiouAEIOU]', ''));  -- Counting the consonants in a word  (3)








