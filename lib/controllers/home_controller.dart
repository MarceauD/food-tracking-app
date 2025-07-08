// lib/controllers/home_controller.dart

import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart';
import '../models/food_item.dart';
import '../models/saved_meals.dart';
import '../models/daily_summary.dart';
import '../models/meal_type.dart';
import '../models/user_profile.dart';
import 'dart:math';
import 'package:intl/intl.dart';
import '../helpers/nutrition_calculator.dart';
import '../widgets/common/notification_service.dart';


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

  Future<void> updateSummaryForDate(DateTime date) async {
    // 1. On charge tous les aliments pour cette date
    final foodsForDay = await DatabaseHelper.instance.getFoodLogForDate(date);
    
    // 2. On utilise la méthode de calcul existante
    final summary = _calculateSummaryForDay(date, foodsForDay);
    
    // 3. On sauvegarde le nouveau résumé dans la base de données
    await DatabaseHelper.instance.saveOrUpdateSummary(summary);
    print("📈 Résumé pour le ${DateFormat('d/M').format(date)} mis à jour.");
  }
  
  Future<void> clearAllFavorites() async {
    await DatabaseHelper.instance.clearFavorites();
  }

  Future<void> clearAllSavedMeals() async {
    await DatabaseHelper.instance.clearSavedMeals();
  }

  Future<bool> addFoodItemToFavorites(FoodItem item) async {
    // On appelle directement le DatabaseHelper qui contient déjà la logique
    // pour vérifier les doublons.
    return await DatabaseHelper.instance.createFavorite(item);
  }

  // Logique de chargement des favoris
  Future<List<FoodItem>> loadFavorites() async {
    return await DatabaseHelper.instance.getFavorites();
  }

  Future<List<SavedMeal>> loadSavedMeals() async {
    return await DatabaseHelper.instance.getSavedMeals();
  }

  Future<void> saveOrUpdateSummary(DailySummary summary) async {
    await DatabaseHelper.instance.saveOrUpdateSummary(summary);
  }
  
  Future<List<DailySummary>> getRecentSummaries() async {
    return await DatabaseHelper.instance.getRecentSummaries(7); // On charge les 7 derniers jours
  }

  // Logique de chargement du journal
  Future<List<FoodItem>> loadFoodLogForDate(DateTime date) async {
    return await DatabaseHelper.instance.getFoodLogForDate(date);
  }

  // Logique pour vider le journal
  Future<void> clearLog() async {
    await DatabaseHelper.instance.clearFoodLog();
  }

  Future<void> submitFood(FoodItem item) async {
    await DatabaseHelper.instance.createFoodLog(item);
  }

  Future<void> deleteFoodLogItem(int id) async {
    await DatabaseHelper.instance.deleteFoodLog(id);
  }

  Future<void> updateFoodLogItemQuantity(int id, double newQuantity) async {
    await DatabaseHelper.instance.updateFoodLogQuantity(id, newQuantity);
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

  Future<void> generateAndSaveFakeSummaries() async {
    final db = DatabaseHelper.instance;
    final random = Random();

    // 1. On nettoie les anciennes données
    await db.clearFoodLog();
    await db.clearSummaries();

    // 2. Notre "banque" d'aliments possibles
    final Map<MealType, List<FoodItem>> foodBank = {
      MealType.breakfast: [
        FoodItem(name: 'Flocons d\'avoine', caloriesPer100g: 370, proteinPer100g: 13, carbsPer100g: 60, fatPer100g: 7, quantity: 40),
        FoodItem(name: 'Yaourt Grec', caloriesPer100g: 59, proteinPer100g: 10, carbsPer100g: 3.6, fatPer100g: 0.4, quantity: 150),
        FoodItem(name: 'Tranche de Pain Complet', caloriesPer100g: 259, proteinPer100g: 13, carbsPer100g: 41, fatPer100g: 3.4, quantity: 40),
        FoodItem(name: 'Confiture', caloriesPer100g: 240, proteinPer100g: 0.3, carbsPer100g: 60, fatPer100g: 0.1, quantity: 20),
      ],
      MealType.lunch: [
        FoodItem(name: 'Filet de Poulet', caloriesPer100g: 165, proteinPer100g: 31, carbsPer100g: 0, fatPer100g: 3.6, quantity: 150),
        FoodItem(name: 'Pavé de Saumon', caloriesPer100g: 208, proteinPer100g: 20, carbsPer100g: 0, fatPer100g: 13, quantity: 130),
        FoodItem(name: 'Pâtes complètes (cuites)', caloriesPer100g: 135, proteinPer100g: 5.5, carbsPer100g: 26, fatPer100g: 1, quantity: 180),
        FoodItem(name: 'Lentilles Vertes (cuites)', caloriesPer100g: 116, proteinPer100g: 9, carbsPer100g: 20, fatPer100g: 0.4, quantity: 200),
        FoodItem(name: 'Haricots Verts', caloriesPer100g: 31, proteinPer100g: 1.8, carbsPer100g: 7, fatPer100g: 0.1, quantity: 150),
      ],
      MealType.dinner: [
        FoodItem(name: 'Soupe de légumes', caloriesPer100g: 30, proteinPer100g: 1, carbsPer100g: 5, fatPer100g: 0.5, quantity: 350),
        FoodItem(name: 'Salade composée', caloriesPer100g: 80, proteinPer100g: 5, carbsPer100g: 8, fatPer100g: 3, quantity: 250),
        FoodItem(name: 'Filet de Colin', caloriesPer100g: 82, proteinPer100g: 19, carbsPer100g: 0, fatPer100g: 0.7, quantity: 150),
        FoodItem(name: 'Quinoa (cuit)', caloriesPer100g: 120, proteinPer100g: 4.4, carbsPer100g: 21, fatPer100g: 1.9, quantity: 150),
      ],
      MealType.snack: [
        FoodItem(name: 'Pomme', caloriesPer100g: 52, proteinPer100g: 0.3, carbsPer100g: 14, fatPer100g: 0.2, quantity: 150),
        FoodItem(name: 'Poignée d\'amandes', caloriesPer100g: 579, proteinPer100g: 21, carbsPer100g: 22, fatPer100g: 49, quantity: 30),
        FoodItem(name: 'Carré de chocolat noir', caloriesPer100g: 600, proteinPer100g: 7, carbsPer100g: 61, fatPer100g: 35, quantity: 10),
      ],
    };

    // 3. On boucle sur les 7 derniers jours
    for (int i = 1; i <= 7; i++) {
      final date = DateTime.now().subtract(Duration(days: i));
      final List<FoodItem> dailyFoods = [];

      // Pour chaque repas, on choisit 1 ou 2 aliments au hasard dans la banque
      foodBank.forEach((mealType, foods) {
        if (mealType == MealType.snack && !random.nextBool()) return; // On saute la collation une fois sur deux
        
        final food1 = foods[random.nextInt(foods.length)];
        dailyFoods.add(food1.copyWith(date: date, mealType: mealType));
        
        // On ajoute un deuxième aliment différent une fois sur deux
        if (random.nextBool() && foods.length > 1) {
          FoodItem food2;
          do {
            food2 = foods[random.nextInt(foods.length)];
          } while (food2.name == food1.name); // Pour ne pas avoir deux fois le même
          dailyFoods.add(food2.copyWith(date: date, mealType: mealType));
        }
      });

      // 4. On sauvegarde les aliments générés pour cette journée
      for (final food in dailyFoods) {
        await db.createFoodLog(food);
      }

      // 5. On calcule le résumé de la journée à partir de ces aliments
      final summary = _calculateSummaryForDay(date, dailyFoods);
      await db.saveOrUpdateSummary(summary);
    }

    print("✅ 7 jours de données de test variées ont été générés.");
  }

  DailySummary _calculateSummaryForDay(DateTime date, List<FoodItem> foods) {
    final totalCalories = foods.fold(0.0, (s, e) => s + e.totalCalories);
    final totalCarbs = foods.fold(0.0, (s, e) => s + e.totalCarbs);
    final totalProtein = foods.fold(0.0, (s, e) => s + e.totalProtein);
    final totalFat = foods.fold(0.0, (s, e) => s + e.totalFat);
    final loggedMeals = foods.map((e) => e.mealType!).toSet();

    double getMealCalories(MealType type) => foods.where((f) => f.mealType == type).fold(0.0, (s, e) => s + e.totalCalories);

    return DailySummary(
      date: date,
      totalCalories: totalCalories,
      goalCalories: 2200, // On peut le récupérer des SharedPreferences pour plus de réalisme
      totalCarbs: totalCarbs,
      totalProtein: totalProtein,
      totalFat: totalFat,
      loggedMeals: loggedMeals,
      breakfastCalories: getMealCalories(MealType.breakfast),
      lunchCalories: getMealCalories(MealType.lunch),
      dinnerCalories: getMealCalories(MealType.dinner),
      snackCalories: getMealCalories(MealType.snack),
    );
  }

  Future<String> generateDailyReport(DailySummary summary) async {
    final dayFormat = DateFormat('EEEE d MMMM yyyy', 'fr_FR');
    final buffer = StringBuffer();

    final userProfile = await DatabaseHelper.instance.getUserProfile();
    final goals = userProfile != null ? NutritionCalculator.calculateGoals(userProfile, objective: userProfile.objective.name) : <String, double>{};
    final goalCarbs = goals['carbs'] ?? 0;
    final goalProtein = goals['protein'] ?? 0;
    final goalFat = goals['fat'] ?? 0;

    // On récupère le détail des aliments pour cette journée
    buffer.writeln("🗓️ Date : ${dayFormat.format(summary.date)}");
    buffer.writeln("======================================");
    final dailyFoods = await DatabaseHelper.instance.getFoodLogForDate(summary.date);

    final goalStatus = summary.totalCalories <= summary.goalCalories 
      ? "Objectif Atteint ✔️" 
      : "Objectif Dépassé ❌";

  buffer.writeln("📊 RÉSUMÉ");
  buffer.writeln("   Calories : ${summary.totalCalories.toStringAsFixed(0)} / ${summary.goalCalories.toStringAsFixed(0)} kcal ($goalStatus)");
  buffer.writeln("   Macros   : Glucides 🔥 : ${summary.totalCarbs.toStringAsFixed(0)} / ${goalCarbs.toStringAsFixed(0)} g | Protéines 💪 : ${summary.totalProtein.toStringAsFixed(0)} / ${goalProtein.toStringAsFixed(0)} g | Lipides 💧 : ${summary.totalFat.toStringAsFixed(0)} / ${goalFat.toStringAsFixed(0)}g ");  
  buffer.writeln(); // Ligne vide

  buffer.writeln("📖 JOURNAL DÉTAILLÉ");

  if (dailyFoods.isEmpty) {
    buffer.writeln("   Aucun aliment enregistré pour cette journée.");
  } else {
    final groupedFoods = groupFoodItemsByMeal(dailyFoods);
    for (var mealType in MealType.values) {
      final items = groupedFoods[mealType]!;
      if (items.isNotEmpty) {
        buffer.writeln(); // Saut de ligne avant chaque repas
        final mealCalories = items.fold(0.0, (sum, item) => sum + item.totalCalories);
        buffer.writeln("  - ${mealType.frenchName} (${mealCalories.toStringAsFixed(0)} kcal) :");
        
        for (var item in items) {
          final macrosDetail = "🔥 : ${item.totalCarbs.toStringAsFixed(0)} g | 💪 : ${item.totalProtein.toStringAsFixed(0)} g | 💧 : ${item.totalFat.toStringAsFixed(0)} g ";
          buffer.writeln("    • ${item.name ?? 'N/A'} (${item.quantity?.toStringAsFixed(0)}g) : ${item.totalCalories.toStringAsFixed(0)} kcal ($macrosDetail)");
        }
      }
    }
  }
    
    return buffer.toString();
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

  Future<UserProfile?> loadProfile() async {
    return await DatabaseHelper.instance.getUserProfile();
  }

  Future<void> copyMealFromYesterday(MealType mealType, DateTime selectedDate) async {
    // 1. On détermine la date d'hier
    final yesterday = selectedDate.subtract(const Duration(days: 1));
    
    // 2. On récupère tous les aliments d'hier
    final yesterdayFoods = await DatabaseHelper.instance.getFoodLogForDate(yesterday);
    
    // 3. On ne garde que ceux qui correspondent au repas que l'on veut copier
    final foodsToCopy = yesterdayFoods.where((item) => item.mealType == mealType).toList();

    if (foodsToCopy.isEmpty) {
      // On pourrait retourner un message pour l'afficher à l'utilisateur
      print("Aucun aliment à copier pour le ${mealType.name} d'hier.");
      return;
    }

    // 4. On boucle sur ces aliments et on les insère pour aujourd'hui
    for (final item in foodsToCopy) {
      // On utilise copyWith pour créer une nouvelle instance avec la date d'aujourd'hui
      final newItem = item.copyWith(
        date: selectedDate,
        forceIdToNull: true, // Pour que la base de données lui donne un nouvel ID
      );
      await DatabaseHelper.instance.createFoodLog(newItem);
    }
  }

  Future<void> checkAndTriggerEveningNotification() async {
    final now = DateTime.now();
    
    // On ne fait ce contrôle que le soir, par exemple entre 19h et 20h
    if (now.hour >= 19 && now.hour < 20) {
      final todaysLog = await DatabaseHelper.instance.getFoodLogForDate(now);
      final loggedMeals = todaysLog.map((item) => item.mealType).toSet();

      String? notificationTitle;
      String? notificationBody;

      // Scénario 1 : Déjeuner manquant
      if (!loggedMeals.contains(MealType.lunch)) {
        notificationTitle = 'Un petit oubli ? 🤔';
        notificationBody = 'Il semble que votre déjeuner n\'a pas été enregistré aujourd\'hui.';
      }
      // Scénario 2 : Dîner manquant (si on est plus tard)
      else if (now.hour >= 21 && !loggedMeals.contains(MealType.dinner)) {
        notificationTitle = 'Presque la fin de la journée !';
        notificationBody = 'Pensez à enregistrer votre dîner pour compléter votre journal.';
      }
      
      // Si on a trouvé une raison de notifier l'utilisateur...
      if (notificationTitle != null && notificationBody != null) {
        final notificationService = NotificationService();
        // On utilise un ID unique pour ne pas écraser d'autres notifications
        await notificationService.showOneTimeNotification(
          id: 99, 
          title: notificationTitle,
          body: notificationBody,
        );
      }
    }
  }
}