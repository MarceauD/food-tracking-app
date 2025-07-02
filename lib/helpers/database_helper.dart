// lib/helpers/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food_item.dart';
import '../models/saved_meals.dart';
import '../models/portion.dart';
import '../models/daily_summary.dart';

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
      version: 4, 
      onCreate: _createDB,
      onUpgrade: _upgradeDB, // <-- On ajoute cette ligne
    );
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
  // Pour cette mise à jour simple, nous allons supprimer les anciennes tables
  // et les recréer. ATTENTION : ceci efface toutes les données existantes.
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
      goal_calories REAL NOT NULL
    )
    ''');

    await db.execute('''
   INSERT INTO common_portions (food_keyword, portion_name, weight_in_grams) VALUES
    -- FRUITS
    ('oeuf', '1 oeuf moyen', 50),
    ('oeuf', '1 jaune', 20),
    ('oeuf', '1 blanc', 30),
    ('pomme', '1 petite', 100),
    ('pomme', '1 moyenne', 150),
    ('banane', '1 petite', 90),
    ('banane', '1 moyenne', 120),
    ('orange', '1 orange', 150),
    ('clémentine', '1 clémentine', 50),
    ('fraise', '1 poignée', 100),
    ('framboise', '1 poignée', 70),
    ('kiwi', '1 kiwi', 75),
    ('avocat', '1/2 avocat', 70),
    
    -- FÉCULENTS
    ('pain', '1 tranche (mie)', 25),
    ('pain', '1 tranche (complet)', 40),
    ('pain', '1 baguette', 250),
    ('riz', '1 portion (cuit)', 150),
    ('pâtes', '1 portion (cuites)', 180),
    ('semoule', '1 portion (cuite)', 150),
    ('pomme de terre', '1 petite', 80),
    ('pomme de terre', '1 moyenne', 120),
    ('flocons d''avoine', '1 bol', 40),
    ('lentilles', '1 portion (cuites)', 200),
    
    -- LÉGUMES
    ('tomate', '1 tomate', 120),
    ('tomate', '1 tomate cerise', 10),
    ('carotte', '1 carotte', 100),
    ('courgette', '1/2 courgette', 125),
    ('oignon', '1 oignon', 100),
    ('ail', '1 gousse', 5),
    ('salade', '1 bol', 50),
    
    -- VIANDES & POISSONS
    ('poulet', '1 filet', 120),
    ('poulet', '1 cuisse', 150),
    ('jambon', '1 tranche', 45),
    ('lardons', '1 portion', 75),
    ('steak', '1 steak haché', 100),
    ('saumon', '1 pavé', 130),
    ('thon', '1 petite boîte', 90),
    
    -- PRODUITS LAITIERS
    ('lait', '1 verre', 200),
    ('lait', '1 bol', 250),
    ('yaourt', '1 pot', 125),
    ('fromage blanc', '1 portion', 100),
    ('camembert', '1/8 de part', 30),
    ('fromage', '1 tranche', 30),
    ('parmesan', '1 c. à soupe', 10),
    
    -- SUCRES, GRAS & AUTRES
    ('sucre', '1 morceau', 5),
    ('sucre', '1 c. à café', 5),
    ('huile', '1 c. à soupe', 10),
    ('beurre', '1 noisette', 10),
    ('confiture', '1 c. à café', 15),
    ('miel', '1 c. à café', 10),
    ('chocolat', '1 carré', 10),
    ('amandes', '1 poignée', 25),
    ('noix', '1 poignée', 25)
    ''');
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

    final maps = await db.query(
      'food_log',
      // Pour matcher tous les items
      orderBy: 'id DESC',
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
    final lowerFoodName = foodName.toLowerCase();

    // Cette recherche est simple mais efficace pour commencer
    final res = await db.query(
      'common_portions',
      where: 'food_keyword IN (SELECT value FROM json_each(?) WHERE value LIKE ?)',
      whereArgs: [
        '["${lowerFoodName.split(' ').join('","')}"]',
        '%${lowerFoodName.split(' ').first}%'
      ],
    );

    if (res.isNotEmpty) {
      return res.map((json) => Portion(
        name: json['portion_name'] as String,
        weightInGrams: json['weight_in_grams'] as double,
      )).toList();
    }
    return [];
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