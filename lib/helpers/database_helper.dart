// lib/helpers/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food_item.dart';
import '../models/saved_meals.dart';

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

    return await openDatabase(path, version: 1, onCreate: _createDB);
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
  }

  // --- Opérations sur le Journal ---

  Future<FoodItem> createFoodLog(FoodItem item) async {
    final db = await instance.database;
    final id = await db.insert('food_log', item.toMap());

    return item.copyWith(); // On pourrait retourner avec l'ID mais pas essentiel ici
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

  Future<int> clearFoodLog() async {
      final db = await instance.database;
      return await db.delete('food_log');
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