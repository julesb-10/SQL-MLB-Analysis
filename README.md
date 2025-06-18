# MLB SQL Analysis Project

This project explores Major League Baseball (MLB) data using PostgreSQL. It includes a full workflow: creating tables, importing data, and writing advanced queries to analyze players, teams, salaries, schools, and trends over time. The questions answered reflect data insights that could easily be extended to business scenarios

---

## Project Structure

- `mlb_analysis.sql` – Main SQL script containing:
  - Table creation statements
  - Data import notes
  - Answers to 12 analytical questions using SQL
- `/images/` – Screenshots showing imported table previews
- `README.md` – Project documentation

---

## Tools Used

- **PostgreSQL**  
  This project uses advanced PostgreSQL (and general SQL) features including:
  - Common Table Expressions (CTEs)
  - Window functions (`ROW_NUMBER`, `NTILE`, `LAG`)
  - Conditional aggregation with `CASE`
  - Date and time functions (`MAKE_DATE`, `EXTRACT`, `AGE`)
  - Data transformation and joins

---


## Cross-Database Compatibility Notes

Whenever PostgreSQL-specific functions are used in the queries, I am always aware of the equivalent approach or function that could be used in MySQL. For example, in **Query 7**, which calculates player ages and career lengths, I use `MAKE_DATE` and `EXTRACT(YEAR FROM AGE(...))` in PostgreSQL. In the SQL file, I include a note on how to achieve the same result in MySQL using either `DATE(CONCAT(...))` or `CAST(CONCAT(...) AS DATE)`, along with commentary on the behavior of NULLs and how PostgreSQL handles ordering when NULLs are present.

---

## Datasets and Schema

Tables created:
- `players`
- `salaries`
- `schools`
- `school_details`

> Data was imported using PostgreSQL’s built-in import tool. Screenshots of table previews may be included in the `/images` folder. My apologies for the inconvenience.

---

## Questions Answered

1. In each decade, how many schools were there that produced MLB players?
2. What are the names of the top 5 schools that produced the most players?
3. For each decade, what were the names of the top 3 schools that produced the most players?
4. Return the top 20% of teams in terms of average annual spending
5. For each team, show the cumulative sum of spending over the years
6. Return the first year that each team's cumulative spending surpassed 1 billion
7. For each player, calculate their age at their first (debut) game, their last game, and their career length (all in years). Sort from longest career to shortest career.
8. What team did each player play on for their starting and ending years?
9. How many players started and ended on the same team and also played for over a decade?
10. Which players have the same birthday?
11. Create a summary table that shows for each team, what percent of players bat right, left and both.
12. How have average height and weight at debut game changed over the years, and what's the decade-over-decade difference?

---

## Sample Query

```sql
-- Calculate age at debut, age at retirement, and career length
WITH dates AS (
  SELECT namegiven,
         MAKE_DATE(birthyear, birthmonth, birthday) AS date_of_birth,
         debut, finalgame
  FROM players
),
ages AS (
  SELECT namegiven,
         EXTRACT(YEAR FROM AGE(debut, date_of_birth)) AS debut_age_yrs,
         EXTRACT(YEAR FROM AGE(finalgame, date_of_birth)) AS retirement_age_yrs,
         EXTRACT(YEAR FROM AGE(finalgame, debut)) AS career_length_yrs
  FROM dates
  WHERE debut IS NOT NULL AND finalgame IS NOT NULL AND date_of_birth IS NOT NULL
)
SELECT *
FROM ages
ORDER BY career_length_yrs DESC;

