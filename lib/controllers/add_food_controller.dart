// lib/controllers/add_food_controller.dart
import 'dart:async';
import 'package:openfoodfacts/openfoodfacts.dart';
import '../helpers/database_helper.dart';
import '../models/food_item.dart';
import '../models/portion.dart';

enum ProductResultStatus {
  success,
  notFound,
  incompleteData,
  networkError,
  timeoutError,
}

class ProductFetchResult {
  final ProductResultStatus status;
  final FoodItem? foodItem; // Ne sera présent qu'en cas de succès

  ProductFetchResult({required this.status, this.foodItem});
}

class AddFoodController {
  final Map<String, List<Product>> _searchCache = {};

  
  // Ajoute un aliment au journal du jour
  Future<void> submitFood(FoodItem item) async {
    await DatabaseHelper.instance.createFoodLog(item);
  }

  Future<List<Portion>> getPortionsForFood(String foodName) async {
    return await DatabaseHelper.instance.getPortionsForFood(foodName);
  }

  // Ajoute un aliment aux favoris et retourne si l'opération a réussi
  Future<bool> addFoodToFavorites(FoodItem item) async {
    return await DatabaseHelper.instance.createFavorite(item);
  }

  Future<List<Product>> searchProducts(String query) async {
    // On évite de lancer une recherche si la requête est trop courte
    if (query.length < 3) {
      return []; // Retourne une liste vide
    }

    if (_searchCache.containsKey(query)) {
      return _searchCache[query]!;
    }

    // On configure les paramètres de la recherche textuelle
    final ProductSearchQueryConfiguration configuration =
        ProductSearchQueryConfiguration(
      parametersList: <Parameter>[
        // On cherche les termes fournis par l'utilisateur
        SearchTerms(terms: [query]),
        SortBy(option: SortOption.POPULARITY), 
      ],
      language: OpenFoodFactsLanguage.FRENCH,
      fields: [ProductField.ALL], // On demande tous les champs pour avoir les détails
      version: ProductQueryVersion.v3, // Ajout du paramètre requis
    );

    try {
      // On lance la recherche via le client de l'API
      final SearchResult result = await OpenFoodAPIClient.searchProducts(
        null, // Le User n'est pas nécessaire pour une simple recherche
        configuration,
      );
      
      // On retourne la liste des produits trouvés, ou une liste vide si aucun résultat
      final products =  result.products ?? [];

      products.sort((a, b) {
        final nameA = a.productName?.toLowerCase() ?? '';
        final nameB = b.productName?.toLowerCase() ?? '';
        final queryLower = query.toLowerCase();

        // Règle 1 : Priorité absolue à ceux qui commencent par la recherche
        final aStartsWith = nameA.startsWith(queryLower);
        final bStartsWith = nameB.startsWith(queryLower);
        if (aStartsWith && !bStartsWith) return -1; // a remonte
        if (!aStartsWith && bStartsWith) return 1;  // b remonte

        // Règle 2 : Pénaliser les "saveurs" et "goûts"
        final aIsFlavor = nameA.contains('goût ') || nameA.contains('saveur ');
        final bIsFlavor = nameB.contains('goût ') || nameB.contains('saveur ');
        if (!aIsFlavor && bIsFlavor) return -1; // a (qui n'est pas une saveur) remonte
        if (aIsFlavor && !bIsFlavor) return 1;  // b (qui n'est pas une saveur) remonte

        // Règle 3 : Priorité aux noms plus courts
        if (nameA.length < nameB.length) return -1;
        if (nameB.length < nameA.length) return 1;

        // Si tout est égal, on ne change rien
        return 0;
      });

      _searchCache[query] = products;
      return products;

    } catch (e) {
      print("Erreur pendant la recherche de produits : $e");
      return []; // En cas d'erreur (réseau, etc.), on retourne une liste vide
    }
  }

  
  // Récupère les données d'un produit via son code-barres
  Future<ProductFetchResult> fetchProductFromBarcode(String barcode) async {
    final config = ProductQueryConfiguration(
      barcode,
      version: ProductQueryVersion.v3,
      language: OpenFoodFactsLanguage.FRENCH,
    );

    try {
      final result = await OpenFoodAPIClient.getProductV3(config);

      // Cas 1 : Le produit n'a pas été trouvé du tout
      if (result.product == null) {
        return ProductFetchResult(status: ProductResultStatus.notFound);
      }

      final product = result.product!;
      
      // Cas 2 : Le produit a été trouvé, mais il manque des données essentielles
      final calories = product.nutriments?.getValue(Nutrient.energyKCal, PerSize.oneHundredGrams);
      if (calories == null) {
        return ProductFetchResult(status: ProductResultStatus.incompleteData);
      }
      
      // Cas 3 : Succès ! Le produit est trouvé et valide.
      // On fait la conversion en FoodItem ICI, dans le controller.
      final foodItem = FoodItem(
        name: product.productName ?? 'Produit inconnu',
        caloriesPer100g: calories,
        proteinPer100g: product.nutriments?.getValue(Nutrient.proteins, PerSize.oneHundredGrams) ?? 0.0,
        carbsPer100g: product.nutriments?.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams) ?? 0.0,
        fatPer100g: product.nutriments?.getValue(Nutrient.fat, PerSize.oneHundredGrams) ?? 0.0,
        quantity: 100,
      );
      
      return ProductFetchResult(status: ProductResultStatus.success, foodItem: foodItem);

    } on TimeoutException { // <-- ON ATTRAPE SPÉCIFIQUEMENT L'ERREUR DE TIMEOUT
      print("Erreur : Timeout de la requête API après 10 secondes.");
      return ProductFetchResult(status: ProductResultStatus.timeoutError);

    } catch (e) {
      // Cas 4 : Une erreur réseau ou autre s'est produite
      print("Erreur réseau ou API : $e");
      return ProductFetchResult(status: ProductResultStatus.networkError);
    }
  }
}