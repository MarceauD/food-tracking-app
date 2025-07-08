// lib/helpers/nutrition_calculator.dart
import '../models/user_profile.dart';

class NutritionCalculator {
  // Calcule l'âge à partir de la date de naissance
  static int _calculateAge(DateTime dateOfBirth) {
    final now = DateTime.now();
    int age = now.year - dateOfBirth.year;
    if (now.month < dateOfBirth.month ||
        (now.month == dateOfBirth.month && now.day < dateOfBirth.day)) {
      age--;
    }
    return age;
  }

  // Calcule le BMR
  static double _calculateBMR(UserProfile profile) {
    final age = _calculateAge(profile.dateOfBirth);
    if (profile.gender == Gender.male) {
      // Formule pour les hommes
      return 88.362 + (13.397 * profile.weight) + (4.799 * profile.height) - (5.677 * age);
    } else {
      // Formule pour les femmes
      return 447.593 + (9.247 * profile.weight) + (3.098 * profile.height) - (4.330 * age);
    }
  }

  // Multiplicateur d'activité
  static double _getActivityMultiplier(ActivityLevel level) {
    switch (level) {
      case ActivityLevel.sedentary: return 1.2;
      case ActivityLevel.light: return 1.375;
      case ActivityLevel.moderate: return 1.55;
      case ActivityLevel.active: return 1.725;
      case ActivityLevel.veryActive: return 1.9;
    }
  }

  // Fonction principale pour calculer les objectifs
  static Map<String, double> calculateGoals(UserProfile profile, {String objective = 'maintain'}) {
    final bmr = _calculateBMR(profile);
    final activityMultiplier = _getActivityMultiplier(profile.activityLevel);
    
    // Calories pour maintenir le poids
    double maintenanceCalories = bmr * activityMultiplier;

    double targetCalories;

    switch (profile.objective) {
      case Objective.lose:
        targetCalories = maintenanceCalories - 400; // Un déficit modéré de 400 kcal
        break;
      case Objective.gain:
        targetCalories = maintenanceCalories + 400; // Un surplus modéré de 400 kcal
        break;
      case Objective.maintain:
        targetCalories = maintenanceCalories;
    }
    // Répartition standard des macros (40% Glucides, 30% Protéines, 30% Lipides)
    // 1g Glucides = 4 kcal, 1g Protéines = 4 kcal, 1g Lipides = 9 kcal
    final double proteinRatio = profile.objective == Objective.gain ? 0.35 : 0.30;
    final double fatRatio = 0.25;
    final double carbsRatio = 1.0 - proteinRatio - fatRatio;

    final double carbs = (targetCalories * carbsRatio) / 4;
    final double protein = (targetCalories * proteinRatio) / 4;
    final double fat = (targetCalories * fatRatio) / 9;

    return {
      'calories': targetCalories,
      'carbs': carbs,
      'protein': protein,
      'fat': fat,
    };
  }
}