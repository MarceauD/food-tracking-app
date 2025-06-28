// lib/helpers/database_helper.dart

import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/food_item.dart';

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
      quantity $realType NOT NULL,
      date TEXT
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

  Future<FoodItem> createFavorite(FoodItem item) async {
    final db = await instance.database;

    final existing = await db.query(
      'favorites',
      where: 'name = ?',
      whereArgs: [item.name],
      limit: 1, // Pas besoin de chercher plus loin qu'une seule correspondance
    );

    if (existing.isEmpty) {
      await db.insert('favorites', item.toMap());
    }
    
    return item;
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

  Future close() async {
    final db = await instance.database;
    db.close();
  }
}