import 'package:flutter/material.dart';
import '/screens/home_screen.dart';
import 'package:openfoodfacts/openfoodfacts.dart';
import 'package:intl/date_symbol_data_local.dart'; 

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
      ),
      home: const HomeScreen(), // L'écran principal est HomeScreen
    );
  }
}
