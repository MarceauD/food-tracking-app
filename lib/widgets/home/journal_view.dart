// lib/widgets/home/journal_view.dart
import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/saved_meals.dart';
import '../../models/meal_type.dart';
import 'summary_card.dart';
import 'quick_add_card.dart';
import 'meal_journal_card.dart';

class JournalView extends StatelessWidget {
  final ScrollController scrollController; // <-- On le reçoit ici
  // Les paramètres ne changent pas
  final double totalCalories;
  final double goalCalories;
  final double totalCarbs;
  final double goalCarbs;
  final double totalProtein;
  final double goalProtein;
  final double totalFat;
  final double goalFat;
  final String currentTip;
  final List<FoodItem> favoriteFoods;
  final List<SavedMeal> savedMeals;
  final bool isToday;
  final TabController tabController;
  final Map<MealType, List<FoodItem>> groupedFoodItems;
  final Widget Function(List<FoodItem> mealItems) buildMealList;
  final Function(MealType mealType, List<FoodItem> items) onSaveMeal;
  final Function(MealType mealType) onCopyMeal;
  final Function(FoodItem) onFavoriteTap;
  final Function(SavedMeal) onSavedMealTap;
  final Function(FoodItem) onFavoriteLongPress;
  final Function(SavedMeal) onSavedMealLongPress;
  final Function(int tabIndex) onClearAllTapped;

  const JournalView({
    super.key, 
    required this.scrollController,// On garde la clé pour PageStorage
    required this.totalCalories,
    required this.goalCalories,
    required this.totalCarbs,
    required this.goalCarbs,
    required this.totalProtein,
    required this.goalProtein,
    required this.totalFat,
    required this.goalFat,
    required this.currentTip,
    required this.favoriteFoods,
    required this.savedMeals,
    required this.isToday,
    required this.tabController,
    required this.groupedFoodItems,
    required this.buildMealList,
    required this.onSaveMeal,
    required this.onCopyMeal,
    required this.onFavoriteTap,
    required this.onSavedMealTap,
    required this.onFavoriteLongPress,
    required this.onSavedMealLongPress,
    required this.onClearAllTapped,
  });

  @override
  Widget build(BuildContext context) {
    // 1. Le widget racine est maintenant un SingleChildScrollView
    //    C'est lui qui portera la clé pour la sauvegarde de position.
    return ListView(
      controller: scrollController,
      children: [Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        // 2. Son enfant est une Column, qui organise les widgets verticalement.
        child: Column(
          children: [
            SummaryCard(
              totalCalories: totalCalories,
              goalCalories: goalCalories,
              totalCarbs: totalCarbs,
              goalCarbs: goalCarbs,
              totalProtein: totalProtein,
              goalProtein: goalProtein,
              totalFat: totalFat,
              goalFat: goalFat,
              gaugeRadiusCalories: 90.0,
            ),
            if (isToday && currentTip.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Container(
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.lightbulb_outline, color: Theme.of(context).colorScheme.primary),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          currentTip,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontWeight: FontWeight.w500,
                              ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            // Les SizedBox avec hauteur fixe sont importants car ils donnent
            // une contrainte claire aux widgets enfants qui contiennent des listes.
            SizedBox(
              height: 400,
              child: MealJournalCard(
                tabController: tabController,
                groupedFoodItems: groupedFoodItems,
                buildMealList: buildMealList,
                onSaveMeal: onSaveMeal,
                onCopyMeal: onCopyMeal,
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 300,
              child: QuickAddCard(
                favoriteFoods: favoriteFoods,
                savedMeals: savedMeals,
                onFavoriteTap: onFavoriteTap,
                onSavedMealTap: onSavedMealTap,
                onFavoriteLongPress: onFavoriteLongPress,
                onSavedMealLongPress: onSavedMealLongPress,
                onClearAllTapped: onClearAllTapped,
              ),
            ),
            const SizedBox(height: 80),
          ],
        ),
      ),
      ],
    );
  }
}