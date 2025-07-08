// lib/widgets/home/quick_add_card.dart

import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/saved_meals.dart';
import '../common/empty_state_widget.dart';
import 'package:flutter_animate/flutter_animate.dart';

// ON TRANSFORME LE WIDGET EN STATEFULWIDGET
class QuickAddCard extends StatefulWidget {
  final List<FoodItem> favoriteFoods;
  final List<SavedMeal> savedMeals;
  final Function(FoodItem) onFavoriteTap;
  final Function(SavedMeal) onSavedMealTap;
  final Function(FoodItem) onFavoriteLongPress;
  final Function(SavedMeal) onSavedMealLongPress;
  final Function(int tabIndex) onClearAllTapped;

  const QuickAddCard({
    super.key,
    required this.favoriteFoods,
    required this.savedMeals,
    required this.onFavoriteTap,
    required this.onSavedMealTap,
    required this.onFavoriteLongPress,
    required this.onSavedMealLongPress,
    required this.onClearAllTapped,
  });

  @override
  State<QuickAddCard> createState() => _QuickAddCardState();
}

class _QuickAddCardState extends State<QuickAddCard> with TickerProviderStateMixin {
  late final TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    // On initialise le TabController avec 2 onglets
    _tabController = TabController(length: 2, vsync: this);
    // On ajoute un "auditeur" pour vider la recherche quand on change d'onglet
    _tabController.addListener(() {
      if (_searchController.text.isNotEmpty) {
        _searchController.clear();
      }
    });
    // On écoute les changements dans le champ de recherche
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  // MÉTHODE POUR CONSTRUIRE LE CHAMP DE RECHERCHE
  Widget _buildSearchView({required String hintText}) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: TextField(
        controller: _searchController,
        decoration: InputDecoration(
          hintText: hintText,
          prefixIcon: const Icon(Icons.search, size: 20),
          isDense: true, // Rend le champ plus compact
          filled: true,
          fillColor: Theme.of(context).scaffoldBackgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(24.0),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }

  // MÉTHODE POUR CONSTRUIRE LA LISTE DES FAVORIS
  Widget _buildFavoritesView(List<FoodItem> items) {
    if (items.isEmpty) {
      return const EmptyStateWidget(
        imagePath: 'assets/images/undraw_love-it_8pc0.svg',
        title: 'Aucun aliment favori',
        subtitle: 'Utilisez le menu d\'un aliment dans votre journal pour l\'ajouter ici.',
      );
    }

    final filteredItems = items.where((item) {
      return item.name?.toLowerCase().contains(_searchQuery) ?? false;
    }).toList();

    // On retourne directement la liste scrollable.
    // Le champ de recherche sera un élément de cette liste.
    return Column(
      children: [
        // Le champ de recherche est maintenant dans cette Column
        _buildSearchView(hintText: 'Rechercher dans les favoris...'),
        Expanded(
          child: filteredItems.isEmpty
              // Cas 2 : La recherche ne donne aucun résultat
              ? const EmptyStateWidget(
                  imagePath: 'assets/images/undraw_questions.svg',
                  title: 'Aucun résultat',
                  subtitle: 'Aucun aliment favori ne correspond à votre recherche.',
                )
              // Cas 3 : On affiche les résultats filtrés
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: filteredItems.length,
                  itemBuilder: (context, index) {
                    final food = filteredItems[index];
                    return ListTile(
                      leading: const Icon(Icons.star_outline, color: Colors.amber),
                      title: Text(food.name ?? 'Sans nom'),
                      onTap: () => widget.onFavoriteTap(food),
                      onLongPress: () => widget.onFavoriteLongPress(food),
                    );
                  },
                ),
        ),
      ],
    ).animate().fadeIn();
  }

  // MÉTHODE POUR CONSTRUIRE LA LISTE DES REPAS SAUVEGARDÉS
  Widget _buildSavedMealsView(List<SavedMeal> meals) {
    // Cas 1 : La liste de base est vide
    if (meals.isEmpty) {
      return const EmptyStateWidget(
        imagePath: 'assets/images/undraw_breakfast_rgx5.svg',
        title: 'Aucun repas sauvegardé',
        subtitle: 'Utilisez l\'icône 🔖 dans le journal pour sauvegarder un repas complet.',
      );
    }
    
    // Si la liste n'est pas vide, on continue...
    final filteredMeals = meals.where((meal) {
      return meal.name.toLowerCase().contains(_searchQuery);
    }).toList();

    return Column(
      children: [
        _buildSearchView(hintText: 'Rechercher dans les repas...'),
        Expanded(
          child: filteredMeals.isEmpty
              // Cas 2 : La recherche ne donne aucun résultat
              ? const EmptyStateWidget(
                  imagePath: 'assets/images/undraw_questions.svg',
                  title: 'Aucun résultat',
                  subtitle: 'Aucun repas sauvegardé ne correspond à votre recherche.',
                )
              // Cas 3 : On affiche les résultats
              : ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  itemCount: filteredMeals.length,
                  itemBuilder: (context, index) {
                    final meal = filteredMeals[index];
                    return ListTile(
                      leading: const Icon(Icons.bookmark_outline, color: Colors.green),
                      title: Text(meal.name),
                      onTap: () => widget.onSavedMealTap(meal),
                      onLongPress: () => widget.onSavedMealLongPress(meal),
                    );
                  },
                ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // La vue principale ne change pas radicalement, elle appelle les nouvelles méthodes
    return Card(
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TabBar(
                  controller: _tabController,
                  tabs: const [
                    Tab(text: 'Aliments Favoris'),
                    Tab(text: 'Repas'),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: () => widget.onClearAllTapped(_tabController.index),
              ),
            ],
          ),
          const Divider(height: 1),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFavoritesView(widget.favoriteFoods),
                _buildSavedMealsView(widget.savedMeals),
              ],
            ),
          ),
        ],
      ),
    );
  }
}