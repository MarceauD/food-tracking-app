import 'package:flutter/material.dart';
import '/screens/home_screen.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart'; // <-- Importer notre nouvelle classe

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

  runApp(
    ChangeNotifierProvider(
      create: (context) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      title: 'Mon Suivi Nutritionnel',
      themeMode: themeProvider.themeMode,

      theme: ThemeData(
        
        useMaterial3: true,

        scaffoldBackgroundColor: const Color(0xFFF8F9FA), // Un gris très clair et neutre

        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          primary: Colors.green.shade600, // Un vert un peu plus soutenu pour les accents
          surface: const Color(0xFFF8F9FA),
          background: const Color(0xFFF8F9FA), // Le même que le scaffold
        ),

        // Un thème personnalisé pour toutes les cartes de l'application
        cardTheme: CardThemeData(
          elevation: 1.5, // Une ombre très subtile pour un effet de flottement
          shadowColor: Colors.black.withOpacity(0.08), // Une ombre douce
          surfaceTintColor: Colors.white, // Très important pour garder les cartes blanches en Material 3
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0))
        ),
            
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).copyWith(
          // Style pour les grands titres (ex: "Bonjour !")
          headlineSmall: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: const Color(0xFF343A40), // Un noir/gris très foncé
          ),
          // Style pour les titres de section ou de carte
          titleLarge: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600, // Semi-gras
            color: const Color(0xFF343A40),
          ),
          // Style pour le corps de texte normal
          bodyMedium: GoogleFonts.poppins(
            fontSize: 14,
            color: Colors.grey[800],
          ),
          // Style pour les textes secondaires ou les sous-titres
          bodySmall: GoogleFonts.poppins(
            fontSize: 12,
            color: Colors.grey[600],
          ),
        ),

        inputDecorationTheme: InputDecorationTheme(
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: Colors.grey.shade300),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12.0),
            borderSide: BorderSide(color: const Color(0xFF43A047), width: 2.0),
          ),
          filled: true,
          fillColor: Colors.white,
        ),

      ),

      darkTheme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: const Color(0xFF121212), // Un noir très foncé
        colorScheme: ColorScheme.fromSeed(
          seedColor: Colors.green,
          brightness: Brightness.dark, // On spécifie que c'est un thème sombre
          surface: const Color(0xFF1E1E1E), // Des cartes légèrement plus claires
        ),
        // Le thème de texte s'adaptera automatiquement (texte blanc sur fond sombre)
        textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
        cardTheme: CardThemeData(
          elevation: 1.0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        ),
        ),

      home: const HomeScreen(), // L'écran principal est HomeScreen
    );
  }
}
