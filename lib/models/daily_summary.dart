import 'meal_type.dart';

class DailySummary {
  final int? id;
  final DateTime date;
  final double totalCalories;
  final double totalCarbs;
  final double totalProtein;
  final double totalFat;
  final double goalCalories;
  final Set<MealType> loggedMeals;
  final double breakfastCalories;
  final double lunchCalories;
  final double dinnerCalories;
  final double snackCalories; 

  DailySummary({
    this.id,
    required this.date,
    required this.totalCalories,
    required this.totalCarbs,
    required this.totalProtein,
    required this.totalFat,
    required this.goalCalories,
    required this.loggedMeals, 
    required this.breakfastCalories,
    required this.lunchCalories,
    required this.dinnerCalories,
    required this.snackCalories,// <-- AJOUTER AU CONSTRUCTEUR
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'date': date.toIso8601String().substring(0, 10), // On stocke la date au format YYYY-MM-DD
      'total_calories': totalCalories,
      'total_carbs': totalCarbs,
      'total_protein': totalProtein,
      'total_fat': totalFat,
      'goal_calories': goalCalories,
      'logged_meals': loggedMeals.map((m) => m.name).join(','),
      'breakfast_calories': breakfastCalories,
      'lunch_calories': lunchCalories,
      'dinner_calories': dinnerCalories,
      'snack_calories': snackCalories,
    };
  }

  factory DailySummary.fromMap(Map<String, dynamic> map) {
    final mealsString = map['logged_meals'] as String? ?? '';
    final loggedMeals = mealsString.split(',')
        .where((name) => name.isNotEmpty)
        .map((name) => MealType.values.byName(name))
        .toSet();


    return DailySummary(
      id: map['id'],
      date: DateTime.parse(map['date']),
      totalCalories: map['total_calories'],
      totalCarbs: map['total_carbs'],
      totalProtein: map['total_protein'],
      totalFat: map['total_fat'],
      goalCalories: map['goal_calories'],
      loggedMeals: loggedMeals, 
      breakfastCalories: map['breakfast_calories'] ?? 0.0,
      lunchCalories: map['lunch_calories'] ?? 0.0,
      dinnerCalories: map['dinner_calories'] ?? 0.0,
      snackCalories: map['snack_calories'] ?? 0.0,
    );
  }
}