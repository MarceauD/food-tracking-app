// lib/controllers/home_controller.dart

import '../widgets/common/notification_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'dart:math';

import '../helpers/database_helper.dart';
import '../helpers/nutrition_calculator.dart';
import '../helpers/tip_service.dart';
import '../models/daily_summary.dart';
import '../models/food_item.dart';
import '../models/meal_type.dart';
import '../models/saved_meals.dart';
import '../models/user_profile.dart';

class HomeController with ChangeNotifier {
  // --- PROPRIÉTÉS D'ÉTAT (LES DONNÉES DE L'UI) ---
  List<FoodItem> foodItems = [];
  List<FoodItem> favoriteFoods = [];
  List<SavedMeal> savedMeals = [];
  UserProfile? userProfile;
  String currentTip = "";
  String userName = 'Utilisateur';

  double goalCalories = 2000;
  double goalProtein = 150;
  double goalCarbs = 200;
  double goalFat = 70;

  bool isLoading = true;

  // --- GETTERS (Pour des calculs simples basés sur l'état) ---
  double get totalCalories => foodItems.fold(0, (sum, item) => sum + item.totalCalories);
  double get totalProtein => foodItems.fold(0, (sum, item) => sum + item.totalProtein);
  double get totalCarbs => foodItems.fold(0, (sum, item) => sum + item.totalCarbs);
  double get totalFat => foodItems.fold(0, (sum, item) => sum + item.totalFat);

  // --- MÉTHODES DE GESTION DES DONNÉES ---

  Future<void> initializeApp(DateTime selectedDate) async {
    isLoading = true;
    notifyListeners();
    
    await checkAndResetLogIfNeeded();
    await loadProfile();
    await refreshData(selectedDate);

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshData(DateTime selectedDate) async {
    isLoading = true;
    notifyListeners();

    final goalsData = await _loadGoals();
    favoriteFoods = await DatabaseHelper.instance.getFavorites();
    savedMeals = await DatabaseHelper.instance.getSavedMeals();
    foodItems = await DatabaseHelper.instance.getFoodLogForDate(selectedDate);
    
    goalCalories = goalsData['calories']!;
    goalCarbs = goalsData['carbs']!;
    goalProtein = goalsData['protein']!;
    goalFat = goalsData['fat']!;

    await updateSummaryForDate(selectedDate);
    _updateTip();

    isLoading = false;
    notifyListeners();
  }

  Future<void> addSavedMealToLog(SavedMeal savedMeal, MealType mealType, DateTime date) async {
    for (final itemTemplate in savedMeal.items) {
      final itemToLog = itemTemplate.copyWith(
        date: date,
        mealType: mealType,
        forceIdToNull: true,
      );
      await DatabaseHelper.instance.createFoodLog(itemToLog);
    }
  }
  
  Future<void> loadProfile() async {
    userProfile = await DatabaseHelper.instance.getUserProfile();
    userName = userProfile?.name ?? 'Utilisateur';
    notifyListeners();
  }

  Future<void> checkAndResetLogIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final String? lastVisitDateStr = prefs.getString('lastVisitDate');
    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    if (lastVisitDateStr == null) {
      await prefs.setString('lastVisitDate', today.toIso8601String());
      return;
    }
    
    final lastVisitDate = DateTime.parse(lastVisitDateStr);
    if (lastVisitDate.isBefore(today)) {
      final lastDayLog = await DatabaseHelper.instance.getFoodLogForDate(lastVisitDate);
      if (lastDayLog.isNotEmpty) {
        await updateSummaryForDate(lastVisitDate, logToUpdate: lastDayLog);
      }
      await DatabaseHelper.instance.clearFoodLog();
      await prefs.setString('lastVisitDate', today.toIso8601String());
    }
  }

  void _updateTip() {
    final goals = {'calories': goalCalories, 'carbs': goalCarbs, 'protein': goalProtein, 'fat': goalFat};
    currentTip = TipService.generateTip(userProfile, foodItems, goals);
  }

  Future<Map<String, double>> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    return {
      'calories': prefs.getDouble('goalCalories') ?? 1700,
      'carbs': prefs.getDouble('goalCarbs') ?? 150,
      'protein': prefs.getDouble('goalProtein') ?? 160,
      'fat': prefs.getDouble('goalFat') ?? 60,
    };
  }

  Future<void> updateSummaryForDate(DateTime date, {List<FoodItem>? logToUpdate}) async {
    final log = logToUpdate ?? await DatabaseHelper.instance.getFoodLogForDate(date);

    double tempTotalCalories = log.fold(0, (sum, item) => sum + item.totalCalories);
    double tempTotalCarbs = log.fold(0, (sum, item) => sum + item.totalCarbs);
    double tempTotalProtein = log.fold(0, (sum, item) => sum + item.totalProtein);
    double tempTotalFat = log.fold(0, (sum, item) => sum + item.totalFat);
    
    double calculateMealCalories(MealType mealType) {
      return log.where((item) => item.mealType == mealType).fold(0, (sum, item) => sum + item.totalCalories);
    }

    final summary = DailySummary(
      date: date,
      totalCalories: tempTotalCalories,
      totalCarbs: tempTotalCarbs,
      totalProtein: tempTotalProtein,
      totalFat: tempTotalFat,
      goalCalories: goalCalories,
      loggedMeals: log.map((e) => e.mealType!).toSet(),
      breakfastCalories: calculateMealCalories(MealType.breakfast),
      lunchCalories: calculateMealCalories(MealType.lunch),
      dinnerCalories: calculateMealCalories(MealType.dinner),
      snackCalories: calculateMealCalories(MealType.snack),
    );
    await DatabaseHelper.instance.saveOrUpdateSummary(summary);
  }

  Map<MealType, List<FoodItem>> groupFoodItemsByMeal(List<FoodItem> items) {
    final Map<MealType, List<FoodItem>> groupedItems = {
      MealType.breakfast: [], MealType.lunch: [], MealType.dinner: [], MealType.snack: [],
    };
    for (final item in items) {
      if (item.mealType != null) {
        groupedItems[item.mealType]!.add(item);
      }
    }
    return groupedItems;
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

  Future<bool> addFoodItemToFavorites(FoodItem item) async {
    return await DatabaseHelper.instance.createFavorite(item);
  }
  
  Future<void> deleteFavorite(int id) async {
    await DatabaseHelper.instance.deleteFavorite(id);
  }

  Future<void> saveCurrentMeal(String name, List<FoodItem> items) async {
    await DatabaseHelper.instance.saveMeal(name, items);
  }
  
  Future<void> deleteSavedMeal(int id) async {
    await DatabaseHelper.instance.deleteSavedMeal(id);
  }

  Future<void> copyMealFromYesterday(MealType mealType, DateTime selectedDate) async {
    final yesterday = selectedDate.subtract(const Duration(days: 1));
    final yesterdayFoods = await DatabaseHelper.instance.getFoodLogForDate(yesterday);
    final foodsToCopy = yesterdayFoods.where((item) => item.mealType == mealType).toList();
    if (foodsToCopy.isEmpty) return;
    for (final item in foodsToCopy) {
      final newItem = item.copyWith(date: selectedDate, forceIdToNull: true);
      await DatabaseHelper.instance.createFoodLog(newItem);
    }
  }

  Future<void> clearAllFavorites() async {
    await DatabaseHelper.instance.clearFavorites();
  }

  Future<void> clearAllSavedMeals() async {
    await DatabaseHelper.instance.clearSavedMeals();
  }
  
  Future<List<DailySummary>> getRecentSummaries() async {
    return await DatabaseHelper.instance.getRecentSummaries(7);
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
}