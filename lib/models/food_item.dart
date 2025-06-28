class FoodItem {
  final int? id;
  final String? name;
  final double caloriesPer100g;
  final double proteinPer100g;
  final double carbsPer100g;
  final double fatPer100g;
  final double quantity; // en grammes
  final DateTime? date;

  FoodItem({
    this.id,
    this.name,
    required this.caloriesPer100g,
    required this.proteinPer100g,
    required this.carbsPer100g,
    required this.fatPer100g,
    required this.quantity,
    this.date,
  });

  // Calcule les valeurs en fonction de la quantité consommée
  double get totalCalories => (caloriesPer100g / 100) * quantity;
  double get totalProtein => (proteinPer100g / 100) * quantity;
  double get totalCarbs => (carbsPer100g / 100) * quantity;
  double get totalFat => (fatPer100g / 100) * quantity;


  FoodItem copyWith ({DateTime ? date}) {
    return FoodItem(
      name: name,
      caloriesPer100g : caloriesPer100g,
      proteinPer100g : proteinPer100g,
      fatPer100g : fatPer100g,
      carbsPer100g: carbsPer100g,
      date : date ?? this.date,
      quantity: quantity,
    );
 }

}
