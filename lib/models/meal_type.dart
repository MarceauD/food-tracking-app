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