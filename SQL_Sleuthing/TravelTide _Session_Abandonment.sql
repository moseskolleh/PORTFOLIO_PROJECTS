/*
 Question #1: 
 Calculate the proportion of sessions abandoned in summer months 
 (June, July, August) and compare it to the proportion of sessions abandoned 
 in non-summer months. Round the output to 3 decimal places.
 
 Expected column names: summer_abandon_rate, other_abandon_rate
 */
-- q1 solution:
SELECT
    ROUND(
        SUM(
            CASE
                WHEN EXTRACT(
                    MONTH
                    FROM
                        session_start
                ) IN (6, 7, 8)
                AND NOT flight_booked
                AND NOT hotel_booked THEN 1
                ELSE 0
            END
        ) :: decimal / SUM(
            CASE
                WHEN EXTRACT(
                    MONTH
                    FROM
                        session_start
                ) IN (6, 7, 8) THEN 1
                ELSE 0
            END
        ),
        3
    ) AS summer_abandon_rate,
    ROUND(
        SUM(
            CASE
                WHEN EXTRACT(
                    MONTH
                    FROM
                        session_start
                ) NOT IN (6, 7, 8)
                AND NOT flight_booked
                AND NOT hotel_booked THEN 1
                ELSE 0
            END
        ) :: decimal / SUM(
            CASE
                WHEN EXTRACT(
                    MONTH
                    FROM
                        session_start
                ) NOT IN (6, 7, 8) THEN 1
                ELSE 0
            END
        ),
        3
    ) AS other_abandon_rate
FROM
    sessions;

-- my observations about the output of my solution to q1
/*
 -- The results show that the abandonment rates are quite similar across summer (0.564) and non-summer months (0.57), suggesting seasonality has a minimal impact on session abandonment. 
 -- This indicates a consistent user behavior pattern throughout the year and highlights the need to investigate other factors that might influence session abandonment
 */


/*
 Question #2: 
 Bin customers according to their place in the session abandonment distribution as follows: 
 
 1. number of abandonments greater than one standard deviation more than the mean. Call these customers “gt”.
 2. number of abandonments fewer than one standard deviation less than the mean. Call these customers “lt”.
 3. everyone else (the middle of the distribution). Call these customers “middle”.
 
 calculate the number of customers in each group, the mean number of abandonments in each group, and the range of abandonments in each group.
 
 Expected column names: distribution_loc, abandon_n, abandon_avg, abandon_range
 
 */
-- q2 solution:
WITH user_abandonments AS (
    SELECT
        user_id,
        COUNT(*) AS abandon_count
    FROM
        sessions
    WHERE
        NOT flight_booked
        AND NOT hotel_booked
    GROUP BY
        user_id
),
abandonment_stats AS (
    SELECT
        AVG(abandon_count) AS mean_abandon,
        STDDEV(abandon_count) AS stddev_abandon
    FROM
        user_abandonments
),
categorized_users AS (
    SELECT
        ua.user_id,
        ua.abandon_count,
        CASE
            WHEN ua.abandon_count > (ab_stats.mean_abandon + ab_stats.stddev_abandon) THEN 'gt'
            WHEN ua.abandon_count < (ab_stats.mean_abandon - ab_stats.stddev_abandon) THEN 'lt'
            ELSE 'middle'
        END AS distribution_loc
    FROM
        user_abandonments ua
        CROSS JOIN abandonment_stats ab_stats
)
SELECT
    distribution_loc,
    COUNT(user_id) AS abandon_n,
    ROUND(AVG(abandon_count), 3) AS abandon_avg,
    MAX(abandon_count) - MIN(abandon_count) AS abandon_range
FROM
    categorized_users
GROUP BY
    distribution_loc;

-- Observations about the output of my solution to q2
/*
 -- A substantial number of customers fall into the 'middle' category, indicating a majority have abandonment numbers close to the average.
 -- The 'lt' group, having exactly 1 abandonment each, might represent occasional or first-time users.
 -- The 'gt' group shows a high variance in abandonment behavior, indicating this group could include frequent users or those who often browse without making bookings.
 -- The high mean abandonment in the 'gt' group suggests a potential area for business improvement, perhaps by understanding the reasons behind these frequent abandonments.
 -- The zero range in the 'lt' group suggests a very consistent behavior among these users, which might be useful for targeted marketing or user engagement strategies.
 */


/*
 Question #3: 
 Calculate the total number of abandoned sessions and the total number of sessions 
 that resulted in a booking per day, but only for customers who reside in one of the 
 top 5 cities (top 5 in terms of total number of users from city). 
 Also calculate the ratio of booked to abandoned for each day. 
 Return only the 5 most recent days in the dataset.
 
 Expected column names: session_date, abandoned,booked, book_abandon_ratio
 
 */
-- q3 solution:
WITH top_cities AS (
    SELECT
        home_city
    FROM
        users
    GROUP BY
        home_city
    ORDER BY
        COUNT(*) DESC
    LIMIT
        5
), daily_sessions AS (
    SELECT
        DATE(session_start) AS session_date,
        u.home_city,
        COUNT(*) FILTER (
            WHERE
                NOT flight_booked
                AND NOT hotel_booked
        ) AS abandoned,
        COUNT(*) FILTER (
            WHERE
                flight_booked
                OR hotel_booked
        ) AS booked
    FROM
        sessions s
        JOIN users u ON s.user_id = u.user_id
    WHERE
        u.home_city IN (
            SELECT
                home_city
            FROM
                top_cities
        )
    GROUP BY
        session_date,
        u.home_city
)
SELECT
    session_date,
    SUM(abandoned) AS abandoned,
    SUM(booked) AS booked,
    ROUND(SUM(booked) * 1.0 / SUM(abandoned), 3) AS book_abandon_ratio
FROM
    daily_sessions
GROUP BY
    session_date
HAVING
    SUM(abandoned) > 0
ORDER BY
    session_date DESC
LIMIT
    5;

-- Observations about the output of my solution to q3
/* 
 - The book-to-abandon ratios are relatively high, close to 1. This suggests that for nearly every abandoned session, there's almost one booked session. It indicates a good level of engagement and conversion among users from the top 5 cities.
 - Despite the high abandonment numbers, the conversion (booking) rates are also high, which could be seen as a positive indicator of user interest and potential for revenue.
 - The consistency of these ratios over the observed days suggests a stable user behavior pattern in terms of session engagement and booking.
 - Focusing on the reasons behind session abandonment in these top cities might provide insights for further improving the booking rates.
 - These observations are specific to the top 5 cities by user count, which may exhibit different patterns compared to other cities or the overall user base
 */


/*
 Question #4: 
 Densely rank users from Saskatoon based on their ratio of successful bookings to abandoned bookings. 
 then count how many users share each rank, with the most common ranks listed first.
 
 note: if the ratio of bookings to abandons is null for a user, 
 use the average bookings/abandons ratio of all Saskatoon users.
 
 Expected column names: ba_rank, rank_count
 */
-- q4 solution:
WITH saskatoon_users AS (
    SELECT
        user_id
    FROM
        users
    WHERE
        home_city = 'saskatoon'
),
session_ratios AS (
    SELECT
        su.user_id,
        SUM(
            CASE
                WHEN (
                    flight_booked
                    OR hotel_booked
                )
                AND NOT cancellation THEN 1
                ELSE 0
            END
        ) AS bookings,
        SUM(
            CASE
                WHEN NOT flight_booked
                AND NOT hotel_booked
                AND NOT cancellation THEN 1
                ELSE 0
            END
        ) AS abandons
    FROM
        sessions s
        JOIN saskatoon_users su ON s.user_id = su.user_id
    GROUP BY
        su.user_id
),
average_ratio AS (
    SELECT
        AVG(bookings * 1.0 / NULLIF(abandons, 0)) AS avg_ratio
    FROM
        session_ratios
),
user_rankings AS (
    SELECT
        user_id,
        COALESCE(
            bookings * 1.0 / NULLIF(abandons, 0),
            (
                SELECT
                    avg_ratio
                FROM
                    average_ratio
            )
        ) AS ba_ratio
    FROM
        session_ratios
),
ranked_users AS (
    SELECT
        DENSE_RANK() OVER (
            ORDER BY
                ba_ratio DESC
        ) AS ba_rank,
        user_id
    FROM
        user_rankings
)
SELECT
    ba_rank,
    COUNT(user_id) AS rank_count
FROM
    ranked_users
GROUP BY
    ba_rank
ORDER BY
    rank_count DESC;

-- Observations about the output of my solution to q4
/*
 - The data shows a diverse range of booking to abandonment ratios among Saskatoon users, as indicated by the variety of ranks and the number of users in each rank.
 - Rank 47 and rank 20 are the most common, suggesting these ratios are typical behaviors for a large segment of users.
 - Popularity of certain ranks (like 47 and 20) highlights specific user segments that could be key targets for engagement and conversion improvement strategies.
 - The spread across different ranks offers insights into varied user preferences and behaviors, which can inform more personalized user experiences or tailored offers.
 */
