import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import '../models/food_item.dart';
import 'add_food_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<FoodItem> foodItems = [];

  // Totaux calculés
  double get totalCalories =>
      foodItems.fold(0, (sum, item) => sum + item.totalCalories);
  double get totalProtein =>
      foodItems.fold(0, (sum, item) => sum + item.totalProtein);
  double get totalCarbs =>
      foodItems.fold(0, (sum, item) => sum + item.totalCarbs);
  double get totalFat =>
      foodItems.fold(0, (sum, item) => sum + item.totalFat);

  // Valeurs max en dur
  final double maxCalories = 1700;
  final double maxProtein = 160;
  final double maxCarbs = 150;
  final double maxFat = 70;

  // Fonction de formatage des nombres pour affichage
  String formatDouble(double value) => value.toStringAsFixed(0);

  void _addFoodItem(FoodItem item) {
    setState((){
      foodItems.add(item);
    });
  }

  void _clearFoodItems() {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Confirmation'),
      content: const Text('Supprimer tous les aliments consommés ?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Annuler'),
        ),
        TextButton(
          onPressed: () {
            setState(() {
              foodItems.clear();
            });
            Navigator.pop(context);
          },
          child: const Text('Supprimer'),
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
              percent: (totalCalories / maxCalories).clamp(0, 1),
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(formatDouble(totalCalories),
                      style: const TextStyle(
                          fontSize: 28, fontWeight: FontWeight.bold)),
                  Text('Restantes'),
                ],
              ),
              footer: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  '${formatDouble(maxCalories - totalCalories)} restantes',
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
                    max: maxCarbs,
                    color: Colors.blue),
                _buildMacroIndicator(
                    label: 'Protéines',
                    value: totalProtein,
                    max: maxProtein,
                    color: Colors.red),
                _buildMacroIndicator(
                    label: 'Lipides',
                    value: totalFat,
                    max: maxFat,
                    color: Colors.orange),
              ],
            ),

            const SizedBox(height: 24),

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
          final newItem = await Navigator.push<FoodItem>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFoodScreen(),
            ),
          );
          if (newItem != null) {
            _addFoodItem(newItem);
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
          backgroundColor: color.withOpacity(0.3),
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
