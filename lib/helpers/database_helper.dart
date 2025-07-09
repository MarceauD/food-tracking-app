// lib/helpers/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food_item.dart';
import '../models/saved_meals.dart';
import '../models/portion.dart';
import '../models/daily_summary.dart';
import '../models/user_profile.dart'; // N'oubliez pas l'import

class DatabaseHelper {
  // Singleton pour s'assurer qu'on a une seule instance de la BDD
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;
  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('nutrition.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 6, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  
  }

  // Création des tables
  Future _createDB(Database db, int version) async {

    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';

    // Table pour le journal quotidien
    await db.execute('''
    CREATE TABLE food_log (
      id $idType,
      name TEXT,
      mealType TEXT,
      caloriesPer100g $realType,
      proteinPer100g $realType,
      carbsPer100g $realType,
      fatPer100g $realType,
      quantity $realType,
      date TEXT NOT NULL
    )
    ''');

    // Table pour les favoris
    await db.execute('''
    CREATE TABLE favorites (
      id $idType,
      name TEXT,
      caloriesPer100g $realType,
      proteinPer100g $realType,
      carbsPer100g $realType,
      fatPer100g $realType,
      quantity $realType,
      date TEXT
    )
    ''');

    await db.execute('''
    CREATE TABLE saved_meals (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE saved_meal_items (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      saved_meal_id INTEGER NOT NULL,
      name TEXT,
      caloriesPer100g REAL NOT NULL,
      proteinPer100g REAL NOT NULL,
      carbsPer100g REAL NOT NULL,
      fatPer100g REAL NOT NULL,
      quantity REAL NOT NULL,
      FOREIGN KEY (saved_meal_id) REFERENCES saved_meals (id) ON DELETE CASCADE
    )
    ''');

    await db.execute('''
    CREATE TABLE common_portions (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      food_keyword TEXT NOT NULL,
      portion_name TEXT NOT NULL,
      weight_in_grams REAL NOT NULL
    )
    ''');

    await db.execute('''
    CREATE TABLE daily_summary (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      date TEXT UNIQUE,
      total_calories REAL NOT NULL,
      total_carbs REAL NOT NULL,
      total_protein REAL NOT NULL,
      total_fat REAL NOT NULL,
      goal_calories REAL NOT NULL,
      logged_meals TEXT, -- Cette colonne existe déjà
      -- ON AJOUTE LES NOUVELLES COLONNES
      breakfast_calories REAL NOT NULL,
      lunch_calories REAL NOT NULL,
      dinner_calories REAL NOT NULL,
      snack_calories REAL NOT NULL
    )
    ''');

    await db.execute('''
        CREATE TABLE user_profile (
          id INTEGER PRIMARY KEY,
          gender TEXT NOT NULL,
          date_of_birth TEXT NOT NULL,
          height REAL NOT NULL,
          weight REAL NOT NULL,
          activity_level TEXT NOT NULL,
          objective TEXT NOT NULL DEFAULT 'maintain',
          name TEXT NOT NULL DEFAULT 'Utilisateur'
        )
      ''');

    await db.execute('''
   INSERT INTO common_portions (food_keyword, portion_name, weight_in_grams) VALUES
    -- FRUITS
    ('oeuf', '1 oeuf moyen (50g)', 50),
    ('oeuf', '1 jaune (20g)', 20),
    ('oeuf', '1 blanc (30g)', 30),
    ('pomme', '1 petite (100g)', 100),
    ('pomme', '1 moyenne (150g)', 150),
    ('banane', '1 petite (90g)', 90),
    ('banane', '1 moyenne (120g)', 120),
    ('orange', '1 orange (150g)', 150),
    ('clémentine', '1 clémentine (50g)', 50),
    ('fraise', '1 poignée (100g)', 100),
    ('framboise', '1 poignée (100g)', 70),
    ('kiwi', '1 kiwi (75g)', 75),
    ('avocat', '1/2 avocat (70g)', 70),
    
    -- FÉCULENTS
    ('pain', '1 tranche (25g)', 25),
    ('pain', '1 tranche (40g)', 40),
    ('pain', '1 baguette (250g)', 250),
    ('riz', '1 portion cuit (150g)', 150),
    ('pâtes', '1 portion cuites (180g)', 180),
    ('semoule', '1 portion (cuite)', 150),
    ('pomme de terre', '1 petite (80g)', 80),
    ('pomme de terre', '1 moyenne (120g)', 120),
    ('flocons d''avoine', '1 bol (40g)', 40),
    ('lentilles', '1 portion cuites (200g)', 200),
    
    -- LÉGUMES
    ('tomate', '1 tomate (120g)', 120),
    ('tomate', '1 tomate cerise (10g)', 10),
    ('carotte', '1 carotte (100g)', 100),
    ('courgette', '1/2 courgette (125g)', 125),
    ('oignon', '1 oignon (100g)', 100),
    ('ail', '1 gousse (5g)', 5),
    ('salade', '1 bol (50g)', 50),
    
    -- VIANDES & POISSONS
    ('poulet', '1 filet (120g)', 120),
    ('poulet', '1 cuisse (150g)', 150),
    ('jambon', '1 tranche (45g)', 45),
    ('lardons', '1 portion (75g)', 75),
    ('steak', '1 steak haché (100g)', 100),
    ('saumon', '1 pavé (130g)', 130),
    ('thon', '1 petite boîte (90g)', 90),
    
    -- PRODUITS LAITIERS
    ('lait', '1 verre (200mL)', 200),
    ('lait', '1 bol (250 mL)', 250),
    ('yaourt', '1 pot (125g)', 125),
    ('fromage blanc', '1 portion (100g)', 100),
    ('camembert', '1 tranche (30g)', 30),
    ('fromage', '1 tranche (30g)', 30),
    ('parmesan', '1 c. à soupe (10g)', 10),
    
    -- SUCRES, GRAS & AUTRES
    ('sucre', '1 morceau (5g)', 5),
    ('sucre', '1 c. à café (5g)', 5),
    ('huile', '1 c. à soupe (10g)', 10),
    ('beurre', '1 noisette (10g)', 10),
    ('confiture', '1 c. à café (15g)', 15),
    ('miel', '1 c. à café (10g)', 10),
    ('chocolat', '1 carré (10g)', 10),
    ('amandes', '1 poignée (25g)', 25),
    ('noix', '1 poignée (25g)', 25)
    ''');

    await db.execute('''
      CREATE TABLE user_portions (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        food_name TEXT NOT NULL,
        portion_name TEXT NOT NULL,
        weight_in_grams REAL NOT NULL
      )
    ''');
  }

  Future<void> saveUserPortion(String foodName, String portionName, double weight) async {
    final db = await instance.database;
    await db.insert(
      'user_portions',
      {
        'food_name': foodName.toLowerCase(),
        'portion_name': portionName,
        'weight_in_grams': weight,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<Portion>> getUserPortionsForFood(String foodName) async {
    final db = await instance.database;
    final res = await db.query(
      'user_portions',
      where: 'food_name = ?',
      whereArgs: [foodName.toLowerCase()],
    );

    return res.isNotEmpty
        ? res.map((json) => Portion.fromJson(json)).toList()
        : [];
  }

  // Sauvegarde ou met à jour le profil de l'utilisateur (il n'y en a qu'un)
  Future<void> saveOrUpdateUserProfile(UserProfile profile) async {
    final db = await instance.database;
    await db.insert(
      'user_profile',
      profile.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace, // Remplace la ligne existante si l'ID est le même
    );
  }

  // Récupère le profil de l'utilisateur
  Future<UserProfile?> getUserProfile() async {
    final db = await instance.database;
    final maps = await db.query(
      'user_profile',
      where: 'id = ?',
      whereArgs: [1], // L'ID du profil est toujours 1
    );

    if (maps.isNotEmpty) {
      return UserProfile.fromMap(maps.first);
    }
    return null; // Retourne null si aucun profil n'a encore été créé
  }

  // --- Opérations sur le Journal ---

  Future<FoodItem> createFoodLog(FoodItem item) async {
    final db = await instance.database;
    final id = await db.insert('food_log', item.toMap());

    return item.copyWith(); // On pourrait retourner avec l'ID mais pas essentiel ici
  }

  // Vide toute la table des favoris
  Future<void> clearFavorites() async {
    final db = await instance.database;
    await db.delete('favorites');
    print('🗑️ Table des favoris vidée.');
  }

  // Vide toute la table des repas sauvegardés (et les items associés par cascade)
  Future<void> clearSavedMeals() async {
    final db = await instance.database;
    await db.delete('saved_meals');
    print('🗑️ Table des repas sauvegardés vidée.');
  }

  Future<List<FoodItem>> getFoodLogForDate(DateTime date) async {
    final db = await instance.database;
    final dateString = date.toIso8601String().substring(0, 10);

    final maps = await db.query(
      'food_log',
      where: 'date LIKE ?', 
      whereArgs: ['$dateString%'], // On utilise 'LIKE' pour matcher toutes les entrées de ce jour
      orderBy: 'id DESC',
      // Pour matcher tous les items
    );

    if (maps.isNotEmpty) {
      return maps.map((json) => FoodItem.fromMap(json)).toList();
    } else {
      return [];
    }
  }

  
  Future<int> deleteFoodLog(int id) async {
    final db = await instance.database;
    return await db.delete('food_log', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> clearFoodLog() async {
      final db = await instance.database;
      return await db.delete('food_log');
  }

  Future<int> updateFoodLogQuantity(int id, double newQuantity) async {
    final db = await instance.database;
    return await db.update(
      'food_log',
      {'quantity': newQuantity},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  // Sauvegarde ou met à jour le résumé du jour (logique "Upsert")
  Future<void> saveOrUpdateSummary(DailySummary summary) async {
    final db = await instance.database;
    await db.insert(
      'daily_summary',
      summary.toMap(),
      // Si une entrée pour cette date existe déjà, on la remplace.
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  // Récupère les résumés des X derniers jours
  Future<List<DailySummary>> getRecentSummaries(int days) async {
    final db = await instance.database;
    final maps = await db.query(
      'daily_summary',
      orderBy: 'date DESC',
      limit: days,
    );
    return maps.map((map) => DailySummary.fromMap(map)).toList();
  }

  Future<void> clearSummaries() async {
    final db = await instance.database;
    await db.delete('daily_summary');
    print('🗑️ Table des résumés journaliers vidée.');
  }

  // --- Opérations sur les Favoris ---

  Future<bool> createFavorite(FoodItem item) async {
    final db = await instance.database;

    final existing = await db.query(
      'favorites',
      where: 'name = ?',
      whereArgs: [item.name],
      limit: 1, // Pas besoin de chercher plus loin qu'une seule correspondance
    );

    if (existing.isEmpty) {
      final Map<String, dynamic> favoriteMap = {
        'name': item.name,
        'caloriesPer100g': item.caloriesPer100g,
        'proteinPer100g': item.proteinPer100g,
        'carbsPer100g': item.carbsPer100g,
        'fatPer100g': item.fatPer100g,
        'quantity': item.quantity,
      };

      await db.insert('favorites', favoriteMap);
      return true;
   } else {
    return false;
   }
  }

  Future<int> deleteFavorite(int id) async {
    final db = await instance.database;
    
    return await db.delete(
      'favorites',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<FoodItem>> getFavorites() async {
    final db = await instance.database;
    final maps = await db.query('favorites', orderBy: 'name ASC');

    if (maps.isNotEmpty) {
      return maps.map((json) => FoodItem.fromMap(json)).toList();
    } else {
      return [];
    }
  }

  Future<List<Portion>> getPortionsForFood(String foodName) async {
  final db = await instance.database;
  
  // 1. Nettoyage initial de la chaîne de recherche
  final cleanedName = foodName.toLowerCase().replaceAll(RegExp(r'[,]'), '');

  // 2. Extraction et normalisation des mots-clés
  final keywords = cleanedName.split(' ').map((word) {
    // Si le mot se termine par 's' et a plus de 3 lettres, on retire le 's'
    if (word.endsWith('s') && word.length > 3) {
      return word.substring(0, word.length - 1);
    }
    return word;
  }).toSet().toList(); // .toSet().toList() pour supprimer les doublons

  if (keywords.isEmpty) {
    return [];
  }

  // 3. On construit une requête SQL dynamique
  // Elle va chercher les portions dont le mot-clé est DANS notre liste de mots-clés
  final placeholders = List.generate(keywords.length, (_) => '?').join(',');
  final whereClause = 'food_keyword IN ($placeholders)';

  final res = await db.query(
    'common_portions',
    where: whereClause,
    whereArgs: keywords, // On passe notre liste de mots-clés normalisés
  );

  // 4. On utilise un Set pour s'assurer que chaque portion est unique
  final Set<String> uniquePortionNames = {};
  final List<Portion> uniquePortions = [];

  for (var json in res) {
    final portionName = json['portion_name'] as String;
    if (uniquePortionNames.add(portionName)) { // .add() retourne true si l'élément est nouveau
      uniquePortions.add(Portion(
        name: portionName,
        weightInGrams: json['weight_in_grams'] as double,
      ));
    }
  }

  return uniquePortions;
}

  //opérations sur les repas sauvegardés
  Future<void> saveMeal(String name, List<FoodItem> items) async {
    final db = await instance.database;

    // Utilise une transaction pour s'assurer que toutes les opérations réussissent ou échouent ensemble
    await db.transaction((txn) async {
      // 1. Insère le nom du repas et récupère son nouvel ID
      final mealId = await txn.insert('saved_meals', {'name': name});

      // 2. Pour chaque aliment du repas, on l'insère dans la table des items
      for (final item in items) {
        final itemMap = {
          'saved_meal_id': mealId,
          'name': item.name,
          'caloriesPer100g': item.caloriesPer100g,
          'proteinPer100g': item.proteinPer100g,
          'carbsPer100g': item.carbsPer100g,
          'fatPer100g': item.fatPer100g,
          'quantity': item.quantity,
        };
        await txn.insert('saved_meal_items', itemMap);
      }
    });
    print('✅ Repas "$name" sauvegardé avec ${items.length} aliments.');
  }

  Future<List<SavedMeal>> getSavedMeals() async {
    final db = await instance.database;
    final List<SavedMeal> savedMeals = [];

    // 1. Récupère tous les repas sauvegardés (juste leur nom et ID)
    final mealsMaps = await db.query('saved_meals');

    // 2. Pour chaque repas, on va chercher les aliments qui lui sont associés
    for (final mealMap in mealsMaps) {
      final mealId = mealMap['id'] as int;
      final mealName = mealMap['name'] as String;

      final itemsMaps = await db.query(
        'saved_meal_items',
        where: 'saved_meal_id = ?',
        whereArgs: [mealId],
      );

      final List<FoodItem> items = itemsMaps.map((itemMap) {
        // On doit recréer un FoodItem. Comme on n'a pas tous les champs,
        // on peut utiliser des valeurs par défaut ou null.
        return FoodItem.fromMap(itemMap);
      }).toList();

      savedMeals.add(SavedMeal(id: mealId, name: mealName, items: items));
    }
    return savedMeals;
  }

  Future<int> deleteSavedMeal(int id) async {
    final db = await instance.database;
    print('🗑️ Suppression du repas sauvegardé avec id: $id');
    
    // Grâce à "ON DELETE CASCADE", supprimer ceci supprimera aussi tous les
    // 'saved_meal_items' associés.
    return await db.delete(
      'saved_meals',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}