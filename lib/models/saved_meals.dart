// lib/models/saved_meal.dart
import 'food_item.dart';

class SavedMeal {
  final int? id;
  final String name;
  final List<FoodItem> items;

  SavedMeal({
    this.id,
    required this.name,
    required this.items,
  });
}