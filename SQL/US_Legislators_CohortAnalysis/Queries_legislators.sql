-- SCHEMA ON LOCAL MACHINE : 'sql_forda'  
-- TABLES USED : 'c4_legislators', 'c4_legislators_terms', 'c0_date_dim'

-- ---------------------------------------------------------------------------------------------------------------------------------

-- Glancing at table data

SELECT * FROM c4_legislators_terms;

-- 1. First time term starting date of each legislator

SELECT
    id_bioguide
    , MIN(term_start) AS first_term
FROM c4_legislators_terms
GROUP BY id_bioguide;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 2. Count of legislators per period

-- SELECT TIMESTAMPDIFF(MONTH, '2009-05-18','2009-07-29') AS MONTH_DIFF;  -- returns year/month/days from 'second timestamp - first timestamp'
-- SELECT TIMESTAMPDIFF(YEAR, '2009-05-18','2007-07-29') AS YEAR_DIFF;    -- returns -1

SELECT
	TIMESTAMPDIFF(YEAR, a.first_term, b.term_start) AS period
	, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
FROM
(
	SELECT
		id_bioguide
		, MIN(term_start) as first_term
	FROM c4_legislators_terms 
	GROUP BY 1
) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
GROUP BY 1;

-- Following query helps to visualize the result of JOIN in above query (only those columns are kept that're used in outer SELECT):

SELECT
	a.id_bioguide AS AID
	, a.first_term
	, b.id_bioguide AS BID
	, b.term_start
	, TIMESTAMPDIFF(YEAR, a.first_term, b.term_start) AS Period 
FROM 
(	SELECT
		id_bioguide
		, MIN(term_start) AS first_term
	FROM c4_legislators_terms
	GROUP BY 1
) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide 
ORDER BY a.id_bioguide;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 3. Percentage of cohort retained in each period

SELECT
	period
	, FIRST_VALUE(cohort_retained) OVER (ORDER BY period) AS cohort_size
	, cohort_retained
	, cohort_retained / FIRST_VALUE(cohort_retained) OVER (ORDER BY period) AS pct_retained
FROM 
(	SELECT
		TIMESTAMPDIFF(YEAR, a.first_term, b.term_start) AS period
		, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
	FROM
	(	SELECT
			id_bioguide
			, min(term_start) as first_term 
		FROM c4_legislators_terms
		GROUP BY 1
	) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide 
	GROUP BY 1
) tmp;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 4. Pivoting results of above query along period (i.e. cols as yr0, yr1, yr2, yr3 etc.)

SELECT 
    cohort_size
    , MAX(CASE WHEN period = 0 THEN pct_retained END) AS yr0
    , MAX(CASE WHEN period = 1 THEN pct_retained END) AS yr1
    , MAX(CASE WHEN period = 2 THEN pct_retained END) AS yr2
FROM
(	SELECT
        period
        , FIRST_VALUE(cohort_retained) OVER (ORDER BY period) AS cohort_size
        , cohort_retained, cohort_retained / FIRST_VALUE(cohort_retained) OVER (ORDER BY period)*100 AS pct_retained
	FROM 
	(    SELECT
		     TIMESTAMPDIFF(YEAR, a.first_term, b.term_start) AS period
             , COUNT(DISTINCT a.id_bioguide) AS cohort_retained
	      FROM 
		 (    SELECT
			       id_bioguide
                   , MIN(term_start) AS first_term
			   FROM c4_legislators_terms 
			   GROUP BY 1
		  ) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide GROUP BY 1
	  ) tmp1
) tmp2 GROUP BY 1;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 5. Create data set that contains a record for each December 31 that each legislator was in office

SELECT
	a.id_bioguide AS ID
	, a.first_term
	, b.term_start
	, b.term_end
	, c.date
	, TIMESTAMPDIFF(YEAR,  a.first_term, b.term_start) AS period
FROM 
(	SELECT
		id_bioguide
		, MIN(term_start) AS first_term 
	FROM c4_legislators_terms 
	GROUP BY 1
) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
LEFT JOIN c0_date_dim c ON c.date BETWEEN b.term_start AND b.term_end AND MONTHNAME(c.date) = 'December' AND DAY(c.date) = 31;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 6. Next calculate cohort_retained for each period as done above earlier. 

-- COALESCE fn sets default as 0 when a legislator's term starts & ends in same year resulting in 'period' as NULL

SELECT
	COALESCE(TIMESTAMPDIFF(YEAR,  a.first_term, c.date), 0) AS period
	, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
FROM
(	SELECT 
		id_bioguide
		, MIN(term_start) AS first_term 
	FROM c4_legislators_terms 
	GROUP BY 1
) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
LEFT JOIN c0_date_dim c ON c.date BETWEEN b.term_start AND b.term_end AND MONTHNAME(c.date) = 'December' AND DAY(c.date) = 31
GROUP BY 1;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 7. Now calculate the cohort_size and pct_retained (like done in lines above) using 'first_value' window fn

SELECT
	period
	, FIRST_VALUE(cohort_retained) OVER (ORDER BY period) AS cohort_size
	, cohort_retained
	, cohort_retained / FIRST_VALUE(cohort_retained) OVER (ORDER BY period) AS pct_retained
FROM
(	SELECT
		COALESCE(TIMESTAMPDIFF(YEAR,  a.first_term, c.date), 0) AS period
		, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
	FROM
	(	SELECT
			id_bioguide
			, MIN(term_start) AS first_term 
		FROM c4_legislators_terms 
		GROUP BY 1
	) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
	LEFT JOIN c0_date_dim c ON c.date BETWEEN b.term_start AND b.term_end AND MONTHNAME(c.date) = 'December' AND DAY(c.date) = 31
	GROUP BY 1
) tmp;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 8. Cohort retained & % of cohort retained in every year

SELECT
	YEAR(a.first_term) as first_year
	, COALESCE(TIMESTAMPDIFF(YEAR,  a.first_term, c.date), 0) AS period
	, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
FROM
(	SELECT
		id_bioguide
		, MIN(term_start) as first_term
	FROM c4_legislators_terms
	GROUP BY 1
) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
LEFT JOIN c0_date_dim c ON c.date BETWEEN b.term_start AND b.term_end AND c.month_name = 'December' AND c.day_of_month = 31
GROUP BY 1, 2;

-- Above query is then used as subquery, and 'cohort_size' and 'pct_retained' are calculated in the outer query. In this case, however, we need 
-- PARTITION BY clause that includes 'first_year' so that FIRST_VALUE is calculated only within the set of rows for that 'first_year', rather than
-- across the whole result set from the subquery.

SELECT
	first_year
	, period
	, FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_year ORDER BY period) AS cohort_size
	, cohort_retained
	,cohort_retained/FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_year ORDER BY period) AS pct_retained
FROM
(	SELECT
		YEAR(a.first_term) as first_year
		, COALESCE(TIMESTAMPDIFF(YEAR,  a.first_term, c.date), 0) AS period
		, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
	FROM
	(	SELECT
			id_bioguide
			, MIN(term_start) as first_term
		FROM c4_legislators_terms
		GROUP BY 1
	) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
	LEFT JOIN c0_date_dim c ON c.date BETWEEN b.term_start AND b.term_end AND c.month_name = 'December' AND c.day_of_month = 31
	GROUP BY 1, 2
) tmp;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 9. Cohort the legislators by the century in which lies their first term date.

-- Unlike PostgreSQL, MySQL doesn't provide an inbuilt CENTURY() fn to return the century a date lies in. However, we can extract the year from a
-- date using YEAR fn.
-- ------------ Ways to extract the century in which a date belongs ------------------------
-- SELECT CAST(FLOOR(YEAR(c.date)/100) +1 AS UNSIGNED) AS Century FROM c0_date_dim c;
-- SELECT DISTINCT(FLOOR(YEAR(c.date)/100)) +1  AS Century, c.date FROM c0_date_dim c;

SELECT
	first_century
	, period
	, FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_century ORDER BY period) AS cohort_size
	, cohort_retained
	, cohort_retained / FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_century ORDER BY period) AS pct_retained
FROM
(	SELECT
		FLOOR(YEAR(a.first_term)/100) + 1 AS first_century
		, COALESCE(TIMESTAMPDIFF(YEAR,  a.first_term, c.date), 0) AS period
		, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
	FROM
	(	SELECT 
			id_bioguide
			, MIN(term_start) AS first_term
		FROM c4_legislators_terms
		GROUP BY 1
	) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
	LEFT JOIN c0_date_dim c ON c.date BETWEEN b.term_start AND b.term_end AND c.month_name = 'December' and c.day_of_month = 31
	GROUP BY 1,2
) tmp
ORDER BY 1,2;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 10. First state for each legislator in which his/her first ever term began in

SELECT
	DISTINCT id_bioguide
	, MIN(term_start) OVER(PARTITION BY id_bioguide) AS first_term
	, FIRST_VALUE(state) OVER(PARTITION BY id_bioguide ORDER BY term_start) AS first_state
FROM c4_legislators_terms;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 11. Using above query as sub-query, find the cohort retention by state

SELECT
	first_state
	, period
	, FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_state ORDER BY period) AS cohort_size
	, cohort_retained
	, cohort_retained/FIRST_VALUE(cohort_retained) OVER(PARTITION BY first_state ORDER BY period) AS pct_retained
FROM
(	SELECT
		a.first_state
		, COALESCE(TIMESTAMPDIFF(YEAR,  a.first_term, c.date), 0) AS period
        , COUNT(DISTINCT a.id_bioguide) AS cohort_retained
	FROM
	(	SELECT
			DISTINCT id_bioguide
            , MIN(term_start)  OVER(PARTITION BY id_bioguide) AS first_term
            , FIRST_VALUE(state)  OVER(PARTITION BY id_bioguide order by term_start) AS first_state
		FROM c4_legislators_terms
	) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
	LEFT JOIN c0_date_dim c ON c.date between b.term_start AND b.term_end AND c.month_name = 'December' and c.day_of_month = 31
	GROUP BY 1, 2
) tmp;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 12. Find out the retention of legislators by gender

SELECT
	d.gender
	, COALESCE(TIMESTAMPDIFF(YEAR, a.first_term, c.date), 0) AS period
	, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
FROM
(	SELECT
		id_bioguide
		, MIN(term_start) AS first_term
	FROM c4_legislators_terms
	GROUP BY 1
) a JOIN c4_legislators_terms b ON a.id_bioguide = b.id_bioguide
LEFT JOIN c0_date_dim c ON c.date BETWEEN b.term_start AND b.term_end AND c.month_name = 'December' AND c.day_of_month = 31
JOIN c4_legislators d on a.id_bioguide = d.id_bioguide
GROUP BY 1,2;

-- ---------------------------------------------------------------------------------------------------------------------------------

-- 13. Find percentage retention by gender over the periods

SELECT
	gender
	, period
	, FIRST_VALUE(cohort_retained) OVER(PARTITION BY gender ORDER BY period) AS cohort_size
	, cohort_retained
	, cohort_retained/FIRST_VALUE(cohort_retained) OVER(PARTITION BY gender ORDER BY period) AS pct_retained
FROM
(	SELECT
		d.gender
		, COALESCE(TIMESTAMPDIFF(YEAR, a.first_term, c.date), 0) AS period
		, COUNT(DISTINCT a.id_bioguide) AS cohort_retained
	FROM
	(	SELECT
			id_bioguide
			, MIN(term_start) AS first_term
		FROM c4_legislators_terms
		GROUP BY 1
	) a JOIN c4_legislators_terms b on a.id_bioguide = b.id_bioguide
	LEFT JOIN c0_date_dim c ON c.date BETWEEN b.term_start AND b.term_end AND c.month_name = 'December' AND c.day_of_month = 31
	JOIN c4_legislators d on a.id_bioguide = d.id_bioguide
	GROUP BY 1,2
) tmp;







