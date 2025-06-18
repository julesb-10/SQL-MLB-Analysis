--MLB ANALYSIS PROJECT

--PART 1: CREATING TABLES AND IMPORTING DATA


-- Drop tables if they already exist
DROP TABLE IF EXISTS players;
DROP TABLE IF EXISTS salaries;
DROP TABLE IF EXISTS schools;
DROP TABLE IF EXISTS school_details;

--
-- Table structure for `players` table:
--

CREATE TABLE players (
    playerID VARCHAR(20) PRIMARY KEY,
    birthYear INT,
    birthMonth INT,
    birthDay INT,
    birthCountry VARCHAR(50),
    birthState VARCHAR(50),
    birthCity VARCHAR(50),
    deathYear INT,
    deathMonth INT,
    deathDay INT,
    deathCountry VARCHAR(50),
    deathState VARCHAR(50),
    deathCity VARCHAR(50),
    nameFirst VARCHAR(50),
    nameLast VARCHAR(50),
    nameGiven VARCHAR(100),
    weight INT,
    height INT,
    bats CHAR(1),
    throws CHAR(1),
    debut DATE,
    finalGame DATE,
    retroID VARCHAR(20),
    bbrefID VARCHAR(20)
);


-- Table structure for `salaries` table:


CREATE TABLE salaries (
    yearID INT,
    teamID VARCHAR(3),
    lgID VARCHAR(2),
    playerID VARCHAR(20),
    salary INT,
    PRIMARY KEY (yearID, teamID, playerID)
);


-- `school_details` table:

CREATE TABLE school_details (
    schoolID VARCHAR(50) PRIMARY KEY,
    name_full VARCHAR(100),
    city VARCHAR(50),
    state VARCHAR(2),
    country VARCHAR(50)
);

--
-- `schools` table:
--

CREATE TABLE schools (
    playerID VARCHAR(50),
    schoolID VARCHAR(50),
    yearID INT,
    PRIMARY KEY (playerID, schoolID, yearID)
);

--Data imported using PostgreSQL's import tool


--1) In each decade, how many schools were there that produced MLB players?

SELECT ROUND(yearid, -1) AS decade, COUNT(DISTINCT schoolid) AS number_scools --COUNT DISTINCT as there are duplicates
FROM schools
GROUP BY decade
ORDER BY decade;




--2) What are the names of the top 5 schools that produced the most players?

SELECT sd.name_full, COUNT(DISTINCT playerid) AS players_produced
FROM schools s
LEFT JOIN school_details sd 
ON s.schoolid = sd.schoolid
GROUP BY sd.name_full
ORDER BY players_produced DESC
LIMIT 5;





--3) For each decade, what were the names of the top 3 schools that produced the most players?

WITH players_per_decade AS (SELECT ROUND(s.yearid, -1) AS decade, sd.name_full, COUNT(DISTINCT playerid) AS players_produced
							FROM schools s
							LEFT JOIN school_details sd 
								ON s.schoolid = sd.schoolid
							GROUP BY decade, sd.name_full),
	 ranked_by_decade AS (SELECT *,
	   							ROW_NUMBER() OVER(PARTITION BY decade ORDER BY players_produced DESC) AS decade_rank
						 FROM players_per_decade)
SELECT decade, name_full, players_produced, row_num
FROM ranked_by_decade
WHERE row_num <= 3
ORDER BY decade DESC, row_num;
--NOTE: ROW_NUMBER could be switched to RANK() or DENSE_RANK() if ties are desired





-- 4) Return the top 20% of teams in terms of average annual spending

WITH total_annual_spend AS (SELECT teamid, yearid, SUM(salary) AS total_spend
							FROM salaries
							GROUP BY teamid, yearid),
	 pctile_ranks AS (SELECT teamid, AVG(total_spend) AS annual_avg,
						   NTILE(5) OVER(ORDER BY AVG(total_spend) DESC) AS pctile_group
					  FROM total_annual_spend
					  GROUP BY teamid)
SELECT teamid, ROUND(annual_avg / 1000000, 1) as avg_spent_millions
FROM pctile_ranks
WHERE pctile_group = 1
ORDER BY annual_avg DESC;





-- 5) For each team, show the cumulative sum of spending over the years

WITH annual_spend_per_team AS (SELECT teamid, yearid, SUM(salary) AS total_spent_year
							   FROM salaries
							   GROUP BY teamid, yearid
							   ORDER BY teamid, yearid)
SELECT teamid, yearid, total_spent_year,
	   ROUND(SUM(total_spent_year) OVER(PARTITION BY teamid ORDER BY yearid) / 1000000, 1) AS cumulative_spend_millions	
FROM annual_spend_per_team;





-- 6) Return the first year that each team's cumulative spending surpassed 1 billion

WITH annual_spend_per_team AS (SELECT teamid, yearid, SUM(salary) AS total_spent_year
							   FROM salaries
							   GROUP BY teamid, yearid
							   ORDER BY teamid, yearid),
	 cumulative_spent AS (SELECT teamid, yearid, total_spent_year,
							    SUM(total_spent_year) OVER(PARTITION BY teamid ORDER BY yearid) AS cumulative_spend	
						  FROM annual_spend_per_team),
	 bil_spent_year AS (SELECT teamid, yearid, cumulative_spend,
							   ROW_NUMBER() OVER(PARTITION BY teamid ORDER BY cumulative_spend) AS bil_spent	
						FROM cumulative_spent
						WHERE cumulative_spend > 1000000000)
SELECT teamid, yearid, ROUND(cumulative_spend / 1000000000, 2) AS cumulative_spent_billions
FROM bil_spent_year
WHERE bil_spent = 1;






--7) For each player, calculate their age at their first (debut) game, their last game, 
--   and their career length (all in years). Sort from longest career to shortest career.

WITH dates AS (SELECT namegiven, MAKE_DATE(birthyear, birthmonth, birthday) AS date_of_birth,
				      debut, finalgame
			   FROM players),			   
	 ages AS (SELECT namegiven, 
				     EXTRACT(YEAR FROM AGE(debut, date_of_birth)) AS debut_age_yrs,
				     EXTRACT(YEAR FROM AGE(finalgame, date_of_birth)) AS retirement_age_yrs,
				     EXTRACT(YEAR FROM AGE(finalgame, debut)) AS career_length_yrs
			  FROM dates	
			  WHERE debut IS NOT NULL AND finalgame IS NOT NULL AND date_of_birth IS NOT NULL)
SELECT *
FROM ages
ORDER BY career_length_yrs DESC;

--NOTE: If I were using mysql, I could use DATE(CONCAT(birthyear, '-', LPAD(birthmonth, 2, '0'), '-', LPAD(birthday, 2, '0')))
--      to get the full birthday, or use CAST(CONCAT(...) AS DATE)

-- NOTE 2: In POSTGRESQL, I needed to include a filter for NULLs as if any of the EXTRACT
-- 		   functions result to NULL, the entire ordering becomes NULL






--8) What team did each player play on for their starting and ending years?

SELECT p.namegiven,
	   s.yearid AS start_year, s.teamid AS start_team,
	   e.yearid AS end_year, e.teamid AS end_team
FROM   players p
INNER JOIN salaries s  -- INNER JOIN since I only want information on players who've had a full career
	   ON p.playerid = s.playerid
	   AND EXTRACT(YEAR FROM p.debut) = s.yearid
INNER JOIN salaries e  
	   ON p.playerid = e.playerid
	   AND EXTRACT(YEAR FROM p.finalgame) = e.yearid;





--9) How many players started and ended on the same team and also played for over a decade?

WITH careers AS (SELECT p.namegiven,
					    s.yearid AS start_year, s.teamid AS start_team,
					    e.yearid AS end_year, e.teamid AS end_team
				 FROM   players p
				 INNER JOIN salaries s  -- INNER JOIN since we only want information on players who've had a full career
					    ON p.playerid = s.playerid
					    AND EXTRACT(YEAR FROM p.debut) = s.yearid
				 INNER JOIN salaries e  
					    ON p.playerid = e.playerid
					    AND EXTRACT(YEAR FROM p.finalgame) = e.yearid)
SELECT COUNT(*)
FROM careers
WHERE start_team = end_team
AND (end_year - start_year) > 10;

-- NOTE: Used a CTE instead of just adding the WHERE conditions to the previous query for readability purposes





-- 10) Which players have the same birthday?

WITH birthdays AS (SELECT namegiven,
					      MAKE_DATE(birthyear, birthmonth, birthday) AS date_of_birth
				   FROM players)
SELECT b1.namegiven as player1_name, b1.date_of_birth,
	   b2.namegiven as player2_name, b2.date_of_birth
FROM birthdays b1
INNER JOIN birthdays b2
	 ON b1.date_of_birth = b2.date_of_birth
WHERE b1.namegiven < b2.namegiven
ORDER BY b1.date_of_birth DESC; --NOTE: using '<' instead of '<>' to avoid duplicate pairs




-- ALTERNATIVE SOLUTION USING STRING_AGG() (similar to GROUP_CONCAT() in MYSQL)

WITH birthdays AS (SELECT namegiven,
					      MAKE_DATE(birthyear, birthmonth, birthday) AS date_of_birth
				   FROM players)
SELECT date_of_birth, STRING_AGG(namegiven, ', ')
FROM birthdays
WHERE date_of_birth IS NOT NULL
GROUP BY date_of_birth
HAVING COUNT(*) > 1 -- This will make it so only birthdays shared between multiple players are shown
ORDER BY date_of_birth DESC;







-- 11) Create a summary table that shows for each team, what percent of players bat right, left and both.

WITH team_batters AS (SELECT DISTINCT s.teamid, s.playerid, p.bats
					  FROM salaries s
					  LEFT JOIN players p  -- LEFT JOIN since we want info about each team, a column in salaries table
					  	   ON s.playerid = p.playerid
					  WHERE p.bats IS NOT NULL)
SELECT teamid,
		ROUND(SUM(CASE WHEN bats = 'R' THEN 1 ELSE 0 END)::NUMERIC / COUNT(playerid) * 100, 1) AS percent_righty,
		ROUND(SUM(CASE WHEN bats = 'L' THEN 1 ELSE 0 END)::NUMERIC / COUNT(playerid) * 100, 1) AS percent_lefty,
		ROUND(SUM(CASE WHEN bats = 'B' THEN 1 ELSE 0 END)::NUMERIC / COUNT(playerid) * 100, 1) AS percent_switch_hitter
FROM team_batters
GROUP BY teamid
ORDER BY teamid;






-- 12) How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?

WITH decade_avgs AS (SELECT FLOOR(EXTRACT(YEAR FROM debut) / 10) * 10 AS decade, AVG(height) AS avg_height, AVG(weight) AS avg_weight
					 FROM players
					 GROUP BY decade)
SELECT decade,
	   avg_height - LAG(avg_height) OVER(ORDER BY decade) AS dod_height_diff,
	   avg_weight - LAG(avg_weight) OVER(ORDER BY decade) AS dod_weight_diff
FROM decade_avgs
WHERE decade IS NOT NULL;


