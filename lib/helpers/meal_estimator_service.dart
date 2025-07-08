// lib/helpers/meal_estimator_service.dart
import '../models/food_item.dart';
import '../models/meal_type.dart';

// --- Définitions des choix possibles ---

enum PlatType { sale, sucre, boisson }
// On ajoute une extension pour la traduction
extension PlatTypeExtension on PlatType {
  String get frenchName {
    switch (this) {
      case PlatType.sale: return 'Plat Salé';
      case PlatType.sucre: return 'Dessert/Sucré';
      case PlatType.boisson: return 'Boisson';
    }
  }
}

enum PortionSize { small, normal, large }
extension PortionSizeExtension on PortionSize {
  String get frenchName {
    switch (this) {
      case PortionSize.small: return 'Petite';
      case PortionSize.normal: return 'Normale';
      case PortionSize.large: return 'Grande';
    }
  }
}

// Pour les plats salés
enum SaleComponent { viandeRouge, volaillePoisson, feculents, legumes }
extension SaleComponentExtension on SaleComponent {
  String get frenchName {
    switch (this) {
      case SaleComponent.viandeRouge: return 'Viande Rouge';
      case SaleComponent.volaillePoisson: return 'Volaille / Poisson';
      case SaleComponent.feculents: return 'Féculents';
      case SaleComponent.legumes: return 'Légumes';
    }
  }
}

enum SaleModifier { sauceLegere, sauceRiche, fromage, friture }
extension SaleModifierExtension on SaleModifier {
  String get frenchName {
    switch (this) {
      case SaleModifier.sauceLegere: return 'Sauce légère';
      case SaleModifier.sauceRiche: return 'Sauce riche / Crème';
      case SaleModifier.fromage: return 'Fromage ajouté';
      case SaleModifier.friture: return 'Friture';
    }
  }
}

// Pour les plats sucrés/desserts
enum SucreComponent { fruit, patisserie, cremeGlacee, chocolat }
extension SucreComponentExtension on SucreComponent {
  String get frenchName {
    switch (this) {
      case SucreComponent.fruit: return 'Fruit';
      case SucreComponent.patisserie: return 'Gâteau / Pâtisserie';
      case SucreComponent.cremeGlacee: return 'Crème / Glace';
      case SucreComponent.chocolat: return 'Chocolat';
    }
  }
}

// Pour les boissons
enum BoissonComponent { eau, soda, jusFruit, alcool }
extension BoissonComponentExtension on BoissonComponent {
  String get frenchName {
    switch (this) {
      case BoissonComponent.eau: return 'Eau';
      case BoissonComponent.soda: return 'Soda / Boisson sucrée';
      case BoissonComponent.jusFruit: return 'Jus de fruit';
      case BoissonComponent.alcool: return 'Boisson alcoolisée';
    }
  }
}

enum SucreModifier { chantilly, coulis_chocolat }
enum BoissonModifier { sucre_ajoute, lait }

extension SucreModifierExtension on SucreModifier {
  String get frenchName {
    switch (this) {
      case SucreModifier.chantilly: return 'Avec chantilly';
      case SucreModifier.coulis_chocolat: return 'Avec coulis chocolat';
    }
  }
}

extension BoissonModifierExtension on BoissonModifier {
  String get frenchName {
    switch (this) {
      case BoissonModifier.sucre_ajoute: return 'Avec sucre ajouté';
      case BoissonModifier.lait: return 'Avec du lait';
    }
  }
}

class MealEstimatorService {
  // --- Tables de valeurs caloriques ---

  static const _baseCaloriesSale = {
    SaleComponent.viandeRouge: 280,
    SaleComponent.volaillePoisson: 220,
    SaleComponent.feculents: 200,
    SaleComponent.legumes: 60,
  };

  static const _baseCaloriesSucre = {
    SucreComponent.fruit: 80,
    SucreComponent.patisserie: 350,
    SucreComponent.cremeGlacee: 250,
    SucreComponent.chocolat: 150, // pour une portion dessert
  };

  static const _baseCaloriesBoisson = {
    BoissonComponent.eau: 0,
    BoissonComponent.soda: 100, // par verre
    BoissonComponent.jusFruit: 110,
    BoissonComponent.alcool: 150, // moyenne pour un verre de vin/bière
  };

  static const _sizeMultipliers = {
    PortionSize.small: 0.7,
    PortionSize.normal: 1.0,
    PortionSize.large: 1.3,
  };

  static const _saleModifiers = {
    SaleModifier.sauceLegere: 80,
    SaleModifier.sauceRiche: 200,
    SaleModifier.fromage: 120,
    SaleModifier.friture: 180,
  };

  static const _sucreModifiers = {
    SucreModifier.chantilly: 100, // kcal
    SucreModifier.coulis_chocolat: 80, // kcal
  };

  static const _boissonModifiers = {
    BoissonModifier.sucre_ajoute: 20, // kcal
    BoissonModifier.lait: 30, // kcal pour un nuage de lait
  };

  // --- Fonction Principale de Calcul ---

  static FoodItem estimateMeal({
    required MealType mealType,
    required DateTime date,
    required PlatType platType,
    required Set<Enum> components,
    required Map<Enum, PortionSize> portionSizes,
    required Set<Enum> modifiers,
  }) {
    double estimatedCalories = 0;
    String description = "Repas estimé";

    switch (platType) {
      case PlatType.sale:
        description += " (Salé)";
        for (final component in components.whereType<SaleComponent>()) {
          final base = _baseCaloriesSale[component] ?? 0;
          final multiplier = _sizeMultipliers[portionSizes[component]] ?? 1.0;
          estimatedCalories += base * multiplier;
        }
        for (final modifier in modifiers.whereType<SaleModifier>()) {
          estimatedCalories += _saleModifiers[modifier] ?? 0;
        }
        break;
      case PlatType.sucre:
        description += " (Sucré)";
        for (final component in components.whereType<SucreComponent>()) {
          final base = _baseCaloriesSucre[component] ?? 0;
          final multiplier = _sizeMultipliers[portionSizes[component]] ?? 1.0;
          estimatedCalories += base * multiplier;
        }
        for (final modifier in modifiers.whereType<SucreModifier>()) {
          estimatedCalories += _sucreModifiers[modifier] ?? 0;
        }
        break;
      case PlatType.boisson:
        description += " (Boisson)";
        for (final component in components.whereType<BoissonComponent>()) {
          final base = _baseCaloriesBoisson[component] ?? 0;
          final multiplier = _sizeMultipliers[portionSizes[component]] ?? 1.0;
          estimatedCalories += base * multiplier;
        }
        for (final modifier in modifiers.whereType<BoissonModifier>()) {
          estimatedCalories += _boissonModifiers[modifier] ?? 0;
        }
        break;
    }
    
    // Calcul des macros avec un ratio standard (40% G, 30% P, 30% L)
    final carbs = (estimatedCalories * 0.40) / 4;
    final protein = (estimatedCalories * 0.30) / 4;
    final fat = (estimatedCalories * 0.30) / 9;

    return FoodItem(
      name: description,
      caloriesPer100g: estimatedCalories,
      proteinPer100g: protein,
      carbsPer100g: carbs,
      fatPer100g: fat,
      quantity: 100.0,
      mealType: mealType,
      date: date,
    );
  }
}