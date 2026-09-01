## COVID-19 Global Health Insights: SQL Data Exploration Portfolio
##  Project Overview
This repository contains an advanced SQL data exploration project designed to uncover actionable insights from global pandemic data. Using data from Our World in Data (OWID), the analysis tracks key epidemiological metrics across countries and continents to quantify risk, assess outcomes, and evaluate vaccination coverage.

* Data Sourced From: Our World in Data (OWID) ETL Portal
* Core Analytics Focus: Fatality ratios, population infection thresholds, time-series progression, geographical risk stratifications, and cross-dataset vaccination gaps.

------------------------------
##  Technical Competencies Demonstrated

* Advanced Analytical Functions: Window Functions (RANK(), PARTITION BY).
* Complex Data Formatting: Conditional calculations using CASE WHEN and precise numeric typecasting (CAST to DECIMAL).
* Data Structuring: Multi-layered Common Table Expressions (CTEs) for advanced dataset isolation.
* Relational Mechanics: Complex multi-key relational joins (JOIN ON) and dataset filtering via HAVING and aggregation clauses.

------------------------------
## Key SQL Inquiries & Analytics Workflows
## 1. Case-to-Death Ratio Evaluation
Isolates each country's peak infection window to identify the absolute maximum mortality-to-infection ratio while stripping out unpopulated geographical anomalies.
```sql
WITH rank_cases_deaths AS
(SELECT 
    country, date, total_deaths, total_cases,
    RANK() 
    OVER(PARTITION BY country 
    ORDER BY total_cases DESC, total_deaths DESC, date DESC) AS rank_total_casesFROM covid WHERE total_cases != 0 
  AND continent IS NOT NULL)
SELECT country, date, total_cases, total_deaths, 
CAST(((total_deaths*1.0)/(total_cases*1.0))*100.0 AS DECIMAL(10,2)) AS cases_to_death_ratio
FROM rank_cases_deaths WHERE rank_total_cases = 1
ORDER BY cases_to_death_ratio DESC;
```

## 2. Maximum Population Infection Thresholds
Calculates the absolute upper bound of a country's population that contracted the virus, standardizing the comparison across globally disproportionate population brackets.
```sql
SELECT country, MAX(total_cases) AS max_total_cases, population, 
CAST((MAX(total_cases)*1.0)/(population*1.0)*100.0 AS DECIMAL(10,2)) AS max_infected_percentage
FROM covid GROUP BY country, population, continent
HAVING continent IS NOT NULL ORDER BY max_infected_percentage DESC;
```

## 3. Time-Series Mortality Progression
Tracks the shifting probability of mortality if infected within a specific region (parameterized for 'China') to analyze how clinical outcomes scaled over time.
```sql
SELECT country, date, total_cases, total_deaths, 
CAST((total_deaths*1.0 / total_cases*1.0) * 100.0 AS DECIMAL(10,3)) AS death_percentage
FROM covid WHERE country LIKE 'China' ORDER BY country, date;
```

## 4. Macro-Continental Impact Metrics
Aggregates broad continental benchmarks by parsing out records where localized country values are null, delivering localized global metrics.
```sql
SELECT country, MAX(total_deaths) AS max_total_deaths
FROM covid GROUP BY continent, country
HAVING continent IS NULL
ORDER BY max_total_deaths DESC;
```

## 5. Global Total Cases and Deaths
Sums up all the deaths and cases in the world.
```sql
SELECT SUM(new_cases) AS global_cases, SUM(new_deaths) AS global_deaths
FROM covid WHERE continent IS NOT NULL
ORDER BY global_cases DESC;
```

## 6. Intra-Continental Competitive Rankings
Utilizes window partitioning to dynamically rank sovereign nations based on total casualties exclusively against neighboring peers within their respective continents.
```sql
SELECT continent, country, MAX(total_deaths) total_deaths, 
RANK() OVER(PARTITION BY continent ORDER BY MAX(total_deaths) DESC) country_rank
FROM covid GROUP BY country, continent HAVING continent IS NOT NULL;
```

## 7. Cross-Dataset Vaccine Risk Stratification
Joins the transactional epidemiology dataset with separate immunization logs. Leverages multi-tier nested CTEs to categorize entire continents based on the concentration of highly vulnerable, unvaccinated populations.
```sql
WITH latest_unvaccinated_info AS(
    SELECT MAX(date) date, country, MIN(people_unvaccinated) unvaccinated_people FROM vaccines GROUP BY country
),
percent_unvaccinated_info AS (
    SELECT cov.continent, cov.country, vac.date,
    (vac.unvaccinated_people*1.0)/(cov.population*1.0)*100.0 percent_unvaccinated
    FROM covid cov JOIN latest_unvaccinated_info vac ON cov.country=vac.country AND cov.date=vac.date WHERE cov.continent IS NOT NULL
),
unvaccinated_labelled AS(
    SELECT continent,
    COUNT(CASE WHEN percent_unvaccinated < 35 THEN 1 END) AS low_risk,
    COUNT(CASE WHEN percent_unvaccinated < 65 AND percent_unvaccinated >= 35 THEN 1 END) AS moderate_risk,
    COUNT(CASE WHEN percent_unvaccinated >= 65 THEN 1 END) AS high_risk
    FROM percent_unvaccinated_info GROUP BY continent, percent_unvaccinated
)
SELECT continent, COUNT(CASE WHEN low_risk = 1 THEN 1 END) AS low_risk_countries,
COUNT(CASE WHEN moderate_risk = 1 THEN 1 END) AS moderate_risk_countries,
COUNT(CASE WHEN high_risk = 1 THEN 1 END) AS high_risk_countries
FROM unvaccinated_labelled GROUP BY continent
ORDER BY continent DESC;
```
