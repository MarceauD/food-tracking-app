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
import 'package:csv/csv.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';

class HomeController with ChangeNotifier {
  final ScrollController _scrollController = ScrollController(); // <-- AJOUTEZ CETTE LIGNE
  // --- PROPRIÉTÉS D'ÉTAT (LES DONNÉES DE L'UI) ---
  List<FoodItem> foodItems = [];
  List<FoodItem> favoriteFoods = [];
  List<SavedMeal> savedMeals = [];
  List<DailySummary> summaries = [];
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

  @override
  void dispose() {
    _scrollController.dispose(); // N'oubliez pas de le disposer
    super.dispose();
  }
  
  Future<void> initializeApp(DateTime selectedDate) async {
    isLoading = true;
    notifyListeners();
    
    // Le premier chargement est complet
    await checkAndResetLogIfNeeded();
    await loadProfile();
    await refreshData(selectedDate);

    isLoading = false;
    notifyListeners();
  }

  Future<void> refreshData(DateTime selectedDate) async {
  // On ne met plus 'isLoading = true', pour éviter de faire clignoter l'UI
  
  // On charge uniquement les données qui changent
  foodItems = await DatabaseHelper.instance.getFoodLogForDate(selectedDate);
  favoriteFoods = await DatabaseHelper.instance.getFavorites();
  savedMeals = await DatabaseHelper.instance.getSavedMeals();
  summaries = await DatabaseHelper.instance.getRecentSummaries(7);
  
  _updateTip(); // On met à jour le conseil
  notifyListeners(); // On notifie l'UI du changement
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

   Future<String> generateWeeklyHtmlReport() async {
    final buffer = StringBuffer();
    final dayFormat = DateFormat('EEEE d MMMM', 'fr_FR');

    // En-tête et style CSS pour un email propre
    buffer.writeln('<html><head><style>');
    buffer.writeln('body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, Oxygen-Sans, Ubuntu, Cantarell, "Helvetica Neue", sans-serif; color: #333; }');
    buffer.writeln('.day-container { border: 1px solid #e0e0e0; border-radius: 8px; margin-bottom: 20px; padding: 16px; background-color: #f9f9f9; }');
    buffer.writeln('h2, h3 { color: #1a1a1a; } h4 { margin-bottom: 5px; }');
    buffer.writeln('.meal-title { font-weight: bold; margin-top: 15px; border-bottom: 1px solid #eee; padding-bottom: 5px; }');
    buffer.writeln('ul { list-style-type: none; padding-left: 0; } li { padding: 5px 0; }');
    buffer.writeln('</style></head><body>');
    buffer.writeln('<h2>Bilan Nutritionnel Détaillé</h2><h3>Client: $userName</h3>');

    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dailyLogByMeal = await DatabaseHelper.instance.getFoodLogForDate(date).then(groupFoodItemsByMeal);

      buffer.writeln('<div class="day-container">');
      buffer.writeln('<h4>${dayFormat.format(date)}</h4>');

      if (dailyLogByMeal.values.every((list) => list.isEmpty)) {
        buffer.writeln('<p><i>Aucun aliment enregistré.</i></p>');
      } else {
        for (final mealEntry in dailyLogByMeal.entries) {
          if (mealEntry.value.isNotEmpty) {
            final mealTotal = mealEntry.value.fold(0.0, (sum, item) => sum + item.totalCalories);
            buffer.writeln('<div class="meal-title">${mealEntry.key.frenchName} - ${mealTotal.toStringAsFixed(0)} kcal</div>');
            buffer.writeln('<ul>');
            for (final item in mealEntry.value) {
              buffer.writeln('<li>${item.name} (${item.quantity?.toStringAsFixed(0)}g) &mdash; <b>${item.totalCalories.toStringAsFixed(0)} kcal</b></li>');
            }
            buffer.writeln('</ul>');
          }
        }
      }
      buffer.writeln('</div>');
    }

    buffer.writeln('</body></html>');
    return buffer.toString();
  }

  Future<String> generateWeeklyTextReport() async {
    final buffer = StringBuffer();
    buffer.writeln('Bilan Nutritionnel Détaillé de la Semaine - $userName\n');
    final today = DateTime.now();
    final dayFormat = DateFormat('EEEE d MMMM', 'fr_FR');

    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dailyLogByMeal = await DatabaseHelper.instance.getFoodLogForDate(date).then(groupFoodItemsByMeal);
      
      buffer.writeln('--- ${dayFormat.format(date)} ---');
      if (dailyLogByMeal.values.every((list) => list.isEmpty)) {
        buffer.writeln('Aucun aliment enregistré pour cette journée.\n');
        continue;
      }

      for (final mealEntry in dailyLogByMeal.entries) {
        if (mealEntry.value.isNotEmpty) {
          final mealTotal = mealEntry.value.fold(0.0, (sum, item) => sum + item.totalCalories);
          buffer.writeln('\n** ${mealEntry.key.frenchName} (${mealTotal.toStringAsFixed(0)} kcal) **');
          for (final item in mealEntry.value) {
            buffer.writeln('- ${item.name} (${item.quantity?.toStringAsFixed(0)}g): ${item.totalCalories.toStringAsFixed(0)} kcal');
          }
        }
      }
      buffer.writeln('');
    }
    return buffer.toString();
  }

  Future<String> generateWeeklyCsvReport() async {
    List<List<dynamic>> rows = [];

    // En-tête du fichier CSV
    rows.add([
      "Date", "Repas", "Aliment", "Quantité (g)",
      "Calories", "Glucides (g)", "Protéines (g)", "Lipides (g)"
    ]);

    final today = DateTime.now();
    for (int i = 6; i >= 0; i--) {
      final date = today.subtract(Duration(days: i));
      final dailyLogByMeal = await DatabaseHelper.instance.getFoodLogForDate(date).then(groupFoodItemsByMeal);

      for (final mealEntry in dailyLogByMeal.entries) {
        for (final item in mealEntry.value) {
          rows.add([
            DateFormat('yyyy-MM-dd').format(date),
            mealEntry.key.frenchName,
            item.name,
            item.quantity,
            item.totalCalories,
            item.totalCarbs,
            item.totalProtein,
            item.totalFat
          ]);
        }
      }
    }

    if (rows.length <= 1) return ""; // Ne génère pas de fichier si seulement l'en-tête est présent

    String csv = const ListToCsvConverter().convert(rows);
    
    // Sauvegarde et retourne le chemin du fichier
    final directory = await getTemporaryDirectory();
    final path = "${directory.path}/bilan_detaille_semaine.csv";
    final file = File(path);
    await file.writeAsString(csv);
    return path;
  }
}