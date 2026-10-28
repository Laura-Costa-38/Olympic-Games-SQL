# 🥇 Olympic Games Data Engineering & SQL Analysis (1896-2022)

Pipeline de données et modélisation relationnelle (Star Schema) en PostgreSQL à partir du jeu de données historique des Jeux Olympiques.

---

## 🏗️ Architecture du Projet & Modélisation

Le projet repose sur une modélisation en étoile (Star Schema) implémentée sous PostgreSQL, séparant les dimensions de référence des tables de faits analytiques.

*(Insérer ici l'image de ton diagramme ER issu de DBeaver)*

### Tables créées :
* **Dimensions (Référentiels) :**
  * `olympic_hosts_cleaned` : Éditions des Jeux (clé primaire : `game_slug`)
  * `olympic_athletes_cleaned` : Référentiel des athlètes dédoublonnés (clé primaire : `athlete_url`)
* **Faits (Événements) :**
  * `olympic_medals_cleaned` : Palmarès des médailles (clé primaire auto-incrémentée : `medal_id`, clés étrangères vers hôtes et athlètes)
  * `olympic_results_cleaned` : Résultats et classements (clé primaire auto-incrémentée : `result_id`, clés étrangères vers hôtes et athlètes)
* **Vue sémantique :**
  * `medal_events` : Vue logique résolvant le biais de comptage des sports collectifs.

---

## 🛠️ Pipeline de Nettoyage & Data Cleansing

Le script de nettoyage (`01_cleaning_pipeline.sql`) intègre les bonnes pratiques suivantes :
1. **Dédoublonnage avancé :** Utilisation de la fonction de fenêtrage `ROW_NUMBER() OVER (PARTITION BY ... ORDER BY ...)` sur les athlètes pour conserver le profil le plus complet.
2. **Standardisation & Typage :** Nettoyage des chaînes de caractères (`TRIM`, `INITCAP`, `UPPER`), conversion stricte des types (`INTEGER`, `DATE`), et isolation des classements numériques via expressions régulières (Regex).
3. **Intégrité Référentielle & Gestion des Orphelins :** Création de profils déduits (*inferred members*) pour les valeurs manquantes afin d'activer les contraintes de clés étrangères (`FOREIGN KEY`) sans perte d'historique.
4. **Optimisation :** Indexation ciblée (`CREATE INDEX`) sur les clés étrangères pour accélérer les performances des futures jointures.

---

## 📁 Structure du Repository

```text
├── data/                      # Fichiers sources bruts (Kaggle)
├── sql/
│   ├── 01_cleaning.sql        # Script complet de nettoyage et modélisation
│   └── 02_analysis.sql        # Requêtes d'analyse métier (à venir)
├── docs/
│   └── er_diagram.png         # Schéma en étoile de la base de données
└── README.md
