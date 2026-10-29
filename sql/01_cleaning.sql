-- =====================================================================
-- Nettoyage des données
-- =====================================================================

DROP VIEW IF EXISTS medal_events CASCADE;
DROP TABLE IF EXISTS olympic_athletes_cleaned CASCADE;
DROP TABLE IF EXISTS olympic_medals_cleaned CASCADE;
DROP TABLE IF EXISTS olympic_hosts_cleaned CASCADE;
DROP TABLE IF EXISTS olympic_results_cleaned CASCADE;

-- ---------- 1. Apperçu de chaque table -------
-- Table olympic_hosts : clé primaire game_slug
SELECT 'olympic_hosts' AS tbl,
       COUNT(*)                                             AS nb_lignes,
       COUNT(*) - COUNT(DISTINCT game_slug)                 AS doublons, 
       COUNT(*) - COUNT(NULLIF(TRIM(game_year::text), ''))  AS vides
FROM olympic_hosts

UNION ALL

-- Table olympic_medals
SELECT 'olympic_medals',
       COUNT(*),
       COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM olympic_medals) t),
       COUNT(*) - COUNT(NULLIF(TRIM(country_3_letter_code::text), ''))
FROM olympic_medals

UNION ALL

-- Table athletes : clé primaire athlete_url
SELECT 'olympic_athletes',
       COUNT(*),
       COUNT(*) - COUNT(DISTINCT athlete_url),
       COUNT(*) - COUNT(NULLIF(TRIM(athlete_year_birth::text), ''))
FROM olympic_athletes

UNION all

-- Table results
SELECT 'olympic_results',
       COUNT(*),
       COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM olympic_results) t),
       COUNT(*) - COUNT(NULLIF(TRIM(rank_position::text), ''))
FROM olympic_results;


-- ---------- 2. Nettoyage de olympic_hosts ----------------
-- game_slug : text / game_name : text / game_location : text / season : text (soit Summer, soit Winter)
-- game year : integer / game_start_end : date / game_end_date : date
-- suppression des lignes vides
-- game_slug est la clé primaire
CREATE TABLE olympic_hosts_cleaned AS
SELECT DISTINCT
    TRIM(game_slug::text) AS game_slug,
    TRIM(game_name::text) AS game_name,
    TRIM(game_location::text) AS game_location,
    INITCAP(TRIM(game_season::text)) AS season,
    NULLIF(TRIM(game_year::text), '')::integer AS game_year,
    TRIM(game_start_date::text)::date AS start_date,
    TRIM(game_end_date::text)::date AS end_date
FROM olympic_hosts
WHERE NULLIF(TRIM(game_slug::text), '') IS NOT NULL;

ALTER TABLE olympic_hosts_cleaned ADD PRIMARY KEY (game_slug);

SELECT 
    'olympic_hosts_cleaned' AS table_name,
    COUNT(*) AS nb_lignes,
    COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM olympic_hosts_cleaned) t) AS doublons,
    COUNT(*) - COUNT(game_slug) AS vides
FROM olympic_hosts_cleaned;

-- ---------- 3. Nettoyage de olympic_medals ---------
-- game_slug : text / discipline : text / event : text / event_gender : text
-- medal_type : text (Gold, Silver, Bronze) / participant_type : text / participant_title : text
-- athlete_url : text / athlete_name : text / country_name : text / country_code : text
-- suppression des lignes sans identifiant de jeux, sans code pays ou sans médaille valide
-- ajout d'une clé primaire auto-incrémentée

CREATE TABLE olympic_medals_cleaned AS
SELECT DISTINCT
    TRIM(slug_game::text)                                              AS game_slug,
    TRIM(discipline_title::text)                                       AS discipline,
    TRIM(event_title::text)                                            AS event,
    COALESCE(INITCAP(NULLIF(TRIM(event_gender::text), '')), 'Unknown') AS event_gender,
    INITCAP(TRIM(medal_type::text))                                    AS medal_type,
    TRIM(participant_type::text)                                       AS participant_type,
    NULLIF(TRIM(participant_title::text), '')                          AS participant_title,
    NULLIF(TRIM(athlete_url::text), '')                                AS athlete_url,
    NULLIF(TRIM(athlete_full_name::text), '')                          AS athlete_name,
    TRIM(country_name::text)                                           AS country_name,
    UPPER(TRIM(country_3_letter_code::text))                           AS country_code
FROM olympic_medals
WHERE NULLIF(TRIM(slug_game::text), '') IS NOT NULL
  AND NULLIF(TRIM(country_3_letter_code::text), '') IS NOT NULL
  AND UPPER(TRIM(medal_type::text)) IN ('GOLD', 'SILVER', 'BRONZE');

ALTER TABLE olympic_medals_cleaned 
ADD COLUMN medal_id SERIAL PRIMARY KEY;

SELECT 
    'olympic_medals_cleaned' AS table_name,
    COUNT(*) AS nb_lignes,
    COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM olympic_medals_cleaned) t) AS doublons,
    COUNT(*) - COUNT(country_code) AS vides
FROM olympic_medals_cleaned;


-- 1 événement = 1 médaille (exemple éviter de compter 4 médailles pour le 4*100m)
-- game_slug : text / discipline : text / event : text / event_gender : text / medal_type : text
-- country_name : text / country_code : text 
-- participant_key : text (URL de l'athlète individuel OU nom de l'équipe/pays)
CREATE VIEW medal_events AS
SELECT DISTINCT
    game_slug, discipline, event, event_gender, medal_type,
    country_name, country_code,
    CASE WHEN participant_type = 'Athlete' THEN athlete_url
         ELSE COALESCE(participant_title, country_code) END AS participant_key
FROM olympic_medals_cleaned;

-- ---------- 4. Nettoyage de olympic_athletes ----------------------
-- athlete_url : text (identifiant unique) / athlete_name : text
-- birth_year : integer (filtré entre 1800 et 2012) / games_participations : integer
-- first_game : text / athlete_medals : text
-- Nettoyage des données aberrantes et dédoublonnage par URL (on garde la ligne avec le plus de participations)
-- athete_url est la clé primaire
CREATE TABLE olympic_athletes_cleaned AS
WITH cleaned AS (
    SELECT
        TRIM(athlete_url::text)                                AS athlete_url,
        TRIM(athlete_full_name::text)                          AS athlete_name,
        CASE 
            WHEN TRIM(athlete_year_birth::text) ~ '^[0-9]{4}$' 
             AND TRIM(athlete_year_birth::text)::integer BETWEEN 1800 AND 2012
            THEN TRIM(athlete_year_birth::text)::integer 
        END                                                    AS birth_year,
        CASE 
            WHEN TRIM(games_participations::text) ~ '^[0-9]+$'
            THEN TRIM(games_participations::text)::integer 
        END                                                    AS games_participations,
        NULLIF(TRIM(first_game::text), '')                     AS first_game
    FROM olympic_athletes
    WHERE NULLIF(TRIM(athlete_url::text), '') IS NOT NULL
),
ranked AS (
    SELECT *,
           ROW_NUMBER() OVER (PARTITION BY athlete_url 
                              ORDER BY games_participations DESC NULLS LAST) AS rn
    FROM cleaned
)
SELECT 
    athlete_url, 
    athlete_name, 
    birth_year, 
    games_participations,
    first_game
FROM ranked
WHERE rn = 1;

ALTER TABLE olympic_athletes_cleaned ADD PRIMARY KEY (athlete_url);

SELECT 
    'olympic_athletes_cleaned' AS table_name,
    COUNT(*) AS nb_lignes,
    COUNT(*) - COUNT(DISTINCT athlete_url) AS doublons,
    COUNT(*) - COUNT(birth_year) AS vides
FROM olympic_athletes_cleaned;

-- ---------- 5. Nettoyage olympic_results ------------
-- game_slug : text / discipline : text / event : text / participant_type : text
-- medal_type : text / rank_position : integer / country_name : text / country_code : text
-- athlete_url : text / value_type : text / value_unit : text
-- Nettoyage des résultats et conversion du classement en nombre (les "DSQ" deviennent NULL)
-- Ajout d'une clé primaire auto-incrémentée
CREATE TABLE olympic_results_cleaned AS
SELECT DISTINCT
    TRIM(slug_game::text)                                      AS game_slug,
    TRIM(discipline_title::text)                               AS discipline,
    TRIM(event_title::text)                                    AS event,
    TRIM(participant_type::text)                               AS participant_type,
    INITCAP(NULLIF(TRIM(medal_type::text), ''))                AS medal_type,
    CASE 
        WHEN TRIM(rank_position::text) ~ '^[0-9]+$' 
        THEN TRIM(rank_position::text)::integer 
    END                                                        AS rank_position,
    NULLIF(TRIM(country_name::text), '')                       AS country_name,
    UPPER(NULLIF(TRIM(country_3_letter_code::text), ''))       AS country_code,
    NULLIF(TRIM(athlete_url::text), '')                        AS athlete_url,
    NULLIF(TRIM(value_type::text), '')                         AS value_type,
    NULLIF(TRIM(value_unit::text), '')                         AS value_unit
FROM olympic_results
WHERE NULLIF(TRIM(slug_game::text), '') IS NOT NULL;

ALTER TABLE olympic_results_cleaned 
ADD COLUMN result_id SERIAL PRIMARY KEY;

SELECT 
    'olympic_results_cleaned' AS table_name,
    COUNT(*) AS nb_lignes,
    COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM olympic_results_cleaned) t) AS doublons,
    COUNT(*) - COUNT(rank_position) AS vides
FROM olympic_results_cleaned;

-- Clés primaires et clés étrangères ------------
-- Insertion des athlètes manquants depuis les résultats
INSERT INTO olympic_athletes_cleaned (athlete_url, athlete_name)
SELECT DISTINCT athlete_url, 'Unknown (Missing Data)'
FROM olympic_results_cleaned
WHERE athlete_url IS NOT NULL 
  AND athlete_url NOT IN (SELECT athlete_url FROM olympic_athletes_cleaned);

-- Insertion des athlètes manquants depuis les médailles
INSERT INTO olympic_athletes_cleaned (athlete_url, athlete_name)
SELECT DISTINCT athlete_url, 'Unknown (Missing Data)'
FROM olympic_medals_cleaned
WHERE athlete_url IS NOT NULL 
  AND athlete_url NOT IN (SELECT athlete_url FROM olympic_athletes_cleaned);

-- Déclaration de toutes les clés étrangères
ALTER TABLE olympic_medals_cleaned
ADD CONSTRAINT fk_medals_hosts FOREIGN KEY (game_slug) REFERENCES olympic_hosts_cleaned(game_slug);

ALTER TABLE olympic_medals_cleaned
ADD CONSTRAINT fk_medals_athletes FOREIGN KEY (athlete_url) REFERENCES olympic_athletes_cleaned(athlete_url);

ALTER TABLE olympic_results_cleaned
ADD CONSTRAINT fk_results_hosts FOREIGN KEY (game_slug) REFERENCES olympic_hosts_cleaned(game_slug);

ALTER TABLE olympic_results_cleaned
ADD CONSTRAINT fk_results_athletes FOREIGN KEY (athlete_url) REFERENCES olympic_athletes_cleaned(athlete_url);


-- ---------- Création des index -------------
CREATE INDEX idx_hosts_slug     ON olympic_hosts_cleaned(game_slug);
CREATE INDEX idx_medals_slug    ON olympic_medals_cleaned(game_slug);
CREATE INDEX idx_medals_athlete ON olympic_medals_cleaned(athlete_url);
CREATE INDEX idx_athletes_url   ON olympic_athletes_cleaned(athlete_url);
CREATE INDEX idx_results_slug   ON olympic_results_cleaned(game_slug);

-- ---------- Test unitaires -------------------

-- Vérification nombre de lignes
SELECT 'olympic_hosts_cleaned' AS nom_table, COUNT(*) AS nb_lignes FROM olympic_hosts_cleaned
UNION ALL 
SELECT 'olympic_medals_cleaned', COUNT(*) FROM olympic_medals_cleaned
UNION ALL 
SELECT 'olympic_athletes_cleaned', COUNT(*) FROM olympic_athletes_cleaned
UNION ALL 
SELECT 'olympic_results_cleaned', COUNT(*) FROM olympic_results_cleaned;

-- S'assurer que chaque médaille correspond à une édition des Jeux connue
SELECT COUNT(*) AS medailles_sans_edition_connue
FROM olympic_medals_cleaned m 
LEFT JOIN olympic_hosts_cleaned h USING (game_slug)
WHERE h.game_slug IS NULL;

-- Test métier : les USA ont gagné 113 médailles au total à Tokyo 2020 (dont 39 en Or).
-- Si le résultat pour l'Or est > 39, c'est que les joueurs d'une même équipe ont été comptés séparément.
SELECT medal_type, COUNT(*) AS total_medailles
FROM medal_events
WHERE country_code = 'USA' AND game_slug LIKE 'tokyo-2020%'
GROUP BY medal_type;
