import 'package:flutter/material.dart';
import '/screens/home_screen.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:google_fonts/google_fonts.dart';

Future<void> deleteDb() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'nutrition.db');
  await deleteDatabase(path);
}

void main() async {
  OpenFoodAPIConfiguration.userAgent = UserAgent(
    name:'MonSuiviNutritionnel', // Nom de votre application
    version:'0.1',
  );

  WidgetsFlutterBinding.ensureInitialized(); 
  await initializeDateFormatting('fr_FR', null);

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mon Suivi Nutritionnel',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.green),
        useMaterial3: true,

        textTheme: GoogleFonts.poppinsTextTheme(Theme.of(context).textTheme),

        // Un fond global un peu plus doux que le blanc pur
        scaffoldBackgroundColor: const Color(0xFFF7F9F9),

        // Un thème personnalisé pour toutes les cartes de l'application
        cardTheme: CardThemeData(
          elevation: 2.0, // Une ombre plus subtile
          // On donne une couleur verte à l'ombre, la rendant beaucoup plus douce
          shadowColor: Colors.green.withOpacity(0.2), 
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        ),
        
      ),
      home: const HomeScreen(), // L'écran principal est HomeScreen
    );
  }
}
