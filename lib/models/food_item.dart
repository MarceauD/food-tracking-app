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

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
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
      // On parse la date stockée en String
      date: map['date'] != null ? DateTime.parse(map['date']) : null,
    );
  }

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
