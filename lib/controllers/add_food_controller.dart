// lib/controllers/add_food_controller.dart
import 'dart:async';
import 'package:openfoodfacts/openfoodfacts.dart';
import '../helpers/database_helper.dart';
import '../models/food_item.dart';
import '../models/portion.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:translator/translator.dart';

enum ProductResultStatus {
  success,
  notFound,
  incompleteData,
  networkError,
  timeoutError,
}

class ProductFetchResult {
  final ProductResultStatus status;
  final FoodItem? foodItem;


  ProductFetchResult({required this.status, this.foodItem});
}

class AddFoodController {
  final Map<String, List<Product>> _searchCache = {};
  final _translator = GoogleTranslator();
  final searchLimit = 10;
  
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
      if (products.length > searchLimit) {
          return products.sublist(0, searchLimit);
        }
        return products;
    } catch (e) {
      print("Erreur pendant la recherche de produits : $e");
      return []; // En cas d'erreur (réseau, etc.), on retourne une liste vide
    }
  }
  
  Future<List<Portion>> findAvailablePortions(String foodName, {Product? originalProduct}) async {
    List<Portion> portions = [];

    // Priorité 1: Portions personnalisées de l'utilisateur
    portions = await DatabaseHelper.instance.getUserPortionsForFood(foodName ?? '');

    // Priorité 2: Portion de l'API (si un produit original est fourni)
    if (portions.isEmpty && originalProduct != null) {
      final String? servingSizeFromApi = originalProduct.servingSize;
      if (servingSizeFromApi != null && servingSizeFromApi.isNotEmpty) {
        final RegExp regex = RegExp(r'(\d+(\.\d+)?)');
        final Match? match = regex.firstMatch(servingSizeFromApi);
        if (match != null) {
          final double? weight = double.tryParse(match.group(1)!);
          if (weight != null) {
            portions.add(Portion(name: '1 portion ($servingSizeFromApi)', weightInGrams: weight));
          }
        }
      }
    }

    // Priorité 3: Recherche dans notre base de données générique
    if (portions.isEmpty) {
      portions = await DatabaseHelper.instance.getPortionsForFood(foodName ?? '');
    }

    // Priorité 4: Portion par défaut si toujours rien
    if (portions.isEmpty) {
      portions.add(Portion(name: 'Portion (100g)', weightInGrams: 100.0));
    }

    return portions;
  }


  Future<void> saveUserPortion(String foodName, String portionName, double weight) async {
    await DatabaseHelper.instance.saveUserPortion(foodName, portionName, weight);
  }
  

  Future<List<FoodItem>> searchGenericFoods(String query) async {
    const apiKey = 'NxszZVLpHF5cLXoo1dLgcPHX25WLx5XZtsJgF2UO'; 
    
    final translation = await _translator.translate(query, from: 'fr', to: 'en');
    final englishQuery = translation.text;

    // On construit l'URL de la requête
    final url = Uri.parse(
      'https://api.nal.usda.gov/fdc/v1/foods/search?api_key=$apiKey&query=${Uri.encodeComponent(englishQuery)}&dataType=Foundation,SR%20Legacy'
    );

    try {
      
      final response = await http.get(
      url,
      headers: {
        'User-Agent': 'MonSuiviNutritionnel/1.0.0', // Vous pouvez mettre le nom de votre app
      },
    ).timeout(const Duration(seconds: 10));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List foodsData = data['foods'] ?? [];

        final List<Future<FoodItem?>> translationTasks = foodsData.map((foodData) async {
        final englishName = foodData['description'] as String? ?? 'Inconnu';
        
        // On traduit le nom du produit en français
        final translatedName = await _translator.translate(englishName, from: 'en', to: 'fr');

        final List nutrients = foodData['foodNutrients'] ?? [];
        double getNutrientValue(int id) => (nutrients.firstWhere((n) => n['nutrientId'] == id, orElse: () => {'value': 0.0})['value'] as num).toDouble();
        
        final calories = getNutrientValue(1008);
        if (calories <= 0) return null; // On ignore les aliments sans calories
        return FoodItem(
          name: translatedName.text, // On utilise le nom traduit
          caloriesPer100g: calories,
          proteinPer100g: getNutrientValue(1003),
          carbsPer100g: getNutrientValue(1005),
          fatPer100g: getNutrientValue(1004),
          quantity: 100.0,
        );
      }).toList();

      final initialResults = await Future.wait(translationTasks);
      final validItems = initialResults.whereType<FoodItem>().toList();
      final queryLower = query.toLowerCase();

      var validResults = validItems.where((item) {
          final nameLower = item.name?.toLowerCase() ?? '';
         
          if (!nameLower.startsWith(queryLower)) return false;
          
          final excludedWords = ['babyfood', 'juice', 'dessert', 'pie', 'sauce', 'strudel'];
          if (excludedWords.any((word) => nameLower.contains(word))) return false;
          
          return true;
        }).toList();


        validResults.sort((a, b) {
          final nameA = a.name?.toLowerCase() ?? '';
          final nameB = b.name?.toLowerCase() ?? '';
          // Important : on trie sur le terme anglais envoyé à l'API
          final queryLower = englishQuery.toLowerCase(); 

          // Règle 1 : Priorité à ce qui commence par la recherche
          final aStartsWith = nameA.startsWith(queryLower);
          final bStartsWith = nameB.startsWith(queryLower);
          if (aStartsWith && !bStartsWith) return -1; // a est meilleur
          if (!aStartsWith && bStartsWith) return 1;  // b est meilleur

          // Règle 2 : Priorité aux noms plus courts (moins de mots)
          final wordCountA = nameA.split(' ').length;
          final wordCountB = nameB.split(' ').length;
          if (wordCountA < wordCountB) return -1; // a est meilleur
          if (wordCountB < wordCountA) return 1;  // b est meilleur

          // Si tout est égal, on ne change pas l'ordre
          return 0;
        });
      
        if (validResults.length > searchLimit) {
          return validResults.sublist(0, searchLimit);
        }
        return validResults;

      } else {
        print("Erreur de l'API USDA : ${response.statusCode} - ${response.body}");
        return [];
      }
    } catch (e) {
      print("Erreur réseau lors de la recherche USDA : $e");
      return [];
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