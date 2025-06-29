// lib/widgets/home/quick_add_card.dart

import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/saved_meals.dart';

import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/saved_meals.dart';
import '../common/empty_state_widget.dart';

class QuickAddCard extends StatefulWidget {
  // Les paramètres reçus ne changent pas
  final List<FoodItem> favoriteFoods;
  final List<SavedMeal> savedMeals;
  final Function(FoodItem) onFavoriteTap;
  final Function(SavedMeal) onSavedMealTap;
  final Function(FoodItem) onFavoriteLongPress;
  final Function(SavedMeal) onSavedMealLongPress; // <-- NOUVEAU CALLBACK

  const QuickAddCard({
    super.key,
    required this.favoriteFoods,
    required this.savedMeals,
    required this.onFavoriteTap,
    required this.onSavedMealTap,
    required this.onFavoriteLongPress,
    required this.onSavedMealLongPress,
  });

  @override
  State<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends State<QuickAddCard> with TickerProviderStateMixin {
  late final TabController _tabController;
  
  // --- NOS VARIABLES D'ÉTAT CORRIGÉES ---
  bool _isExpanded = false;
  // On sauvegarde nous-même l'index de l'onglet actif
  int _activeTabIndex = 0; 

  // Les hauteurs ne changent pas
  final double _collapsedHeight = 75.0;
  final double _expandedHeight = 200.0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.favoriteFoods.isEmpty && widget.savedMeals.isEmpty) {
      return const SizedBox.shrink();
    }

    return Card(
      elevation: 2.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      clipBehavior: Clip.antiAlias,
      child: AnimatedContainer(
        height: _isExpanded ? _expandedHeight : _collapsedHeight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
        child: Column(
          children: [
            TabBar(
              controller: _tabController,
              // --- LA LOGIQUE DE GESTION DE CLIC, DÉFINITIVE ET CORRECTE ---
              onTap: (tappedIndex) {
                setState(() {
                  // Cas 1 : La carte est DÉJÀ dépliée ET on clique sur le même onglet
                  if (_isExpanded && _activeTabIndex == tappedIndex) {
                    _isExpanded = false; // Alors on la replie
                  } else {
                  // Cas 2 : Dans TOUS les autres cas (carte repliée, ou clic sur un autre onglet)
                    _isExpanded = true; // Alors on la déplie (ou la laisse dépliée)
                  }
                  
                  // À la fin, on met à jour notre variable avec le nouvel onglet actif
                  _activeTabIndex = tappedIndex;
                });
              },
              labelColor: Theme.of(context).colorScheme.primary,
              unselectedLabelColor: Colors.grey,
              tabs: const [
                Tab(icon: Icon(Icons.star), text: 'Aliments'),
                Tab(icon: Icon(Icons.restaurant_menu), text: 'Repas'),
              ],
            ),
            if (_isExpanded) // On utilise la même condition ici pour la performance
              Expanded(
                child: TabBarView(
                  physics: const NeverScrollableScrollPhysics(),
                  controller: _tabController,
                  children: [
                    _buildFavoritesView(widget.favoriteFoods),
                    _buildSavedMealsView(widget.savedMeals),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildFavoritesView(List<FoodItem> items) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        imagePath: 'assets/images/undraw_love-it_8pc0.svg', 
        title: 'Aucun aliment favori',
        subtitle: 'Sauvegardez vos aliments fréquents ici pour les ajouter en un clin d\'œil.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: items.map((food) {
          return GestureDetector(
            onTap: () => widget.onFavoriteTap(food),
            onLongPress: () => widget.onFavoriteLongPress(food),
            child: Chip(
              label: Text(food.name ?? 'Sans nom'),
              backgroundColor: Colors.blueGrey[50],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildSavedMealsView(List<SavedMeal> meals) {
    if (meals.isEmpty) {
      return const EmptyStateWidget(
        imagePath: 'assets/images/undraw_breakfast_rgx5.svg',
        title: 'Aucun repas sauvegardé',
        subtitle: 'Utilisez l\'icône 🔖 dans le journal pour sauvegarder un repas complet et le réutiliser.',
      );
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: meals.map((meal) {
          return GestureDetector(
            onLongPress: () => widget.onSavedMealLongPress(meal),
            child: ElevatedButton.icon(
              icon: const Icon(Icons.bookmark, size: 16),
              label: Text(meal.name),
              onPressed: () => widget.onSavedMealTap(meal),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green[50],
                foregroundColor: Colors.green[800],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}