/*
Question #1: 
Installers receive performance based year end bonuses. Bonuses are calculated by taking 10% of the total value of parts installed by the installer.

Calculate the bonus earned by each installer rounded to a whole number. Sort the result by bonus in increasing order.

Expected column names: name, bonus
*/

-- q1 solution:

-- Selecting the installer's name and their calculated bonus
SELECT i.name,
-- Rounding the sum of the parts' prices * their quantities * 10% to get the bonus
ROUND(SUM(o.quantity * p.price) * 0.10) AS bonus -- From the installers table
FROM
    installers i -- Joining the installs table on installer_id to get the installations done by each installer
    JOIN installs ins ON i.installer_id = ins.installer_id -- Joining the orders table on order_id to get the details of the orders for each installation
    JOIN orders o ON ins.order_id = o.order_id -- Joining the parts table on part_id to get the price of each part ordered
    JOIN parts p ON o.part_id = p.part_id -- Grouping the results by installer to calculate sums per installer
GROUP BY
    i.name -- Ordering the results by the calculated bonus in ascending order
ORDER BY
    bonus ASC;

/*
Question #2: 
RevRoll encourages healthy competition. The company holds a “Install Derby” where installers face off to see who can change a part the fastest in a tournament style contest.

Derby points are awarded as follows:

- An installer receives three points if they win a match (i.e., Took less time to install the part).
- An installer receives one point if they draw a match (i.e., Took the same amount of time as their opponent).
- An installer receives no points if they lose a match (i.e., Took more time to install the part).

We need to calculate the scores of all installers after all matches. Return the result table ordered by `num_points` in decreasing order. 
In case of a tie, order the records by `installer_id` in increasing order.

Expected column names: `installer_id`, `name`, `num_points`

*/

-- q2 solution:

-- Creating a derived table that assigns points to each installer for each derby match
WITH derby_points AS (
    SELECT
        installer_one_id AS installer_id,
        -- If installer one is faster, they win and get 3 points
        CASE
            WHEN installer_one_time < installer_two_time THEN 3 -- If it's a tie, they get 1 point
            WHEN installer_one_time = installer_two_time THEN 1 -- If installer one is slower, they get 0 points
            ELSE 0
        END AS points
    FROM
        install_derby
    UNION
    ALL
    SELECT
        installer_two_id AS installer_id,
        -- If installer two is faster, they win and get 3 points
        CASE
            WHEN installer_two_time < installer_one_time THEN 3 -- If it's a tie, they get 1 point
            WHEN installer_two_time = installer_one_time THEN 1 -- If installer two is slower, they get 0 points
            ELSE 0
        END AS points
    FROM
        install_derby
) -- Selecting the installer_id, their name, and the sum of their points from the derby_points derived table
SELECT
    i.installer_id,
    i.name,
    -- Using COALESCE to turn NULL sums into 0
    COALESCE(SUM(dp.points), 0) AS num_points
FROM
    installers i -- Joining the derby_points derived table on installer_id to calculate total points
    LEFT JOIN derby_points dp ON i.installer_id = dp.installer_id -- Grouping by installer_id and name to ensure we sum points for each installer
GROUP BY
    i.installer_id,
    i.name -- Ordering the result first by the total points in descending order, then by installer_id in ascending order
ORDER BY
    num_points DESC,
    i.installer_id ASC;

/*
Question #3:

Write a query to find the fastest install time with its corresponding `derby_id` for each installer. 
In case of a tie, you should find the install with the smallest `derby_id`.

Return the result table ordered by `installer_id` in ascending order.

Expected column names: `derby_id`, `installer_id`, `install_time`
*/

-- q3 solution:

-- Combining the install times from both installer positions
WITH CombinedTimes AS (
    SELECT
        derby_id,
        installer_one_id AS installer_id,
        installer_one_time AS install_time
    FROM
        install_derby
    WHERE
        installer_one_time IS NOT NULL
    UNION
    ALL
    SELECT
        derby_id,
        installer_two_id AS installer_id,
        installer_two_time AS install_time
    FROM
        install_derby
    WHERE
        installer_two_time IS NOT NULL
),
-- Ranking the install times for each installer
RankedTimes AS (
    SELECT
        derby_id,
        installer_id,
        install_time,
        -- Ranking install times, with ties broken by smallest derby_id
        RANK() OVER (
            PARTITION BY installer_id
            ORDER BY
                install_time,
                derby_id
        ) AS rnk
    FROM
        CombinedTimes
) -- Selecting the fastest install time for each installer
SELECT
    derby_id,
    installer_id,
    install_time
FROM
    RankedTimes
WHERE
    rnk = 1
ORDER BY
    installer_id;

/*
Question #4: 
Write a solution to calculate the total parts spending by customers paying for installs on each Friday of every week in November 2023. 
If there are no purchases on the Friday of a particular week, the parts total should be set to `0`.

Return the result table ordered by week of month in ascending order.

Expected column names: `november_fridays`, `parts_total`
*/

-- q4 solution:

-- Creating a list of all dates in November 2023
WITH AllNovemberDays AS (
    SELECT
        generate_series(
            '2023-11-01' :: date,
            '2023-11-30' :: date,
            '1 day' :: interval
        ) AS day
),
-- Filtering for Fridays
NovemberFridays AS (
    SELECT
        day :: date -- Casting the timestamp to a date
    FROM
        AllNovemberDays
    WHERE
        EXTRACT(
            ISODOW
            FROM
                day
        ) = 5
),
-- Calculating the total parts spending for each Friday
PartsTotals AS (
    SELECT
        nf.day AS november_fridays,
        COALESCE(SUM(p.price * o.quantity), 0) AS parts_total
    FROM
        NovemberFridays nf
        LEFT JOIN installs i ON nf.day = i.install_date
        LEFT JOIN orders o ON i.order_id = o.order_id
        LEFT JOIN parts p ON o.part_id = p.part_id
    GROUP BY
        nf.day
) -- Selecting the final results with the day and total spending, ordered by the day of the month
SELECT
    november_fridays,
    parts_total
FROM
    PartsTotals
ORDER BY
    november_fridays;
