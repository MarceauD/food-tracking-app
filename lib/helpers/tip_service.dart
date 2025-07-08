// lib/helpers/tip_service.dart
import 'dart:math';
import '../models/user_profile.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';



class TipService {
  // Une fonction d'aide pour choisir un conseil au hasard dans une liste
  static String _getRandomTip(List<String> tips) {
    final random = Random();
    return tips[random.nextInt(tips.length)];
  }

  static String generateTip(UserProfile? profile, List<FoodItem> foodLog, Map<String, double> goals) {
    if (profile == null) {
      return "Complétez votre profil pour des conseils personnalisés.";
    }

    // --- On récupère toutes les données nécessaires ---
    final hour = DateTime.now().hour;
    final totalCalories = foodLog.fold(0.0, (sum, item) => sum + item.totalCalories);
    final totalProtein = foodLog.fold(0.0, (sum, item) => sum + item.totalProtein);
    final loggedMeals = foodLog.map((e) => e.mealType).toSet();
    final goalCalories = goals['calories'] ?? 2000;
    final goalProtein = goals['protein'] ?? 150;

    // --- MOTEUR DE CONSEILS PAR PRIORITÉ ---
    final List<String? Function()> tipGenerators = [

      () {
        if (foodLog.isEmpty) {
          if (hour < 12) {
            return "Bonjour ! Prêt(e) à commencer la journée ? Enregistrez votre petit-déjeuner pour bien démarrer.";
          }
          if (hour < 18) {
            return "Il est temps d'enregistrer votre déjeuner pour rester sur la bonne voie aujourd'hui !";
          }
          return "N'oubliez pas d'enregistrer vos repas de la journée pour un suivi précis.";
        }
        return null;
      },

      () {
        final hasEatenLunch = loggedMeals.contains(MealType.lunch);
        final hasSkippedBreakfast = !loggedMeals.contains(MealType.breakfast);

        if (hour > 14 && hasSkippedBreakfast && hasEatenLunch) {
          final lunchCalories = foodLog
              .where((item) => item.mealType == MealType.lunch)
              .fold(0.0, (sum, item) => sum + item.totalCalories);
          
          // Si le déjeuner représente plus de 50% de l'objectif total
          if (lunchCalories > goalCalories * 0.5) {
            return "Votre déjeuner a bien compensé ! Pensez à un dîner plus léger pour rester dans votre objectif global.";
          }
        }
        return null;
      },
      
      () {
        if (hour >= 14 && hour < 18 && !loggedMeals.contains(MealType.lunch)) {
          return _getRandomTip([
            "Il semble que vous n'ayez pas encore enregistré votre déjeuner. Pensez-y !",
            "Un déjeuner équilibré est crucial pour l'énergie de l'après-midi. Avez-vous mangé ?",
            "N'oubliez pas d'enregistrer votre déjeuner pour un suivi précis de votre journée."
          ]);
        }
        if (hour >= 21 && !loggedMeals.contains(MealType.dinner)) {
          return _getRandomTip([
            "Pensez à ajouter votre dîner. Chaque repas compte pour atteindre vos objectifs !",
            "Votre journée n'est pas terminée ! Qu'avez-vous mangé pour le dîner ?",
            "Même un dîner léger mérite d'être enregistré. Ne l'oubliez pas !"
          ]);
        }
        return null;
      },

      () {
        List<FoodItem> lastMajorMealItems = [];
        String mealNameToCompensate = "";

        if (hour >= 14 && hour < 19 && loggedMeals.contains(MealType.lunch)) {
          lastMajorMealItems = foodLog.where((item) => item.mealType == MealType.lunch).toList();
          mealNameToCompensate = "dîner";
        } else if (hour >= 10 && hour < 14 && loggedMeals.contains(MealType.breakfast)) {
          lastMajorMealItems = foodLog.where((item) => item.mealType == MealType.breakfast).toList();
          mealNameToCompensate = "déjeuner";
        }
        
        if (lastMajorMealItems.isNotEmpty) {
          final mealCalories = lastMajorMealItems.fold(0.0, (sum, item) => sum + item.totalCalories);
          final mealCarbs = lastMajorMealItems.fold(0.0, (sum, item) => sum + item.totalCarbs);
          final mealProtein = lastMajorMealItems.fold(0.0, (sum, item) => sum + item.totalProtein);
          
          // On vérifie si les glucides représentent plus de 65% des calories du repas
          if ((mealCarbs * 4) > (mealCalories * 0.65)) {
            return "Votre dernier repas était riche en glucides. Pensez à privilégier les protéines et les légumes pour votre $mealNameToCompensate.";
          }
          // On vérifie si les protéines sont très basses
          if ((mealProtein * 4) < (mealCalories * 0.10)) {
            return "Il semble que votre dernier repas manquait de protéines. Une source de protéines maigres à votre prochain $mealNameToCompensate serait une excellente idée.";
          }
        }
        return null;
      },
      // 1. CONSEILS SPÉCIFIQUES À L'OBJECTIF & AU MOMENT DE LA JOURNÉE
      () {
        switch (profile.objective) {
          case Objective.lose:
            // --- Perte de poids ---
            if (hour >= 20 && totalCalories > goalCalories) {
              return _getRandomTip([
                "Objectif dépassé aujourd'hui. Pas de souci, concentrez-vous sur demain !",
                "Un petit écart arrive. L'important est de reprendre vos bonnes habitudes dès le prochain repas.",
                "Ne vous découragez pas, la perte de poids est un marathon, pas un sprint."
              ]);
            }
            if (hour >= 12 && hour < 15 && totalProtein < goalProtein * 0.3) {
              return _getRandomTip([
                "Pour votre déjeuner, pensez à une bonne source de protéines (poulet, poisson, tofu) pour vous sentir rassasié.",
                "Les protéines sont vos alliées pour la satiété. Assurez-vous d'en avoir assez au déjeuner.",
                "Un repas riche en protéines ce midi vous aidera à éviter les fringales de l'après-midi."
              ]);
            }
            break;

          case Objective.gain:
            // --- Prise de masse ---
            if (hour >= 21 && totalCalories < goalCalories) {
              return _getRandomTip([
                "Il vous manque des calories ! Un shaker de caséine ou un bol de fromage blanc avant de dormir peut vous aider.",
                "Ne terminez pas la journée en déficit. Une collation post-dîner est une bonne stratégie.",
                "Pour la prise de masse, chaque calorie compte. Pensez à une dernière collation ce soir."
              ]);
            }
            if (hour >= 15 && hour < 18 && totalCalories < goalCalories * 0.6) {
              return _getRandomTip([
                "C'est l'heure de la collation ! Pensez aux amandes, aux bananes ou à un yaourt grec.",
                "Ne sautez pas la collation de l'après-midi, elle est essentielle pour votre prise de masse.",
                "Un apport régulier en nutriments est la clé. Une collation maintenant serait parfaite."
              ]);
            }
            break;

          case Objective.maintain:
            // --- Maintien ---
            if (hour >= 20 && totalCalories > goalCalories - 150 && totalCalories < goalCalories + 150) {
              return _getRandomTip([
                "Parfaitement dans votre objectif de maintien aujourd'hui. Excellent travail !",
                "Vous maîtrisez l'équilibre à la perfection. Continuez comme ça !",
                "C'est ce qu'on appelle une journée réussie ! Bravo pour cette régularité."
              ]);
            }
            if (hour >= 10 && hour < 12 && !loggedMeals.contains(MealType.breakfast)) {
              return _getRandomTip([
                "Le maintien passe par des repas réguliers. N'oubliez pas votre petit-déjeuner !",
                "Un bon petit-déjeuner vous donnera l'énergie nécessaire pour la matinée.",
                "Commencez la journée du bon pied avec un petit-déjeuner équilibré."
              ]);
            }
            break;
        }
        return null; // Pas de conseil spécifique trouvé
      },

      // 2. CONSEILS GÉNÉRIQUES SUR LA NUTRITION ET LE BIEN-ÊTRE
      () {
        final genericTips = [
          "L'hydratation est la clé ! Avez-vous pensé à boire assez d'eau aujourd'hui ?",
          "Un verre d'eau avant chaque repas peut aider à la digestion et à la satiété.",

          // Nutrition & Bien-être
          "Les fibres sont vos alliées. Les légumes verts et les légumineuses en sont d'excellentes sources.",
          "Pensez aux bonnes graisses ! Un peu d'avocat, de noix ou d'huile d'olive est excellent pour la santé.",
          "Les couleurs dans votre assiette sont souvent un signe de variété nutritionnelle. Essayez de manger un arc-en-ciel !",
          "Une petite marche de 15 minutes après le repas peut faire des merveilles pour la digestion.",
          "La planification des repas de la semaine est une excellente stratégie pour rester sur la bonne voie.",
          "Limitez les sucres ajoutés. Ils apportent des calories vides sans nutriments essentiels.",
          "Écoutez votre corps. Mangez quand vous avez faim, arrêtez-vous quand vous êtes rassasié.",

          // Motivation & Mental
          "Un sommeil de qualité est aussi important que votre nutrition pour atteindre vos objectifs.",
          "La régularité est plus importante que la perfection. Chaque petit pas compte.",
          "Ne vous comparez pas aux autres. Chaque parcours est unique. Concentrez-vous sur vos propres progrès.",
          "Célébrez vos petites victoires ! Chaque journée réussie est un pas dans la bonne direction.",
          "Si vous avez une envie de sucre, un fruit est une excellente alternative saine et naturelle.",
        ];
        return _getRandomTip(genericTips);
      }
    ];

    // On parcourt nos générateurs et on retourne le premier conseil valide trouvé
    for (final generator in tipGenerators) {
      final tip = generator();
      if (tip != null) {
        return tip;
      }
    }
    
    return "Bonne continuation !"; // Ne devrait jamais être atteint
  }
}