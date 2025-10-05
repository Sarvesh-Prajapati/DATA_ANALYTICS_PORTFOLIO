SELECT CURRENT_TIMESTAMP();       -- current time-stamp
SHOW PARAMETERS LIKE 'TIMEZONE';  -- current timezone  (dafualt : 'America/Los_Angeles')

ALTER SESSION SET TIMEZONE = 'Asia/Kolkata';
SELECT CURRENT_TIMESTAMP();

-- Create the DB, drop the default PUBLIC schema created within it; create schema REPO
CREATE OR REPLACE DATABASE GYM;
DROP SCHEMA GYM.PUBLIC;
CREATE OR REPLACE SCHEMA GYM.REPO;

-- Change context and role
USE ROLE SYSADMIN;
USE DATABASE GYM;
USE SCHEMA GYM.REPO;

-- ######################### LOADING CSV ###########################

-- Create a Table To Import Raw Data Into.
CREATE OR REPLACE TABLE GYM.REPO.TBL_ACCIDENTS(
Accident_ID INT PRIMARY KEY,              -- 1 to 307973
Accident_Timestamp TIMESTAMP,
Day_Of_Week VARCHAR(10),
Junction_Control VARCHAR(100),
Junction_Detail VARCHAR(100),
Accident_Severity VARCHAR(20),            -- slight, serious, fatal
LatLong VARCHAR(50),                      -- CSV file has 'LatLong' vals as string (e.g. 'POINT(10.123 -10.123)') so VARCHAR specified here; fixed below after loading data 
Light_Conditions VARCHAR(50),
Local_Authority_District VARCHAR(50),
Carriageway_Hazards VARCHAR(100),
Casualty_Count INT,                        -- 1 to 48
Vehicle_Count INT,                         -- 1 to 32
Police_Force VARCHAR(50),
Road_Surface_Conditions VARCHAR(25),       -- dry, wet or damp, frost or ice, flood, snow etc.
Road_Type VARCHAR(20),                     -- one way, roundabout, single carriageway, dual carriageway, slip road
Speed_Limit INT,                           -- 10 to 70mph
Area VARCHAR(15),                          -- urban, rural
Weather_Conditions VARCHAR(25),
Vehicle_Type VARCHAR(40)
);

-- Create a file format
CREATE OR REPLACE FILE FORMAT GYM.REPO.FF_CSV 
    TYPE = 'CSV'       -- suits any flat file (tsv, pipe-separated, etc)
    FIELD_DELIMITER = ','
    RECORD_DELIMITER = '\n'
    SKIP_HEADER = 1 ;

-- Create a stage 
CREATE OR REPLACE STAGE STG_GYM;

-- Load the raw file AccidentData.csv into stage

-- Now, query the raw file present in stage:
SELECT $1, $2, $3, $4
FROM @GYM.REPO.STG_GYM/AccidentData.csv
(FILE_FORMAT => GYM.REPO.FF_CSV);

-- Load file from stage in to table : 
COPY INTO GYM.REPO.TBL_ACCIDENTS
FROM @GYM.REPO.STG_GYM
FILES = ('AccidentData.csv')
FILE_FORMAT = (FORMAT_NAME = GYM.REPO.FF_CSV);

-- Glance at table's contents:
SELECT * FROM GYM.REPO.TBL_ACCIDENTS;


-- ######################### LOADING JSON ###########################

CREATE OR REPLACE TABLE GYM.REPO.TBL_PEOPLE(
    PEOPLE_INFO VARIANT 
);

-- Creating another file format to load JSON data
CREATE OR REPLACE FILE FORMAT GYM.REPO.FF_JSON
    TYPE = 'JSON' 
    COMPRESSION = 'AUTO' 
    ALLOW_DUPLICATE = FALSE
    STRIP_OUTER_ARRAY = TRUE
    STRIP_NULL_VALUES = FALSE
    IGNORE_UTF8_ERRORS = FALSE ; 

-- Load the raw file 'people.json' into stage

-- Now, query the raw json file present in stage:
SELECT $1
FROM @GYM.REPO.STG_GYM/people.json
(FILE_FORMAT => GYM.REPO.FF_JSON);

-- Load file from stage in to table : 
COPY INTO GYM.REPO.TBL_PEOPLE
FROM @GYM.REPO.STG_GYM
FILES = ('people.json')
FILE_FORMAT = (FORMAT_NAME = GYM.REPO.FF_JSON);

-- Glance at table's contents : 
SELECT
 PEOPLE_INFO:id AS ID
 ,PEOPLE_INFO:first_name::STRING AS FIRST_NAME
 ,PEOPLE_INFO:last_name::STRING AS LAST_NAME
 ,PEOPLE_INFO:email::STRING AS EMAIL_ID
FROM GYM.REPO.TBL_PEOPLE;

CREATE OR REPLACE VIEW GYM.REPO.VW_PEOPLE_INFO AS 
SELECT
 PEOPLE_INFO:id AS ID
 ,PEOPLE_INFO:first_name::STRING AS FIRST_NAME
 ,PEOPLE_INFO:last_name::STRING AS LAST_NAME
 ,PEOPLE_INFO:email::STRING AS EMAIL_ID
FROM GYM.REPO.TBL_PEOPLE;

-- Instead of creating a view above, CTAS (create table as select) can also be used to create a fresh table as : 

-- CREATE OR REPLACE TABLE GYM.REPO.StructuredTbl_People AS 
-- (SELECT
--  PEOPLE_INFO:id AS ID
--  ,PEOPLE_INFO:first_name::STRING AS FIRST_NAME
--  ,PEOPLE_INFO:last_name::STRING AS LAST_NAME
--  ,PEOPLE_INFO:email::STRING AS EMAIL_ID
-- FROM GYM.REPO.TBL_PEOPLE);
