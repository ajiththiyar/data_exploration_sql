-- Following SQL queries are used to explore the Covid dataset and extract meaningful insights 
-- regarding cases, deaths, infection rates, and vaccination status across different countries and continents. 
-- Data is sourced from the Covid dataset and the vaccines dataset, providing a comprehensive view of the pandemic's impact globally.
-- Link: https://docs.owid.io/projects/etl/api/covid/#download-data


/* The latest day in the dataset with country that has the maximum cases to death ratio is shown in the below SQL query*/
WITH rank_cases_deaths AS
(SELECT 
    country, date, total_deaths, total_cases,
    RANK() 
    OVER(PARTITION BY country 
    ORDER BY total_cases DESC, total_deaths DESC, date DESC) AS rank_total_cases
FROM covid 
WHERE total_cases != 0 
  AND continent IS NOT NULL)

SELECT country, date, total_cases, total_deaths, 
CAST(((total_deaths*1.0)/(total_cases*1.0))*100.0 AS DECIMAL(10,2)) AS cases_to_death_ratio
FROM rank_cases_deaths
WHERE rank_total_cases = 1
ORDER BY cases_to_death_ratio DESC


/* Maximum infected percentage of the population per country(Infection Rate vs Population)*/
SELECT country, MAX(total_cases) AS max_total_cases, population, 
CAST((MAX(total_cases)*1.0)/(population*1.0)*100.0 AS DECIMAL(10,2)) AS max_infected_percentage
FROM covid
GROUP BY country, population, continent
HAVING continent IS NOT NULL
ORDER BY max_infected_percentage DESC


/*Tracking the likelihood of dying if infected in a specific country over time*/
SELECT country, date, total_cases, total_deaths, 
CAST((total_deaths*1.0 / total_cases*1.0) * 100.0 AS DECIMAL(10,3)) AS death_percentage
FROM covid
WHERE country LIKE 'China' -- Can be swapped for any country
ORDER BY country, date;


/* Maximum death count for each continent*/
SELECT country, MAX(total_deaths) AS max_total_deaths
FROM covid
GROUP BY continent, country
HAVING continent IS NULL
ORDER BY max_total_deaths DESC


/* Global cases and deaths*/
SELECT SUM(new_cases) AS global_cases, SUM(new_deaths) AS global_deaths
FROM covid 
WHERE continent IS NOT NULL
ORDER BY global_cases DESC


/* Country rank within its continent based on total deaths*/
SELECT continent, country, MAX(total_deaths) total_deaths, 
RANK() OVER(PARTITION BY continent ORDER BY MAX(total_deaths) DESC) country_rank
FROM covid
GROUP BY country, continent 
HAVING continent IS NOT NULL


/* Check for each continent with problematic countries having high unvaccinated population
and label them as High Risk, Moderate Risk or Low Risk.*/
WITH latest_unvaccinated_info AS(
SELECT MAX(date) date,country, MIN(people_unvaccinated) unvaccinated_people 
FROM vaccines
GROUP BY country
),
percent_unvaccinated_info AS (
SELECT cov.continent, cov.country, vac.date,
(vac.unvaccinated_people*1.0)/(cov.population*1.0)*100.0 percent_unvaccinated
FROM covid cov JOIN latest_unvaccinated_info vac ON cov.country=vac.country 
AND cov.date=vac.date
WHERE cov.continent IS NOT NULL
),
unvaccinated_labelled AS(
SELECT continent,
COUNT(CASE WHEN percent_unvaccinated < 35 THEN 1 END) AS low_risk,
COUNT(CASE WHEN percent_unvaccinated < 65 AND percent_unvaccinated >= 35 THEN 1 END) AS moderate_risk,
COUNT(CASE WHEN percent_unvaccinated >= 65 THEN 1 END) AS high_risk
FROM percent_unvaccinated_info
GROUP BY continent, percent_unvaccinated
)

SELECT continent, COUNT(CASE WHEN low_risk = 1 THEN 1 END) AS low_risk_countries,
COUNT(CASE WHEN moderate_risk = 1 THEN 1 END) AS moderate_risk_countries,
COUNT(CASE WHEN high_risk = 1 THEN 1 END) AS high_risk_countries
FROM unvaccinated_labelled
GROUP BY continent
ORDER BY continent DESC;
