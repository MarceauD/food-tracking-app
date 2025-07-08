// lib/widgets/home/meal_journal_card.dart
import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/meal_type.dart';

class MealJournalCard extends StatelessWidget {
  final TabController tabController;
  final Map<MealType, List<FoodItem>> groupedFoodItems;
  final Widget Function(List<FoodItem> mealItems) buildMealList;
  final Function(MealType mealType, List<FoodItem> items) onSaveMeal;
  final Function(MealType mealType) onCopyMeal;

  const MealJournalCard({
    super.key,
    required this.tabController,
    required this.groupedFoodItems,
    required this.buildMealList,
    required this.onSaveMeal,
    required this.onCopyMeal,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height : 400,
      child: Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: tabController,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: Colors.grey,
                  labelStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600), // Police un peu plus petite pour mieux loger
                  unselectedLabelStyle: const TextStyle(fontSize: 12),
                  // On remplace le padding par défaut pour un look plus compact
                  labelPadding: const EdgeInsets.symmetric(horizontal: 4.0), 
                  tabs:  [
                    // On ajoute un 'icon' à chaque Tab
                    Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Petit-déj'),
                    Tab(icon: Icon(Icons.lunch_dining_outlined), text: 'Déjeuner'),
                    Tab(icon: Icon(Icons.nightlight_round_outlined), text: 'Dîner'),
                    Tab(icon: Icon(Icons.fastfood_outlined), text: 'Collation'),
                  ],
                ),
              ),
              IconButton(
                  icon: const Icon(Icons.copy_outlined),
                  tooltip: 'Copier le repas d\'hier',
                  onPressed: () {
                    final currentMealType = MealType.values[tabController.index];
                    onCopyMeal(currentMealType);
                  },
                ),

              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: 'Sauvegarder ce repas pour le réutiliser plus tard',
                onPressed: () {
                  final currentMealType = MealType.values[tabController.index];
                  final currentItems = groupedFoodItems[currentMealType]!;
                  if (currentItems.isNotEmpty) {
                    onSaveMeal(currentMealType, currentItems);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Ce repas est vide, impossible de le sauvegarder.')),
                    );
                  }
                },
              ),
            ],
          ),
          const Divider(height: 1),

          _buildTotalsBar(context),

          // Ce Expanded ici est correct, car son parent direct est une Column.
          Expanded(
            child: TabBarView(
              controller: tabController,
              children: [
                buildMealList(groupedFoodItems[MealType.breakfast]!),
                buildMealList(groupedFoodItems[MealType.lunch]!),
                buildMealList(groupedFoodItems[MealType.dinner]!),
                buildMealList(groupedFoodItems[MealType.snack]!),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _buildTotalsBar(BuildContext context) {
    double getMealTotal(MealType type) {
      return groupedFoodItems[type]!.fold(0, (sum, item) => sum + item.totalCalories);
    }

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildMealTotalText(context, 'Petit-déj', getMealTotal(MealType.breakfast)),
          _buildMealTotalText(context, 'Déjeuner', getMealTotal(MealType.lunch)),
          _buildMealTotalText(context, 'Dîner', getMealTotal(MealType.dinner)),
          _buildMealTotalText(context, 'Collation', getMealTotal(MealType.snack)),
        ],
      ),
    );
  }

  Widget _buildMealTotalText(BuildContext context, String label, double value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          value.toStringAsFixed(0),
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

}