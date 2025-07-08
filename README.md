# NutriSuivi - Application de Suivi Nutritionnel

Ce document présente le projet d'application mobile **NutriSuivi**, développée avec Flutter. Il sert de documentation centrale pour comprendre son architecture, ses fonctionnalités et sa vision.

## 1. Objectif de l'Application

NutriSuivi est un outil de suivi nutritionnel personnel conçu pour être à la fois **puissant** et **confortable** à utiliser au quotidien. L'objectif est de permettre à un utilisateur de suivre facilement son apport calorique et en macronutriments, tout en l'aidant à atteindre ses objectifs personnels (perte de poids, maintien, prise de masse) grâce à des fonctionnalités intelligentes et une interface agréable.

L'application est également conçue pour un cas d'usage **Coach/Client**, où un coach nutritionnel peut suivre les progrès de ses clients via des bilans journaliers et hebdomadaires détaillés.

## 2. Environnement de Développement

* **Framework :** Flutter (Version du SDK : 3.x)
* **Langage :** Dart (avec Null Safety)
* **Éditeur de code :** Visual Studio Code
* **Base de données locale :** SQLite via le package `sqflite`
* **Gestion d'état :** `ChangeNotifier` et `Provider` (pour le thème) et gestion d'état locale (`StatefulWidget`) pour les écrans.
* **Principaux packages :**
    * `openfoodfacts`, `translator`, `http` pour les API externes.
    * `flutter_local_notifications` pour les rappels.
    * `percent_indicator`, `fl_chart`, `animated_digit` pour la visualisation des données.
    * `google_fonts`, `flutter_svg`, `flutter_animate` pour le design de l'interface.
    * `share_plus`, `url_launcher` pour les fonctionnalités de partage.

## 3. Architecture du Projet

Le projet suit une architecture claire séparant les responsabilités :

* `lib/screens/` : Contient les écrans principaux de l'application (pages complètes).
* `lib/widgets/` : Contient les widgets réutilisables, organisés par sous-dossiers (`common`, `home`).
* `lib/controllers/` : Contient la logique métier et les interactions avec les services de données.
* `lib/helpers/` : Contient les services techniques (ex: `database_helper.dart`, `notification_service.dart`).
* `lib/models/` : Contient les classes de modèle de données (ex: `FoodItem`, `UserProfile`).
* `lib/providers/` : Contient les gestionnaires d'état globaux (ex: `ThemeProvider`).

## 4. Fonctionnalités Implémentées

### Suivi Nutritionnel de Base
* **Journal Quotidien :** Saisie des aliments répartis par repas (Petit-déjeuner, Déjeuner, Dîner, Collation).
* **Calcul des Totaux :** Calcul en temps réel des calories et des macronutriments (protéines, glucides, lipides) consommés.
* **Objectifs Personnalisés :** L'utilisateur peut définir manuellement ses objectifs caloriques et en macros.

### Saisie d'Aliments Avancée
* **Scan de Code-barres :** Utilise l'API Open Food Facts pour récupérer instantanément les données d'un produit.
* **Recherche Hybride :**
    * Recherche par texte dans l'API **Open Food Facts** pour les produits industriels.
    * Recherche par texte dans l'API **USDA FoodData Central** (avec traduction FR->EN) pour les aliments bruts (fruits, légumes, etc.).
    * Algorithme de tri et de filtrage personnalisé pour améliorer la pertinence des résultats.
* **Saisie Manuelle :** Formulaire complet pour les aliments non trouvés.
* **Saisie par Portions :** Pour les aliments courants, l'utilisateur peut saisir par unité (ex: "1 œuf", "1 tranche de pain") grâce à une base de données locale et à la détection des portions de l'API.
* **Wizard d'Estimation de Plat :** Un assistant guidé permet d'estimer les calories d'un plat (au restaurant, chez des amis) en décrivant sa composition, sa taille et ses "extras" (sauce, friture, sucre).

### Ergonomie et "Qualité de Vie"
* **Ajout Rapide :** Section sur l'écran d'accueil avec des onglets pour les **aliments favoris** et les **repas sauvegardés**, avec recherche et suppression.
* **Interaction avec le Journal :** Un clic sur un aliment du journal ouvre un menu pour le **modifier**, le **supprimer** ou l'**ajouter aux favoris**.
* **Copie de Repas :** Possibilité de copier un repas complet de la veille vers le jour actuel en un clic.
* **Navigation Temporelle :** Un sélecteur de date dans l'en-tête permet de consulter et de modifier les journaux des jours précédents.

### Personnalisation et Coaching
* **Profil Utilisateur :** L'utilisateur peut enregistrer son nom, sexe, date de naissance, taille, poids, niveau d'activité et objectif principal.
* **Calcul d'Objectifs :** L'application peut suggérer des objectifs nutritionnels personnalisés basés sur les données du profil.
* **Statistiques :** Un écran de statistiques affiche l'historique des 7 derniers jours (calories, macros, totaux par repas) et indique si l'objectif a été atteint.
* **Partage de Bilans :** L'utilisateur peut générer et partager un rapport textuel détaillé (quotidien ou hebdomadaire) pour son coach via email ou toute autre application.
* **Conseils Personnalisés :** Une section sur l'écran d'accueil affiche des conseils dynamiques basés sur l'heure, les données saisies et l'objectif de l'utilisateur.

### Interface Utilisateur et Design
* **Thème Clair / Sombre :** L'utilisateur peut choisir son thème, et ce choix est sauvegardé.
* **Design Système :** Utilisation d'une palette de couleurs, d'une typographie (`Poppins`) et de composants (boutons, cartes) unifiés dans toute l'application.
* **Animations et Retours Haptiques :** Des animations subtiles et des vibrations améliorent l'expérience et le retour d'information.

## 5. Feuille de Route (Prochaines Étapes)

* **Notifications Proactives :** Mettre en place un système de notifications plus intelligent (rappels conditionnels si un repas est manquant en fin de journée).
* **Suivi du Poids :** Ajouter une fonctionnalité pour enregistrer l'évolution du poids et l'afficher sous forme de graphique.
* **Suggestions par Habitudes :** Améliorer la recherche en proposant d'abord les aliments que l'utilisateur consomme le plus souvent.
* **Infrastructure Backend :** Si le projet évolue vers un modèle B2B (salle de sport), rechercher et implémenter une solution serveur pour gérer plusieurs utilisateurs.