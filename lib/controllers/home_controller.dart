// lib/controllers/home_controller.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart';
import '../models/food_item.dart';
import '../models/saved_meals.dart';

class HomeController {

  Future<void> saveCurrentMeal(String name, List<FoodItem> items) async {
    await DatabaseHelper.instance.saveMeal(name, items);
  }

  // Logique de chargement des objectifs
  Future<Map<String, double>> loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'calories': prefs.getDouble('goalCalories') ?? 1700,
      'carbs': prefs.getDouble('goalCarbs') ?? 150,
      'protein': prefs.getDouble('goalProtein') ?? 160,
      'fat': prefs.getDouble('goalFat') ?? 60,
    };
  }

  // Logique de chargement des favoris
  Future<List<FoodItem>> loadFavorites() async {
    return await DatabaseHelper.instance.getFavorites();
  }

  Future<List<SavedMeal>> loadSavedMeals() async {
    return await DatabaseHelper.instance.getSavedMeals();
  }

  // Logique de chargement du journal
  Future<List<FoodItem>> loadFoodLogForToday() async {
    return await DatabaseHelper.instance.getFoodLogForDate(DateTime.now());
  }

  // Logique pour vider le journal
  Future<void> clearLog() async {
    await DatabaseHelper.instance.clearFoodLog();
  }

  // Logique de traitement pure (pas d'appel externe)
  Map<MealType, List<FoodItem>> groupFoodItemsByMeal(List<FoodItem> items) {
    final Map<MealType, List<FoodItem>> groupedItems = {
      MealType.breakfast: [],
      MealType.lunch: [],
      MealType.dinner: [],
      MealType.snack: [],
    };
    for (final item in items) {
      if (item.mealType != null) {
        groupedItems[item.mealType]!.add(item);
      }
    }
    return groupedItems;
  }

  Future<void> deleteSavedMeal(int id) async {
    await DatabaseHelper.instance.deleteSavedMeal(id);
  }

  // Logique de réinitialisation journalière
  // Elle retourne 'true' si le log a été vidé, sinon 'false'
  Future<bool> checkAndResetLogIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final bool autoResetEnabled = prefs.getBool('autoResetEnabled') ?? true;
    if (!autoResetEnabled) {
      return false;
    }

    final String? lastVisitDateStr = prefs.getString('lastVisitDate');
    final today = DateTime.now();
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    if (lastVisitDateStr == null) {
      await prefs.setString('lastVisitDate', todayDateOnly.toIso8601String());
      return false;
    }

    final lastVisitDate = DateTime.parse(lastVisitDateStr);

    if (lastVisitDate.isBefore(todayDateOnly)) {
      await DatabaseHelper.instance.clearFoodLog();
      await prefs.setString('lastVisitDate', todayDateOnly.toIso8601String());
      return true; // Un reset a eu lieu
    }
    
    return false; // Pas de reset
  }
}