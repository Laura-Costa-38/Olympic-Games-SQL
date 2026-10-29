-- ---------------------------------------------------------------------
-- Q1. Identifier les 10 athlètes individuels les plus âgés
--     ayant remporté une médaille d'or aux Jeux Olympiques.
--
-- Objectif :
--   Mettre en évidence les athlètes capables de remporter un titre
--   olympique à un âge avancé.
--
-- Méthode :
--   - Récupérer les médailles d'or obtenues par des athlètes individuels.
--   - Estimer l'âge au moment de la compétition à partir de l'année
--     des Jeux et de l'année de naissance.
--   - Classer les athlètes du plus âgé au plus jeune et retenir les 10
--     premiers résultats.
--
-- Limite :
--   L'âge est approximatif, car le mois et le jour de naissance ne sont
--   pas pris en compte. Il peut donc différer de l'âge réel de ±1 an.
-- ---------------------------------------------------------------------

SELECT
    m.athlete_name AS athlete,       -- Nom de l'athlète
    m.country_name AS pays,          -- Pays représenté lors de la compétition
    m.discipline AS discipline,      -- Discipline olympique
    m.event AS epreuve,              -- Épreuve dans laquelle la médaille a été gagnée
    h.game_name AS edition,          -- Nom de l'édition olympique
    h.game_year - a.birth_year AS age -- Estimation de l'âge lors des Jeux

FROM olympic_medals_cleaned AS m

JOIN olympic_athletes_cleaned AS a
    ON m.athlete_url = a.athlete_url
JOIN olympic_hosts_cleaned AS h
    ON m.game_slug = h.game_slug

WHERE m.medal_type = 'Gold'          -- Ne conserver que les médailles d'or
  AND m.participant_type = 'Athlete' -- Ne garder que les athlètes individuels
  AND a.birth_year IS NOT NULL       -- Exclure les athlètes dont l'année de naissance est inconnue
ORDER BY age DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q2. Identifier les athlètes ayant remporté des médailles lors des
--     Jeux Olympiques d'été ET d'hiver.
--
-- Objectif :
--   Vérifier si certains athlètes ont obtenu des médailles dans les deux
--   saisons olympiques et identifier les disciplines associées.
--
-- Méthode :
--   - Relier les médailles aux informations sur les éditions olympiques.
--   - Regrouper les résultats par athlète et par pays représenté.
--   - Compter les saisons olympiques distinctes dans lesquelles
--     l'athlète apparaît dans la table des médailles.
--   - Ne retenir que les groupes associés à deux saisons distinctes.
--   - Présenter le nombre de disciplines et de médailles pour chaque
--     groupe retenu.
--
-- Point de vigilance :
--   Le regroupement par pays peut créer plusieurs lignes pour un même
--   athlète s'il a représenté différents pays au cours de sa carrière.
--
-- Limite :
--   Cette requête porte sur les athlètes médaillés uniquement.
-- ---------------------------------------------------------------------

SELECT
    m.athlete_name AS athlete, -- Nom de l'athlète
    m.country_name AS pays,    -- Pays représenté lors des compétitions

    COUNT(DISTINCT m.discipline) AS nb_disciplines, -- Nombre de disciplines distinctes dans lesquelles l'athlète a remporté au moins 1 médaille

    STRING_AGG(
        DISTINCT m.discipline,
        ', '
        ORDER BY m.discipline
    ) AS disciplines,

    COUNT(*) AS nb_medailles

FROM olympic_medals_cleaned AS m

JOIN olympic_hosts_cleaned AS h
    ON m.game_slug = h.game_slug

WHERE m.athlete_url IS NOT NULL -- Exclure les enregistrements sans identifiant d'athlète

GROUP BY
    m.athlete_url,
    m.athlete_name,
    m.country_name

HAVING COUNT(DISTINCT h.season) = 2 -- =2 signifie que les médailles sont associées à été et hiver

ORDER BY nb_medailles DESC;

-- ---------------------------------------------------------------------
-- Q3. Identifier les athlètes individuels ayant la plus longue période
--     entre leur première et leur dernière édition olympique médaillée.
--
-- Objectif :
--   Repérer les athlètes ayant obtenu des médailles sur une longue période
--
-- Méthode :
--   - Relier les médailles aux athlètes et aux années des Jeux.
--   - Regrouper les médailles par athlète et par discipline.
--   - Identifier la première et la dernière année de médaille.
--   - Calculer l'écart entre ces deux années.
--   - Retenir les athlètes ayant été médaillés lors d'au moins
--     quatre éditions distinctes.
--   - Classer les résultats selon la durée de carrière, puis selon
--     le nombre d'éditions olympiques médaillées.
--
--  Limite :
--   Il s'agit d'une carrière médaillée observée dans les données,
--   et non de la durée totale de carrière sportive de l'athlète.
-- ---------------------------------------------------------------------

SELECT
    a.athlete_name AS athlete, -- Nom de l'athlète

    m.discipline AS discipline, -- Discipline étudiée pour cet athlète

    STRING_AGG(DISTINCT m.country_name, ' / ') AS pays,

    COUNT(DISTINCT m.game_slug) AS nb_editions_medaillees, -- nombre d'éditions distinctes où au moins 1 médaille
    
    MIN(h.game_year) AS premiere_medaille, -- année première édition médaillée

    MAX(h.game_year) AS derniere_medaille, -- année dernière édition médaillée

    MAX(h.game_year) - MIN(h.game_year) AS duree_carriere_ans

FROM olympic_medals_cleaned AS m

JOIN olympic_athletes_cleaned AS a
    ON m.athlete_url = a.athlete_url

JOIN olympic_hosts_cleaned AS h
    ON m.game_slug = h.game_slug

WHERE m.participant_type = 'Athlete'

GROUP BY
    a.athlete_url,
    a.athlete_name,
    m.discipline

HAVING COUNT(DISTINCT m.game_slug) >= 4 -- Exiger au moins 4 éditions distinctes avec 1 médaille

ORDER BY
    duree_carriere_ans DESC,
    nb_editions_medaillees DESC
LIMIT 10;

-- ---------------------------------------------------------------------
-- Q4. Calculer le nombre d'athlètes distincts présents à chaque édition
--     des Jeux Olympiques d'été et d'hiver.
--
-- Objectif :
--   Comparer le nombre d'athlètes recensés selon les éditions olympiques
--   et observer l'évolution de la participation au fil du temps.
--
-- Méthode :
--   - Partir de la table des résultats olympiques.
--   - Relier chaque résultat à son édition grâce à game_slug.
--   - Compter les identifiants d'athlètes distincts par édition.
--   - Conserver la saison et l'année pour distinguer les Jeux d'été
--     des Jeux d'hiver et suivre leur évolution chronologique.
--
--   Si un athlète apparaître plusieurs fois dans les résultats d'une
--   même édition, par exemple s'il participe à plusieurs épreuves,
--   le comptage distinct évite de compter plusieurs fois le même
--   identifiant d'athlète au sein d'une édition.
--
-- ---------------------------------------------------------------------

SELECT
    h.game_name AS edition, -- Nom de l'édition olympique
    h.season AS saison,     -- Saison : été ou hiver

    COUNT(DISTINCT r.athlete_url) AS nb_athletes,

    h.game_year AS annee     -- Année de l'édition

FROM olympic_results_cleaned AS r

JOIN olympic_hosts_cleaned AS h
    ON r.game_slug = h.game_slug

WHERE r.athlete_url IS NOT NULL

GROUP BY
    h.game_name,
    h.season,
    h.game_year

ORDER BY h.game_year;

-- ---------------------------------------------------------------------
-- Q5. Identifier les disciplines dans lesquelles la proportion
--     de résultats sans classement est la plus élevée.
--
-- Objectif :
--   Repérer les disciplines où les résultats sont fréquemment associés
--   à une absence de classement, ce qui peut notamment être lié à des
--   abandons, des disqualifications ou d'autres situations particulières.
--
-- Méthode :
--   - Regrouper les résultats par discipline.
--   - Compter le nombre total de résultats dans chaque discipline.
--   - Compter les résultats dont rank_position est NULL.
--   - Calculer la part de ces résultats dans le total de la discipline.
--   - Exclure les disciplines avec moins de 200 résultats afin de limiter
--     l'influence des effectifs très faibles.
--   - Trier les disciplines par pourcentage décroissant et afficher
--     les 10 premières.
--
-- Point de vigilance :
--   Une position NULL ne prouve pas à elle seule qu'il y a eu abandon
--   ou disqualification. Elle peut également correspondre à d'autres
--   situations ou à des données manquantes.
--
-- Le taux calculé doit donc être interprété comme un taux de résultats
-- sans classement renseigné.
-- ---------------------------------------------------------------------

SELECT
    discipline, -- Discipline olympique analysée

    COUNT(*) AS nb_resultats, -- Nombre total de lignes de résultats recensées dans la discipline.

    COUNT(*) FILTER ( -- Nombre de résultats dont la position au classement n'est pas renseignée.
        WHERE rank_position IS NULL
    ) AS sans_classement,

    ROUND( -- Proportion de résultats sans classement, exprimée en pourcentage.
        100.0 * COUNT(*) FILTER (
            WHERE rank_position IS NULL
        ) / COUNT(*),
        1
    ) AS pourcentage_sans_classement

FROM olympic_results_cleaned

GROUP BY discipline

HAVING COUNT(*) >= 200 -- Ne conserver que les disciplines comptant au moins 200 résultats.

ORDER BY pourcentage_sans_classement DESC

LIMIT 10;



