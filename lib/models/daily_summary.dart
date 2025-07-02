// lib/models/daily_summary.dart

class DailySummary {
  final int? id;
  final DateTime date;
  final double totalCalories;
  final double totalCarbs;
  final double totalProtein;
  final double totalFat;
  final double goalCalories;

  DailySummary({
    this.id,
    required this.date,
    required this.totalCalories,
    required this.totalCarbs,
    required this.totalProtein,
    required this.totalFat,
    required this.goalCalories,
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
    };
  }

  factory DailySummary.fromMap(Map<String, dynamic> map) {
    return DailySummary(
      id: map['id'],
      date: DateTime.parse(map['date']),
      totalCalories: map['total_calories'],
      totalCarbs: map['total_carbs'],
      totalProtein: map['total_protein'],
      totalFat: map['total_fat'],
      goalCalories: map['goal_calories'],
    );
  }
}