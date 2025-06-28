import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/food_item.dart';
import 'add_food_screen.dart';
import 'settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart'; // Importer le helper


class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FoodItem> foodItems = [];
  List<FoodItem> _favoriteFoods = [];

  // Valeurs max en dur
  double goalCalories = 1700;
  double goalProtein = 160;
  double goalCarbs = 150;
  double goalFat = 60;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  Future<void> _refreshData() async {
    await _loadGoals();
    await _loadFavoriteFoodsFromDb();
    await _loadFoodLogFromDb();
  }

  Future<void> _loadFavoriteFoodsFromDb() async {
    final favorites = await DatabaseHelper.instance.getFavorites();
    setState(() {
      _favoriteFoods = favorites;
    });
  }

  Future<void> _loadFoodLogFromDb() async {
    final log = await DatabaseHelper.instance.getFoodLogForDate(DateTime.now());
    setState(() {
      foodItems = log;
    });
  }
  
  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      goalCalories = prefs.getDouble('goalCalories') ?? 1700;
      goalCarbs = prefs.getDouble('goalCarbs') ?? 150;
      goalProtein = prefs.getDouble('goalProtein') ?? 160;
      goalFat = prefs.getDouble('goalFat') ?? 60;
    });
  }

  // Totaux calculés
  double get totalCalories =>
      foodItems.fold(0, (sum, item) => sum + item.totalCalories);
  double get totalProtein =>
      foodItems.fold(0, (sum, item) => sum + item.totalProtein);
  double get totalCarbs =>
      foodItems.fold(0, (sum, item) => sum + item.totalCarbs);
  double get totalFat =>
      foodItems.fold(0, (sum, item) => sum + item.totalFat);

  

  // Fonction de formatage des nombres pour affichage
  String formatDouble(double value) => value.toStringAsFixed(0);


  void _addFavoriteToToday (FoodItem item) async {
      await DatabaseHelper.instance.createFoodLog(item);
      _loadFoodLogFromDb();
  }

  void _clearFoodItems() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Supprimer tous les aliments consommés ?'),
        actions: [
          TextButton(
            onPressed: () async {
              await DatabaseHelper.instance.clearFoodLog();
              _loadFoodLogFromDb(); // Recharger la liste vide
              Navigator.pop(context);
            },
            child: const Text('Annuler'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Résumé nutritionnel'),
        actions: [
          IconButton(
        icon: const Icon(Icons.delete),
        tooltip: 'Effacer tous les aliments',
        onPressed: _clearFoodItems,
       ),
       IconButton(
        icon: const Icon(Icons.settings),
        tooltip: 'Objectifs',
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SettingsScreen()),
        );
    },
  ),
      ],
    ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Jauge calories
            CircularPercentIndicator(
              radius: 120,
              lineWidth: 14,
              percent: (totalCalories / goalCalories).clamp(0, 1),
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formatDouble(totalCalories),
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  Text('Calories'),
                ],
              ),
              footer: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${formatDouble(goalCalories - totalCalories)} restantes',
                  style: const TextStyle(fontSize: 14),
                ),
              ),
              progressColor: Colors.green,
              backgroundColor: Colors.green.shade100,
              circularStrokeCap: CircularStrokeCap.round,
            ),
            const SizedBox(height: 32),

            // Jauges macronutriments en ligne
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildMacroIndicator(
                    label: 'Glucides',
                    value: totalCarbs,
                    max: goalCarbs,
                    color: Colors.blue),
                _buildMacroIndicator(
                    label: 'Protéines',
                    value: totalProtein,
                    max: goalProtein,
                    color: Colors.red),
                _buildMacroIndicator(
                    label: 'Lipides',
                    value: totalFat,
                    max: goalFat,
                    color: Colors.orange),
              ],
            ),
            const SizedBox(height: 24),
            if (_favoriteFoods.isNotEmpty) ...[
                const Text(
                  'Favoris',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _favoriteFoods.map((food) {
                    return ElevatedButton(
                      onPressed: () => _addFavoriteToToday(food),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[200],
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                      child: Text(food.name ?? 'Sans nom'),
                    );
                  }).toList(),
                ),
                const SizedBox(height: 24),
              ],

            // Liste aliments (tu peux la garder ou ajuster)
            Expanded(
              child: foodItems.isEmpty
                  ? const Center(child: Text('Aucun aliment ajouté'))
                  : ListView.builder(
                      itemCount: foodItems.length,
                      itemBuilder: (context, index) {
                        final item = foodItems[index];
                        return ListTile(
                          title: Text(item.name ?? 'Aliment sans nom'),
                          subtitle: Text(
                              '${item.quantity}g — ${item.totalCalories.toStringAsFixed(0)} kcal'),
                          trailing: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text('${item.totalProtein.toStringAsFixed(1)} g P'),
                              Text('${item.totalCarbs.toStringAsFixed(1)} g G'),
                              Text('${item.totalFat.toStringAsFixed(1)} g L'),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
          
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final shouldRefresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFoodScreen(),
            ),
          );

          // Si on a reçu 'true', c'est qu'un ajout a été fait
          if (shouldRefresh == true && mounted) {
            _refreshData(); // On recharge toutes les données
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMacroIndicator({
    required String label,
    required double value,
    required double max,
    required Color color,
  }) {
    double percent = (value / max).clamp(0, 1);

    return Column(
      children: [
        CircularPercentIndicator(
          radius: 60,
          lineWidth: 8,
          percent: percent,
          center: Text('${value.toStringAsFixed(0)}\n/\n${max.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          progressColor: color,
          backgroundColor: color.withAlpha((0.3 * 255).toInt()),
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
