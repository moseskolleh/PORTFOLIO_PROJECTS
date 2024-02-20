
-- 1.a
SELECT
  age_group,
  gender,
  COUNT(*) AS travel_count
FROM
  (
    SELECT
      CASE
        WHEN (
          EXTRACT(
            YEAR
            FROM
              CURRENT_DATE
          ) - EXTRACT(
            YEAR
            FROM
              birthdate
          )
        ) BETWEEN 18 AND 25  THEN '18-25'
        WHEN (
          EXTRACT(
            YEAR
            FROM
              CURRENT_DATE
          ) - EXTRACT(
            YEAR
            FROM
              birthdate
          )
        ) BETWEEN 26 AND 35  THEN '26-35'
        WHEN (
          EXTRACT(
            YEAR
            FROM
              CURRENT_DATE
          ) - EXTRACT(
            YEAR
            FROM
              birthdate
          )
        ) BETWEEN 36 AND 45  THEN '36-45'
        WHEN (
          EXTRACT(
            YEAR
            FROM
              CURRENT_DATE
          ) - EXTRACT(
            YEAR
            FROM
              birthdate
          )
        ) > 45 THEN '46+'
        ELSE 'Unknown'
      END AS age_group,
      gender,
      user_id
    FROM
      users
  ) AS age_gender_group
  JOIN sessions ON age_gender_group.user_id = sessions.user_id
  JOIN flights ON sessions.trip_id = flights.trip_id
GROUP BY
  age_group,
  gender
ORDER BY
  travel_count DESC;

-- 1.a Explanation:
-- This query calculates the age of users and groups them into age brackets, then counts the number of travels for each age and gender group.

-- 1.b 
SELECT
  married,
  has_children,
  COUNT(*) AS booking_count
FROM
  users
  JOIN sessions ON users.user_id = sessions.user_id
  JOIN flights ON sessions.trip_id = flights.trip_id
GROUP BY
  married,
  has_children
ORDER BY
  booking_count DESC;

-- 1.b Explanation:
-- This query examines the travel behavior based on marital status and children, providing direct insights into different travel patterns.

/* 1.b Interesting Observations:
- This query can provide insights into how marital and parental status impact travel behavior.
- For example, married users with children travel less frequently compared to single, childless users.
- Such insights are valuable for customizing travel packages and marketing strategies for different customer segments.
*/
-- 2.a 
SELECT
  100.0 * SUM(
    CASE
      WHEN s.trip_id IS NULL
      OR (
        s.flight_booked = '0'
        AND s.hotel_booked = '0'
      ) THEN 1
      ELSE 0
    END
  ) / COUNT(*) AS abandonment_rate
FROM
  sessions s;

-- 2.a Explanation:
-- This query calculates the session abandonment rate directly, showing the percentage of sessions that did not result in a booking.

-- 2.b 
SELECT 
    u.gender, 
    u.married, 
    u.has_children, 
    100.0 * SUM(CASE 
                   WHEN f.trip_id IS NULL AND h.trip_id IS NULL THEN 1 
                   ELSE 0 
               END) / COUNT(*) AS abandonment_rate
FROM 
    users u
JOIN 
    sessions s ON u.user_id = s.user_id
LEFT JOIN 
    flights f ON s.trip_id = f.trip_id
LEFT JOIN 
    hotels h ON s.trip_id = h.trip_id
GROUP BY 
    u.gender, u.married, u.has_children;


-- 2.b Explanation:
-- This query identifies which demographic groups have higher session abandonment rates by calculating the rate for each group.

-- 3
SELECT
  users.home_city,
  flights.destination,
  COUNT(*) AS travel_count
FROM
  users
  JOIN sessions ON users.user_id = sessions.user_id
  JOIN flights ON sessions.trip_id = flights.trip_id
GROUP BY
  users.home_city,
  flights.destination
ORDER BY
  users.home_city,
  travel_count DESC;

-- 3 Explanation:
-- This query reveals the travel preferences of users based on their home city by showing the count of travels to various destinations.

-- 4 Recommendations

--Strategic Recommendations:
-- Tailor marketing and service offerings to the age (36-49 years) and gender (specifically male) group traveling the most.
-- Offer customized travel packages based on marital status and children especially single and married that are childless.
-- Develop strategies to reduce session abandonment, focusing on demographics with higher abandonment rates especially female that are married and with children.
-- Create city-specific travel offers and promotions based on geographic travel preferences particularly for Akron to New York.
