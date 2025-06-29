// lib/widgets/home/meal_journal_card.dart
import 'package:flutter/material.dart';
import '../../models/food_item.dart';

class MealJournalCard extends StatelessWidget {
  final TabController tabController;
  final Map<MealType, List<FoodItem>> groupedFoodItems;
  final Widget Function(List<FoodItem> mealItems) buildMealList;
  final Function(MealType mealType, List<FoodItem> items) onSaveMeal;

  const MealJournalCard({
    super.key,
    required this.tabController,
    required this.groupedFoodItems,
    required this.buildMealList,
    required this.onSaveMeal,
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
                  tabs: const [
                    // On ajoute un 'icon' à chaque Tab
                    Tab(icon: Icon(Icons.wb_sunny_outlined), text: 'Petit-déj'),
                    Tab(icon: Icon(Icons.lunch_dining_outlined), text: 'Déjeuner'),
                    Tab(icon: Icon(Icons.nightlight_round_outlined), text: 'Dîner'),
                    Tab(icon: Icon(Icons.fastfood_outlined), text: 'Collation'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.bookmark_add_outlined),
                tooltip: 'Sauvegarder ce repas',
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
}