-- part 2 the five queries for task 2
-- each query uses a different technique
-- the titles in the output come from the print lines

-- show the column names and line the output up in columns
.headers on
.mode column


-- query 1 join
.print ''
.print '=== Query 1 (join): Which tournaments were played on clay during 2025 season? ==='
-- get the tournament names
SELECT series_name FROM tournament_series ts
-- get the tournaments played on 2025 with their venues
JOIN tournament_edition te ON te.series_id = ts.series_id
-- get the venues and their surface info
JOIN venue v ON v.venue_id = te.venue_id
-- keep only the clay courts
WHERE v.surface = 'Clay';


-- query 2 aggregate function
.print ''
.print '=== Query 2 (aggregate): Across all 2025 events in the database, what is the average match duration in each round, and which round lasts longer? ==='
-- get round names and their avg duration with one decimal point
SELECT r.round_name, ROUND(AVG(m.minutes), 1) AS avg_minutes
FROM "match" m
-- round holds the full name of the rounds
JOIN round r ON r.round_code = m.round_code
-- get one result per round
GROUP BY r.round_name
-- the longest round on avg appears first
ORDER BY avg_minutes DESC;


-- query 3 nested query
.print ''
.print '=== Query 3 (nested query): Which players are taller than the average player in the database? ==='
-- get the players and their heights
SELECT player_name, height_cm FROM player
-- keep only the players that their height is above the average height
WHERE height_cm > (SELECT AVG(height_cm) FROM player);


-- query 4 self join
.print ''
.print '=== Query 4 (self join): Which pairs of players were born in the same city? ==='
-- get pairs of players born in the same city
SELECT c.city, p1.player_name AS player_1, p2.player_name AS player_2
FROM player p1
-- self join with player to get the 2nd copy of player table
JOIN player p2 on p1.birthplace_id = p2.birthplace_id
-- join with city to get the actual city names
JOIN city c on c.city_id = p1.birthplace_id
-- keep each pair once and avoid pairing a player with themselves
WHERE p1.player_id < p2.player_id
-- see the pairs ordered by city
ORDER BY c.city;


-- query 5 set operation
.print ''
.print '=== Query 5 (set operation): Which players have no coach recorded in the database? ==='
-- get all players that do not have recorded coach links
SELECT p.player_name FROM player p
WHERE p.player_id IN (
	-- all players in the database
	SELECT player_id FROM player
	-- without
	EXCEPT
	-- players that have recorded coach/-es
	SELECT player_id FROM coach_player
)
-- get the results ordered by player name
ORDER BY p.player_name;