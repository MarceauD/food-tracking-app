import 'package:flutter/material.dart';
import '/screens/home_screen.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:intl/date_symbol_data_local.dart'; 
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'providers/theme_provider.dart';
import 'widgets/common/notification_service.dart'; 
import 'package:flutter_localizations/flutter_localizations.dart';// <-- Importer notre nouvelle classe
import 'package:shared_preferences/shared_preferences.dart';
import 'controllers/home_controller.dart';

Future<void> deleteDb() async {
  final dbPath = await getDatabasesPath();
  final path = join(dbPath, 'nutrition.db');
  await deleteDatabase(path);
}

Future<void> main() async {
  // 1. On s'assure que tout est initialisé avant de continuer
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. On crée UNE SEULE instance de notre service de notifications
  final NotificationService notificationService = NotificationService();

  // 3. On initialise le service et on demande les permissions
  await notificationService.init();
  await notificationService.requestPermissions();
  
  // 4. On programme les rappels
  await notificationService.scheduleDailyMorningReminder();
  // Vous ajouterez ici l'appel pour la notification hebdomadaire plus tard

  // Le reste de votre logique d'initialisation ne change pas
  final prefs = await SharedPreferences.getInstance();
  final String savedThemeName = prefs.getString('theme_mode') ?? ThemeMode.light.name;
  final ThemeMode initialThemeMode = ThemeMode.values.firstWhere(
    (e) => e.name == savedThemeName,
    orElse: () => ThemeMode.light, // Sécurité supplémentaire
  );
  
  await initializeDateFormatting('fr_FR', null);
  OpenFoodAPIConfiguration.userAgent = UserAgent(
    name: 'MonSuiviNutritionnel',
    version: '1.0.0',
  );

  // 5. On lance l'application
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => ThemeProvider(initialThemeMode)),
        ChangeNotifierProvider(create: (context) => HomeController()),
      ],
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
      scaffoldBackgroundColor: const Color(0xFFF8F9FA),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        // CORRECTION 1 : Il faut spécifier la luminosité pour chaque thème
        brightness: Brightness.light, 
        primary: Colors.green.shade600,
        // CORRECTION 2 : La couleur de surface (des cartes) doit être blanche
        surface: Colors.white, 
        background: const Color(0xFFF8F9FA),
      ),
      // CORRECTION 3 : Le nom de la classe est CardThemeData, pas CardTheme
      cardTheme: CardThemeData(
        elevation: 1.5,
        shadowColor: Colors.black.withOpacity(0.08),
        surfaceTintColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
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
      brightness: Brightness.dark, // La luminosité est bien définie ici
      scaffoldBackgroundColor: const Color(0xFF121212),
      colorScheme: ColorScheme.fromSeed(
        seedColor: Colors.green,
        brightness: Brightness.dark,
        primary: Colors.green.shade400,
        surface: const Color(0xFF1E1E1E), // Surface pour les cartes sombres
      ),
      // CORRECTION 3 : Le nom de la classe est CardThemeData
      cardTheme: CardThemeData(
        elevation: 1.0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      ),
      // AMÉLIORATION : On s'assure que le texte par défaut est bien lisible
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme).copyWith(
        headlineSmall: GoogleFonts.poppins(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
          // Style pour les titres de section ou de carte
          titleLarge: GoogleFonts.poppins(
            fontSize: 18,
            fontWeight: FontWeight.w600, // Semi-gras
          ),
          // Style pour le corps de texte normal
          bodyMedium: GoogleFonts.poppins(
            fontSize: 14,
          ),
          // Style pour les textes secondaires ou les sous-titres
          bodySmall: GoogleFonts.poppins(
            fontSize: 12,
          ),
      ).apply(
        bodyColor: Colors.white.withOpacity(0.87),
        displayColor: Colors.white,
      ),
    ),
      
        
      locale: const Locale('fr'), // On définit le français comme langue par défaut

      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: const [
        Locale('fr'), // Français
        Locale('en'), // Anglais (comme langue de secours)
      ],
      home: const HomeScreen(), // L'écran principal est HomeScreen
    );
  }
}
