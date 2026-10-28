# 🥇 Jeux Olympiques : projet SQL

Nettoyage et modélisation des données en PostgreSQL à partir du jeu de données historique des Jeux Olympiques, disponible sur Kaggle : https://www.kaggle.com/datasets/piterfm/olympic-games-medals-19862018

---

## 🏗️ Modélisation des données

### Tables créées :
  * `olympic_hosts_cleaned` : Éditions des Jeux (clé primaire : `game_slug`)
  * `olympic_athletes_cleaned` : Référentiel des athlètes dédoublonnés (clé primaire : `athlete_url`)
  * `olympic_medals_cleaned` : Palmarès des médailles (clé primaire auto-incrémentée : `medal_id`, clés étrangères vers hôtes et athlètes)
  * `olympic_results_cleaned` : Résultats et classements (clé primaire auto-incrémentée : `result_id`, clés étrangères vers hôtes et athlètes)
* **Vue :**
  * `medal_events` : Vue logique résolvant le biais de comptage des sports collectifs.

---

## 🛠️ Nettoyage

Le script de nettoyage (`01_cleaning_pipeline.sql`) réalise les opérations suivantes :
1. Utilisation de la fonction `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` sur les athlètes
2. Nettoyage des chaînes de caractères (`TRIM`, `INITCAP`, `UPPER`), conversion stricte des types (`INTEGER`, `DATE`), et isolation des classements numériques via expressions régulières (Regex).
3. Création de profils vides pour les valeurs manquantes afin d'activer les contraintes de clés étrangères (`FOREIGN KEY`)
4. Indexation ciblée (`CREATE INDEX`) sur les clés étrangères pour accélérer les performances des futures jointures.

---

## 📁 Structure du répertoire

```text
├── data/                      # Fichiers sources bruts (Kaggle)
├── sql/
│   ├── 01_cleaning.sql        # Nettoyage et modélisation
│   └── 02_analysis.sql        # Requêtes d'analyse métier 
├── docs/
│   └── Diagramme.png         # Diagramme UML
└── README.md
