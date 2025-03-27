--Part 1: Write SQL queries to retrieve the following data

--- Part 1.1 All animation movies released between 2017 and 2019 with rate more than 1, alphabetical

---- Solution 1: Using INNER JOINs directly
--      This approach uses straightforward INNER JOINs to connect the film table with category
--      information and applies filtering conditions in the WHERE clause.
--      The UPPER function is applied to the category name to ensure case-insensitive matching
SELECT f.title
     , f.release_year
     , f.rental_rate
     , c.name
FROM film f
         INNER JOIN film_category fc on f.film_id = fc.film_id
         INNER JOIN category c on fc.category_id = c.category_id
WHERE f.release_year BETWEEN '2017' AND '2019'
  AND UPPER(c.name) = 'ANIMATION'
  AND f.rental_rate > 1
ORDER BY f.title;

---- Solution 2: Using Common Table Expression (CTE)
--      This approach first creates a temporary result set of all animation films, ensure case-insensitivity
--      then applies year and rate filters to that subset, improving query readability.
WITH animationFilms AS
         (SELECT f.title
               , f.film_id
               , f.release_year
               , f.rental_rate
               , c.name
          FROM film f
                   INNER JOIN film_category fc on f.film_id = fc.film_id
                   INNER JOIN category c on fc.category_id = c.category_id
          WHERE UPPER(c.name) = 'ANIMATION')
SELECT title
     , release_year
     , rental_rate
     , 'Animation' as name
FROM animationFilms
WHERE release_year BETWEEN 2017 AND 2019
  AND rental_rate > 1
ORDER BY title ASC;

--- Part 1.2 The revenue earned by each rental store after March 2017
--          (columns: address and address2 – as one column, revenue)

---- Solution 1: Using staff table as the link between payments and stores
--     Suggested :The staff table serves as the link between payments and stores since staff members are associated with stores.
-- NOTE: This approach may not accurately reflect store revenue if staff members
-- processed payments for rentals from different stores than where they work.
-- The assumption here is that staff members only process payments for their assigned store.
-- This might not accurately reflect which store the inventory item belongs to.
SELECT s.store_id
     , CONCAT(a.address, ' ', COALESCE(a.address2, '')) AS full_address
     , SUM(p.amount)                                    AS revenue
FROM payment p
         INNER JOIN staff sf ON p.staff_id = sf.staff_id
         INNER JOIN store s ON sf.store_id = s.store_id
         INNER JOIN address a ON s.address_id = a.address_id
WHERE p.payment_date >= '2017-04-01'
GROUP BY s.store_id, full_address
ORDER BY revenue DESC;

-- So, if proposed suggestion in Solution 1 is false

----Solution 2: Using inventory to track which store the rental item belongs to
--      This is  can be more accurate approach as it traces revenue back to the store
-- where the inventory item is physically located. This correctly attributes revenue
-- to the store that owns the rental item, regardless of which staff member processed
-- the payment. The inventory.store_id field directly indicates which store owns the item,
-- but at the same time not a FK in this table
WITH post_march_2017_payments AS (SELECT p.rental_id, p.amount
                                  FROM payment p
                                  WHERE p.payment_date >= '2017-04-01')
SELECT s.store_id
        ,
       CONCAT(a.address, ' ', COALESCE(a.address2, '')) AS full_address,
       SUM(pmp.amount)                                  AS revenue
FROM post_march_2017_payments pmp
         INNER JOIN rental r ON pmp.rental_id = r.rental_id
         INNER JOIN inventory i ON r.inventory_id = i.inventory_id
         INNER JOIN store s ON i.store_id = s.store_id
         INNER JOIN address a ON s.address_id = a.address_id
GROUP BY s.store_id
       , full_address
ORDER BY revenue DESC;

--- Part1.3 Top-5 actors by number of movies (released after 2015) they took part in
--      (columns: first_name, last_name, number_of_movies, sorted by number_of_movies in descending order)

----Solution 1: Direct Aggregation with LIMIT
--      Uses COUNT(DISTINCT f.film_id) to avoid counting the same film multiple times
--      Handles cases where an actor might be in multiple copies of the same film
--      Use OFFSET to handle potential ties in movie count
SELECT CONCAT(a.first_name, ' ', a.last_name) as name
     , COUNT(DISTINCT f.film_id)              as number_of_movies
FROM actor a
         LEFT JOIN film_actor fa ON a.actor_id = fa.actor_id
         INNER JOIN film f on fa.film_id = f.film_id
WHERE f.release_year > '2015'
GROUP BY a.actor_id
ORDER BY number_of_movies DESC
LIMIT 5 OFFSET 0;

--- Part 1.4 Number of Drama, Travel, Documentary per year (columns: release_year, number_of_drama_movies,
-- number_of_travel_movies, number_of_documentary_movies), sorted by release year in descending order.
-- Dealing with NULL values is encouraged)

---- Solution 1: Using CTEs for cleaner category filtering and COALESCE for NULL handling
--      This approach uses separate CTEs for each category count, then joins them together
WITH countDramaMovies AS (SELECT f.release_year
                               , COUNT(f.film_id) as number_of_drama_movies
                          FROM film f
                                   INNER JOIN film_category fc on f.film_id = fc.film_id
                                   INNER JOIN category c on fc.category_id = c.category_id
                          WHERE UPPER(c.name) = 'DRAMA'
                          GROUP BY f.release_year)
   , countTravelMovies AS (SELECT f.release_year
                                , COUNT(f.film_id) as number_of_travel_movies
                           FROM film f
                                    INNER JOIN film_category fc on f.film_id = fc.film_id
                                    INNER JOIN category c on fc.category_id = c.category_id
                           WHERE UPPER(c.name) = 'TRAVEL'
                           GROUP BY f.release_year)
   , countDocumentaryMovies AS (SELECT f.release_year
                                     , COUNT(f.film_id) as number_of_documentary_movies
                                FROM film f
                                         INNER JOIN film_category fc on f.film_id = fc.film_id
                                         INNER JOIN category c on fc.category_id = c.category_id
                                WHERE UPPER(c.name) = 'DOCUMENTARY'
                                GROUP BY f.release_year)

SELECT DISTINCT f.release_year
              , COALESCE(d.number_of_drama_movies, 0)         AS number_of_drama_movies
              , COALESCE(t.number_of_travel_movies, 0)        AS number_of_travel_movies
              , COALESCE(doc.number_of_documentary_movies, 0) AS number_of_documentary_movies
FROM film f
         LEFT JOIN countDramaMovies d ON f.release_year = d.release_year
         LEFT JOIN countTravelMovies t ON f.release_year = t.release_year
         LEFT JOIN countDocumentaryMovies doc ON f.release_year = doc.release_year
ORDER BY f.release_year DESC;

---- Solution 2: Using SUM with CASE Expressions and Subquery
--      This approach uses a single query with CASE expressions to pivot category counts
SELECT release_year,
       SUM(CASE WHEN UPPER(c.name) = 'DRAMA' THEN 1 ELSE 0 END)       AS number_of_drama_movies,
       SUM(CASE WHEN UPPER(c.name) = 'TRAVEL' THEN 1 ELSE 0 END)      AS number_of_travel_movies,
       SUM(CASE WHEN UPPER(c.name) = 'DOCUMENTARY' THEN 1 ELSE 0 END) AS number_of_documentary_movies
FROM film f
         INNER JOIN film_category fc ON f.film_id = fc.film_id
         INNER JOIN category c ON fc.category_id = c.category_id
GROUP BY f.release_year
ORDER BY f.release_year DESC;

---- Solution 3: Crosstab Approach with Subquery and CASE Expressions
--      Crosstab (Pivot) Query for Movie Category Counts
SELECT release_year,
       SUM(CASE WHEN category = 'DRAMA' THEN movie_count ELSE 0 END)       AS number_of_drama_movies,
       SUM(CASE WHEN category = 'TRAVEL' THEN movie_count ELSE 0 END)      AS number_of_travel_movies,
       SUM(CASE WHEN category = 'DOCUMENTARY' THEN movie_count ELSE 0 END) AS number_of_documentary_movies
FROM (SELECT f.release_year,
             UPPER(c.name)    AS category,
             COUNT(f.film_id) AS movie_count
      FROM film f
               INNER JOIN film_category fc ON f.film_id = fc.film_id
               INNER JOIN category c ON fc.category_id = c.category_id
      WHERE UPPER(c.name) IN ('DRAMA', 'TRAVEL', 'DOCUMENTARY')
      GROUP BY f.release_year, c.name) subq
GROUP BY release_year
ORDER BY release_year DESC;

-- Part 2: Solve the following problems using SQL

--- Part 2.1 Which three employees generated the most revenue in 2017?
-- They should be awarded a bonus for their outstanding performance.
--  Assumptions:
--  staff could work in several stores in a year, please indicate which store the staff worked in (the last one);
--  if staff processed the payment then he works in the same store;
--  take into account only payment_date

---- Solution 1: Using CTEs for better readability and organization
--      Revenue is based on payment amounts processed by each staff member
--      Only payments with a payment_date in 2017 are considered
--      Staff are assumed to work at their most recently assigned store
--      The query includes detailed store location information for award notifications
--      This query follows the complete transaction flow:
--      payment → rental → inventory → store, which better represents how revenue is generated
--      through the DVD rental process.
WITH staffRevenue2017 AS (SELECT p.staff_id
                               , ROUND(SUM(amount), 2) AS total_revenue
                          FROM payment p
                                   JOIN rental r ON p.rental_id = r.rental_id
                                   JOIN inventory i ON r.inventory_id = i.inventory_id
                          WHERE EXTRACT(YEAR FROM payment_date) = 2017
                          GROUP BY p.staff_id),

     storeAddresses AS (SELECT st.store_id
                             , CONCAT(a.address, ' ', a.address2) as store_address
                        FROM store st
                                 JOIN
                             address a ON st.address_id = a.address_id)
SELECT s.staff_id
     , CONCAT(s.first_name, ' ', s.last_name)
     , s.store_id as store_working_place
     , sa.store_address
     , sr.total_revenue
FROM staff s
         JOIN
     staffRevenue2017 sr ON s.staff_id = sr.staff_id
         JOIN
     storeAddresses sa ON s.store_id = sa.store_id
ORDER BY sr.total_revenue DESC
LIMIT 3;

--- Part2.2 Which 5 movies were rented more than others (number of rentals),
-- and what's the expected age of the audience for these movies?
-- To determine expected age please use 'Motion Picture Association film rating system

----Solution 1: Map MPA ratings to expected audience age descriptions
--      The Motion Picture Association (MPA) film rating system is used to rate a film's
--      suitability for certain audiences based on its content. Understanding which ratings
--      are most popular can help with inventory planning and targeted marketing.

SELECT f.film_id
     , f.title
     , f.rating
     , COUNT(r.rental_id) AS times_rented
     , CASE
           WHEN f.rating = 'G' THEN 'All ages (General Audiences)'
           WHEN f.rating = 'PG' THEN 'Children with parental guidance (Parental Guidance Suggested)'
           WHEN f.rating = 'PG-13' THEN 'Ages 13+ (Parents Strongly Cautioned)'
           WHEN f.rating = 'R' THEN 'Ages 17+ with guardian (Restricted)'
           WHEN f.rating = 'NC-17' THEN 'Ages 18+ only (Adults Only)'
           ELSE 'Unrated'
    END                   AS expected_audience
FROM rental r
         INNER JOIN inventory i on r.inventory_id = i.inventory_id
         INNER JOIN film f on i.film_id = f.film_id
GROUP BY f.title, f.rating, f.film_id
ORDER BY times_rented DESC
LIMIT 5;

---- Solution 2: Using a CTE for clarity and organization
--      This approach uses a Common Table Expression (CTE) to separate the data gathering
--      from the final selection. This improves readability and makes it easier to modify
--      just one part of the query if needed.

WITH movieRentalStats AS (SELECT f.film_id,
                                 f.title,
                                 f.rating,
                                 COUNT(r.rental_id) AS times_rented
                          FROM film f
                                   JOIN
                               inventory i ON f.film_id = i.film_id
                                   JOIN
                               rental r ON i.inventory_id = r.inventory_id
                          GROUP BY f.film_id, f.title, f.rating)
SELECT film_id,
       title,
       rating,
       times_rented,
       CASE
           WHEN rating = 'G' THEN 'All ages (General Audiences)'
           WHEN rating = 'PG' THEN 'Children with parental guidance (Parental Guidance Suggested)'
           WHEN rating = 'PG-13' THEN 'Ages 13+ (Parents Strongly Cautioned)'
           WHEN rating = 'R' THEN 'Ages 17+ with guardian (Restricted)'
           WHEN rating = 'NC-17' THEN 'Ages 18+ only (Adults Only)'
           ELSE 'Unrated'
           END AS expected_audience
FROM movieRentalStats
ORDER BY times_rented DESC
LIMIT 5;

-- Part 3. Which actors/actresses didn't act for a longer period of time than the others?
--      The task can be interpreted in various ways, and here are a few options:
-- V1: gap between the latest release_year and current year per each actor;
-- V2: gaps between sequential films per each actor;


--- Part 3. V1: gap between the latest release_year and current year per each actor

---- Solution 1: This query finds 20 actors who haven't appeared in films for the longest time
--      based on the gap between their most recent film's release year and the current year.
--     CTE used to find the most recent film for each actor, than labeled and sorted in a query

----     Note: cant add film title to CTE in a GROUP BY clause
--      This would change the meaning of MAX(f.release_year) to find the maximum release year per film
--      rather than per actor.
--          film titles joined afterward based on that latest_film_year

WITH actorLastFilm AS (SELECT a.actor_id
                            , CONCAT(a.first_name, ' ', a.last_name) as actor_name
                            , MAX(f.release_year)                    AS latest_film_year
                       FROM actor a
                                JOIN
                            film_actor fa ON a.actor_id = fa.actor_id
                                JOIN
                            film f ON fa.film_id = f.film_id
                       GROUP BY a.actor_id)
SELECT alf.actor_id
     , alf.actor_name
     , alf.latest_film_year
     , EXTRACT(YEAR FROM CURRENT_DATE) - alf.latest_film_year AS years_inactive
     , CASE
           WHEN EXTRACT(YEAR FROM CURRENT_DATE) - alf.latest_film_year >= 10 THEN 'Likely retired'
           WHEN EXTRACT(YEAR FROM CURRENT_DATE) - alf.latest_film_year >= 5 THEN 'Extended hiatus'
           WHEN EXTRACT(YEAR FROM CURRENT_DATE) - alf.latest_film_year >= 2 THEN 'Short break'
           ELSE 'Recently active'
    END                                                       AS activity_status
     , (SELECT f.title -- subquery to fetch just one film title for each actor
        FROM film f
                 JOIN film_actor fa ON f.film_id = fa.film_id
        WHERE fa.actor_id = alf.actor_id
          AND f.release_year = alf.latest_film_year
        LIMIT 1)                                              AS most_recent_film
FROM actorLastFilm alf
ORDER BY years_inactive DESC
LIMIT 20;

--- Part 3. V2: gaps between sequential films per each actor

---- Solution 1: This approach leverages the fact that for each actor, we can identify consecutive films
--      by joining the actor's films with films released later and finding the ones with
--      the smallest possible gap.

-- 1.Creates a CTE with all films for each actor
-- 2.Joins each film with other films by the same actor released later
-- 3.Uses NOT EXISTS to ensure there's no other film released between them (making them consecutive)
-- 4.Finds the maximum gap for each actor from these consecutive film pairs

-- Get all films per actor
WITH actorFilms AS (SELECT a.actor_id
                         , CONCAT(a.first_name, ' ', a.last_name) as actor_name
                         , f.film_id
                         , f.title
                         , f.release_year
                    FROM actor a
                             JOIN
                         film_actor fa ON a.actor_id = fa.actor_id
                             JOIN
                         film f ON fa.film_id = f.film_id),

-- Calculate gaps between films for each actor
     actorFilmGaps AS (SELECT af1.actor_id
                            , af1.actor_name
                            , af1.film_id                         AS film1_id
                            , af1.title                           AS film1_title
                            , af1.release_year                    AS film1_year
                            , af2.film_id                         AS film2_id
                            , af2.title                           AS film2_title
                            , af2.release_year                    AS film2_year
                            , af2.release_year - af1.release_year AS year_gap
                       FROM actorFilms af1
                                JOIN
                            actorFilms af2 ON
                                af1.actor_id = af2.actor_id AND
                                af1.release_year < af2.release_year AND
                                    -- Find films where there's no other film released between them
                                NOT EXISTS (SELECT 1
                                            FROM actorFilms af3
                                            WHERE af3.actor_id = af1.actor_id
                                              AND af3.release_year > af1.release_year
                                              AND af3.release_year < af2.release_year)),

-- Find the maximum gap for each actor
     maxGapsPerActor AS (SELECT actor_id
                              , MAX(year_gap) AS max_gap
                         FROM actorFilmGaps
                         GROUP BY actor_id)

-- Join back to get the complete information about the gap
SELECT afg.actor_id
     , afg.actor_name
     , afg.film1_title AS earlier_film
     , afg.film1_year  AS earlier_year
     , afg.film2_title AS later_film
     , afg.film2_year  AS later_year
     , afg.year_gap
     , CASE
           WHEN year_gap >= 10 THEN 'Likely retired'
           WHEN year_gap >= 5 THEN 'Extended hiatus'
           WHEN year_gap >= 2 THEN 'Short break'
           ELSE 'Recently active'
    END                AS activity_status
FROM actorFilmGaps afg
         JOIN
     maxGapsPerActor mg ON
         afg.actor_id = mg.actor_id AND
         afg.year_gap = mg.max_gap
ORDER BY afg.year_gap DESC, afg.actor_name
LIMIT 20;
