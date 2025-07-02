enum MealType { breakfast, lunch, dinner, snack }

extension MealTypeExtension on MealType {
  String get frenchName {
    switch (this) {
      case MealType.breakfast:
        return 'Petit-déjeuner';
      case MealType.lunch:
        return 'Déjeuner';
      case MealType.dinner:
        return 'Dîner';
      case MealType.snack:
        return 'Collation';
    }
  }
}

class FoodItem {
  final int? id;
  final String? name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  double? quantity;
  final MealType? mealType;
  final DateTime? date;

  FoodItem({
    this.id,
    this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    this.quantity,
    this.mealType,
    this.date,
  });

  // Calcule les valeurs en fonction de la quantité consommée
  double get totalCalories => (caloriesPer100g / 100) * (quantity ?? 0);
  double get totalProtein => (proteinPer100g / 100) * (quantity ?? 0);
  double get totalCarbs => (carbsPer100g / 100) * (quantity ?? 0);
  double get totalFat => (fatPer100g / 100) * (quantity ?? 0);

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'mealType': mealType?.name, 
      'caloriesPer100g': caloriesPer100g,
      'proteinPer100g': proteinPer100g,
      'carbsPer100g': carbsPer100g,
      'fatPer100g': fatPer100g,
      'quantity': quantity,
      // On stocke la date en format ISO 8601 (String)
      'date': date?.toIso8601String(), 
    };
  }

  factory FoodItem.fromMap(Map<String, dynamic> map) {
    return FoodItem(
      id: map['id'],
      name: map['name'],
      caloriesPer100g: map['caloriesPer100g'],
      proteinPer100g: map['proteinPer100g'],
      carbsPer100g: map['carbsPer100g'],
      fatPer100g: map['fatPer100g'],
      quantity: map['quantity'],
      mealType: map['mealType'] != null
          ? MealType.values.byName(map['mealType'])
          : null,
      // On parse la date stockée en String
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
    );
  }

  FoodItem copyWith({
    int? id,
    String? name,
    double? caloriesPer100g,
    double? proteinPer100g,
    double? carbsPer100g,
    double? fatPer100g,
    double? quantity,
    MealType? mealType,
    DateTime? date,

    bool forceIdToNull = false, 
  }) {
    return FoodItem(
      id: forceIdToNull ? null : (id ?? this.id),
      name: name ?? this.name,
      caloriesPer100g: caloriesPer100g ?? this.caloriesPer100g,
      proteinPer100g: proteinPer100g ?? this.proteinPer100g,
      carbsPer100g: carbsPer100g ?? this.carbsPer100g,
      fatPer100g: fatPer100g ?? this.fatPer100g,
      quantity: quantity ?? this.quantity,
      mealType: mealType ?? this.mealType,
      date: date ?? this.date,
    );
  }
 }
