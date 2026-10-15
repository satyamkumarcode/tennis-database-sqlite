-- tennis database for infomdw assignment 1 (step 1 of 3: schema)
-- this one file has everything for task 1 and task 2
-- part 1 builds the tables and fills them with data
-- part 2 has the five queries for task 2

-- how to run it
-- open the terminal in the folder where this sql file is saved
-- start sqlite3 with any new file name and read this file with the read command

-- stop at the first error so a mistake does not hide in the output
.bail on

-- sqlite does not check foreign keys unless we switch them on
-- it has to be before any table work
PRAGMA foreign_keys = ON;

-- drop old tables first so the file can run again and again without errors
-- order matters because a child table needs its parent so children are dropped first
DROP TABLE IF EXISTS "match";
DROP TABLE IF EXISTS tournament_entry;
DROP TABLE IF EXISTS coach_player;
DROP TABLE IF EXISTS player_nationalities;
DROP TABLE IF EXISTS round;
DROP TABLE IF EXISTS event;
DROP TABLE IF EXISTS tournament_edition;
DROP TABLE IF EXISTS venue;
DROP TABLE IF EXISTS tournament_series;
DROP TABLE IF EXISTS coach;
DROP TABLE IF EXISTS player;
DROP TABLE IF EXISTS city;
DROP TABLE IF EXISTS country;


-- part 1 database design

-- quick guide to the words used below
-- primary key is the column that identifies a row and it can never repeat
-- unique means no two rows can have the same value
-- check is a rule that every row has to follow
-- foreign key points to a row in another table so we cannot save something that does not exist
-- on delete restrict blocks the delete and cascade copies the change to the child rows
-- set null keeps the row and just clears the link

-- geography first
-- country holds the countries
CREATE TABLE country (
    country_code CHAR(3) NOT NULL,
    country      VARCHAR NOT NULL,
    CONSTRAINT pk_country PRIMARY KEY (country_code),
    CONSTRAINT uq_country_name UNIQUE (country),
    -- country codes like NED or ESP are always 3 letters, and since sqlite3 ignores the number of characters, we enforce the length with the below check
    CONSTRAINT ck_country_code CHECK (length(country_code) = 3)
);

-- a city belongs to one country
-- the same city name can come again only in another country
CREATE TABLE city (
    city_id      INTEGER NOT NULL,
    country_code CHAR(3) NOT NULL,
    city         VARCHAR NOT NULL,
    CONSTRAINT pk_city PRIMARY KEY (city_id),
    CONSTRAINT uq_city UNIQUE (country_code, city),
    -- a country that still has cities cannot be deleted
    CONSTRAINT fk_city_country FOREIGN KEY (country_code) REFERENCES country (country_code)
        ON DELETE RESTRICT ON UPDATE CASCADE
);


-- one row per player
-- atp name weight turned pro and backhand can be empty because the source did not always have them
-- a player must be at least 14 years old but a trigger further down checks that
CREATE TABLE player (
    player_id     VARCHAR NOT NULL,
    player_name   VARCHAR NOT NULL,
    -- atp refers to the association of tennis professionals
    atp_name      VARCHAR,
    -- gender and birthplace can also be null in this table
    gender        CHAR(1),
    birthdate     DATE    NOT NULL,
    birthplace_id INTEGER,
    weight_kg     INTEGER,
    height_cm     INTEGER NOT NULL,
    turned_pro    INTEGER,
    hand          CHAR(1) NOT NULL,
    -- 1h means one handed backhand and 2h means two handed backhand
    backhand      CHAR(2),
    CONSTRAINT pk_player PRIMARY KEY (player_id),
    CONSTRAINT ck_player_gender   CHECK (gender IN ('M', 'F')), -- allow only F and M values in gender column
    CONSTRAINT ck_player_hand     CHECK (hand IN ('R', 'L')), -- allow only R and L values in hand column
    CONSTRAINT ck_player_backhand CHECK (backhand IN ('1H', '2H')), -- allow only 1H and 2H values in backhand column
    -- if a city is deleted the player stays and only the birthplace becomes empty
    CONSTRAINT fk_player_birthplace FOREIGN KEY (birthplace_id) REFERENCES city (city_id)
        ON DELETE SET NULL ON UPDATE CASCADE
);

-- coaches have their own table because a player can have many coaches and a coach can train many players
CREATE TABLE coach (
    coach_id        INTEGER NOT NULL,
    coach_full_name VARCHAR NOT NULL,
    CONSTRAINT pk_coach PRIMARY KEY (coach_id)
);


-- tournaments are stored in three levels
-- series is the tournament itself like wimbledon
-- edition is one year of that tournament
-- event is one draw of an edition like the men's singles
CREATE TABLE tournament_series (
    series_id   INTEGER NOT NULL,
    series_name VARCHAR NOT NULL,
    category    VARCHAR NOT NULL,
    CONSTRAINT pk_tournament_series PRIMARY KEY (series_id),
    CONSTRAINT uq_series_name UNIQUE (series_name),
    CONSTRAINT ck_series_category CHECK (category IN ('Grand Slam', 'Masters 1000')) -- allow only the categories the db was designed for
);

-- venue is the place where a tournament is played with its court surface
CREATE TABLE venue (
    venue_id   INTEGER NOT NULL,
    venue_name VARCHAR NOT NULL,
    city_id    INTEGER NOT NULL,
    surface    VARCHAR NOT NULL,
    CONSTRAINT pk_venue PRIMARY KEY (venue_id),
    CONSTRAINT uq_venue UNIQUE (venue_name, city_id),
    CONSTRAINT ck_venue_surface CHECK (surface IN ('Hard', 'Clay', 'Grass', 'Carpet')), -- allow only the correct surface types
    CONSTRAINT fk_venue_city FOREIGN KEY (city_id) REFERENCES city (city_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- one edition is one year of a series played at one venue
CREATE TABLE tournament_edition (
    tourney_id VARCHAR NOT NULL,
    series_id  INTEGER NOT NULL,
    venue_id   INTEGER NOT NULL,
    start_date DATE    NOT NULL,
    CONSTRAINT pk_tournament_edition PRIMARY KEY (tourney_id),
    CONSTRAINT uq_series_start UNIQUE (series_id, start_date),
    CONSTRAINT fk_edition_series FOREIGN KEY (series_id) REFERENCES tournament_series (series_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_edition_venue FOREIGN KEY (venue_id) REFERENCES venue (venue_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- one event is one draw of an edition
CREATE TABLE event (
    event_id   INTEGER NOT NULL,
    tourney_id VARCHAR NOT NULL,
    gender     CHAR(1) NOT NULL,
    draw_size  INTEGER NOT NULL,
    best_of    INTEGER NOT NULL,
    CONSTRAINT pk_event PRIMARY KEY (event_id),
    -- unique on tourney and gender means only one draw per gender in each edition
    CONSTRAINT uq_event UNIQUE (tourney_id, gender),
    CONSTRAINT ck_event_gender    CHECK (gender IN ('M', 'F')),
    CONSTRAINT ck_event_draw_size CHECK (draw_size IN (128, 96, 64, 56)),
    CONSTRAINT ck_event_best_of   CHECK (best_of IN (3, 5)),
    CONSTRAINT fk_event_edition FOREIGN KEY (tourney_id) REFERENCES tournament_edition (tourney_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- round codes in playing order from R128 up to the final F
-- sequence order lets us sort the rounds
CREATE TABLE round (
    round_code     VARCHAR NOT NULL,
    round_name     VARCHAR NOT NULL,
    sequence_order INTEGER NOT NULL,
    CONSTRAINT pk_round PRIMARY KEY (round_code),
    CONSTRAINT uq_round_name UNIQUE (round_name),
    CONSTRAINT uq_round_order UNIQUE (sequence_order)
);


-- junction tables come next
-- they connect two tables that have a many to many relation
-- one row in a junction table is one link

-- this one links players to countries over time
-- start year is part of the key so a player can come back to the same country later
-- an empty end year means the player still plays for that country
-- if a player is deleted his rows go too but a country that is still used cannot be deleted
CREATE TABLE player_nationalities (
    player_id        VARCHAR NOT NULL,
    nationality_code CHAR(3) NOT NULL,
    start_year       INTEGER NOT NULL,
    end_year         INTEGER,
    CONSTRAINT pk_player_nationalities PRIMARY KEY (player_id, nationality_code, start_year),
    CONSTRAINT ck_nationality_years CHECK (end_year >= start_year),
    CONSTRAINT fk_nationality_player FOREIGN KEY (player_id) REFERENCES player (player_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_nationality_country FOREIGN KEY (nationality_code) REFERENCES country (country_code)
        ON DELETE RESTRICT ON UPDATE CASCADE
);

-- every row links one player to one coach
-- if the player or the coach is deleted the link goes away too
CREATE TABLE coach_player (
    player_id VARCHAR NOT NULL,
    coach_id  INTEGER NOT NULL,
    CONSTRAINT pk_coach_player PRIMARY KEY (player_id, coach_id),
    CONSTRAINT fk_coach_player_player FOREIGN KEY (player_id) REFERENCES player (player_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_coach_player_coach FOREIGN KEY (coach_id) REFERENCES coach (coach_id)
        ON DELETE CASCADE ON UPDATE CASCADE
);

-- this is the entry list of an event
-- a row says that this player played this event with a seed and a ranking
-- the primary key is event plus player so nobody enters the same event twice
CREATE TABLE tournament_entry (
    event_id    INTEGER NOT NULL,
    player_id   VARCHAR NOT NULL,
    seed        INTEGER,
    -- q means qualifier and wc means wild card
    -- ll means lucky loser and pr means protected ranking
    -- se means special exempt
    entry       VARCHAR,
    "rank"      INTEGER,
    rank_points INTEGER,
    CONSTRAINT pk_tournament_entry PRIMARY KEY (event_id, player_id),
    -- two players in the same event cannot have the same seed
    CONSTRAINT uq_entry_seed UNIQUE (event_id, seed),
    CONSTRAINT ck_entry_seed        CHECK (seed BETWEEN 1 AND 32),
    CONSTRAINT ck_entry_type        CHECK (entry IN ('Q', 'WC', 'LL', 'PR', 'SE')),
    CONSTRAINT ck_entry_rank        CHECK ("rank" > 0),
    CONSTRAINT ck_entry_rank_points CHECK (rank_points > 0),
    -- rank and rank points must both be filled or both be empty
    CONSTRAINT ck_entry_rank_pair   CHECK (("rank" IS NULL) = (rank_points IS NULL)),
    CONSTRAINT fk_entry_event FOREIGN KEY (event_id) REFERENCES event (event_id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT fk_entry_player FOREIGN KEY (player_id) REFERENCES player (player_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);


-- one row per match
-- winner columns start with w and loser columns start with l
-- stats can be empty for example when a match ended with a walkover
-- match is in double quotes to prevent sqlite3 from reading it as an SQL keyword
CREATE TABLE "match" (
    match_id   INTEGER NOT NULL,
    event_id   INTEGER NOT NULL,
    match_date DATE    NOT NULL,
    match_num  INTEGER NOT NULL,
    indoor     CHAR(1) NOT NULL,
    winner_id  VARCHAR NOT NULL,
    loser_id   VARCHAR NOT NULL,
    score      VARCHAR,
    round_code VARCHAR NOT NULL,
    minutes    INTEGER,
    -- df means double faults and svpt means service points played
    -- 1stin means first serves in and 1stwon means points won on first serve
    -- 2ndwon means points won on second serve and svgms means service games played
    -- bpsaved means break points saved and bpfaced means break points faced
    -- these meanings apply to both winner and loser columns
    w_ace INTEGER,
    w_df INTEGER,
    w_svpt INTEGER,
    w_1stIn INTEGER,
    w_1stWon INTEGER,
    w_2ndWon INTEGER,
    w_SvGms INTEGER,
    w_bpSaved INTEGER,
    w_bpFaced INTEGER,
    l_ace INTEGER,
    l_df INTEGER,
    l_svpt INTEGER,
    l_1stIn INTEGER,
    l_1stWon INTEGER,
    l_2ndWon INTEGER,
    l_SvGms INTEGER,
    l_bpSaved INTEGER,
    l_bpFaced INTEGER,
    CONSTRAINT pk_match PRIMARY KEY (match_id),
    -- every match has its own number inside an event
    -- the same result cannot be saved twice in one event
    CONSTRAINT uq_match_number UNIQUE (event_id, match_num),
    CONSTRAINT uq_match_pair UNIQUE (event_id, winner_id, loser_id),
    CONSTRAINT uq_event_match_loser UNIQUE (event_id, loser_id),
    CONSTRAINT uq_event_match_winner_round UNIQUE (event_id, winner_id, round_code),
    CONSTRAINT ck_match_indoor CHECK (indoor IN ('O', 'I')), -- either indoors or outdoors
    -- a player cannot play against himself
    CONSTRAINT ck_match_players CHECK (winner_id <> loser_id),
    -- minutes must be above 0 and the stats cannot be negative
    CONSTRAINT ck_match_minutes CHECK (minutes > 0),
    CONSTRAINT ck_match_w_ace CHECK (w_ace IS NULL OR w_ace >= 0),
    CONSTRAINT ck_match_w_df CHECK (w_df IS NULL OR w_df >= 0),
    CONSTRAINT ck_match_w_svpt CHECK (w_svpt IS NULL OR w_svpt >= 0),
    CONSTRAINT ck_match_w_1stin CHECK (w_1stIn IS NULL OR w_1stIn >= 0),
    CONSTRAINT ck_match_w_1stwon CHECK (w_1stWon IS NULL OR w_1stWon >= 0),
    CONSTRAINT ck_match_w_2ndwon CHECK (w_2ndWon IS NULL OR w_2ndWon >= 0),
    CONSTRAINT ck_match_w_svgms CHECK (w_SvGms IS NULL OR w_SvGms >= 0),
    CONSTRAINT ck_match_w_bpsaved CHECK (w_bpSaved IS NULL OR w_bpSaved >= 0),
    CONSTRAINT ck_match_w_bpfaced CHECK (w_bpFaced IS NULL OR w_bpFaced >= 0),
    CONSTRAINT ck_match_l_ace CHECK (l_ace IS NULL OR l_ace >= 0),
    CONSTRAINT ck_match_l_df CHECK (l_df IS NULL OR l_df >= 0),
    CONSTRAINT ck_match_l_svpt CHECK (l_svpt IS NULL OR l_svpt >= 0),
    CONSTRAINT ck_match_l_1stin CHECK (l_1stIn IS NULL OR l_1stIn >= 0),
    CONSTRAINT ck_match_l_1stwon CHECK (l_1stWon IS NULL OR l_1stWon >= 0),
    CONSTRAINT ck_match_l_2ndwon CHECK (l_2ndWon IS NULL OR l_2ndWon >= 0),
    CONSTRAINT ck_match_l_svgms CHECK (l_SvGms IS NULL OR l_SvGms >= 0),
    CONSTRAINT ck_match_l_bpsaved CHECK (l_bpSaved IS NULL OR l_bpSaved >= 0),
    CONSTRAINT ck_match_l_bpfaced CHECK (l_bpFaced IS NULL OR l_bpFaced >= 0),
    CONSTRAINT fk_match_event FOREIGN KEY (event_id) REFERENCES event (event_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_match_round FOREIGN KEY (round_code) REFERENCES round (round_code)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    -- winner and loser both point to the entry list
    -- two columns together point to one entry row so both players must have entered that event
    CONSTRAINT fk_match_winner FOREIGN KEY (event_id, winner_id) REFERENCES tournament_entry (event_id, player_id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_match_loser FOREIGN KEY (event_id, loser_id) REFERENCES tournament_entry (event_id, player_id)
        ON DELETE RESTRICT ON UPDATE CASCADE
);


-- indexes make searching and joining faster
-- we add them on foreign key columns because we join on them a lot
-- primary keys and unique constraints already get an index from sqlite so they are not repeated
CREATE INDEX idx_player_birthplace   ON player (birthplace_id);
CREATE INDEX idx_venue_city          ON venue (city_id);
CREATE INDEX idx_edition_series      ON tournament_edition (series_id);
CREATE INDEX idx_edition_venue       ON tournament_edition (venue_id);
CREATE INDEX idx_nationality_country ON player_nationalities (nationality_code);
CREATE INDEX idx_coach_player_coach  ON coach_player (coach_id);
CREATE INDEX idx_entry_player        ON tournament_entry (player_id);
CREATE INDEX idx_match_round         ON "match" (round_code);
CREATE INDEX idx_match_loser         ON "match" (event_id, loser_id);


-- triggers run a small check before an insert or an update
-- we need them because sqlite does not allow the current date inside a check
-- each rule has two triggers one for insert and one for update
-- when a rule is broken the trigger stops the change with an error message

-- a player must be at least 14 years old
-- new refers to the proposed row values
CREATE TRIGGER trg_player_birthdate_ins BEFORE INSERT ON player
WHEN NEW.birthdate > date('now', '-14 years')
BEGIN
    SELECT RAISE(ABORT, 'player must be at least 14 years old');
END;

CREATE TRIGGER trg_player_birthdate_upd BEFORE UPDATE OF birthdate ON player
WHEN NEW.birthdate > date('now', '-14 years')
BEGIN
    SELECT RAISE(ABORT, 'player must be at least 14 years old');
END;

-- the turned pro year cannot be in the future
-- strftime extracts the current year and cast converts it to a number
CREATE TRIGGER trg_player_turned_pro_ins BEFORE INSERT ON player
WHEN NEW.turned_pro > CAST(strftime('%Y', 'now') AS INTEGER)
BEGIN
    SELECT RAISE(ABORT, 'turned_pro cannot be later than the current year');
END;

CREATE TRIGGER trg_player_turned_pro_upd BEFORE UPDATE OF turned_pro ON player
WHEN NEW.turned_pro > CAST(strftime('%Y', 'now') AS INTEGER)
BEGIN
    SELECT RAISE(ABORT, 'turned_pro cannot be later than the current year');
END;

-- the start year of a nationality cannot be in the future
CREATE TRIGGER trg_nationality_start_ins BEFORE INSERT ON player_nationalities
WHEN NEW.start_year > CAST(strftime('%Y', 'now') AS INTEGER)
BEGIN
    SELECT RAISE(ABORT, 'start_year cannot be later than the current year');
END;

CREATE TRIGGER trg_nationality_start_upd BEFORE UPDATE OF start_year ON player_nationalities
WHEN NEW.start_year > CAST(strftime('%Y', 'now') AS INTEGER)
BEGIN
    SELECT RAISE(ABORT, 'start_year cannot be later than the current year');
END;

