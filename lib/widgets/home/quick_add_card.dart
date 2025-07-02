// lib/widgets/home/quick_add_card.dart

import 'package:flutter/material.dart';
import '../../models/food_item.dart';
import '../../models/saved_meals.dart';
import '../common/empty_state_widget.dart';

class _QuickAddButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _QuickAddButton({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(20.0), // Pour l'effet d'ondulation
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(20.0),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: foregroundColor),
            const SizedBox(width: 6),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class QuickAddCard extends StatefulWidget {
  // Les paramètres reçus ne changent pas
  final List<FoodItem> favoriteFoods;
  final List<SavedMeal> savedMeals;
  final Function(FoodItem) onFavoriteTap;
  final Function(SavedMeal) onSavedMealTap;
  final Function(FoodItem) onFavoriteLongPress;
  final Function(SavedMeal) onSavedMealLongPress;
  
  final Function(int tabIndex) onClearAllTapped; // <-- NOUVEAU CALLBACK

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
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  // --- NOS VARIABLES D'ÉTAT CORRIGÉES ---
  bool _isExpanded = false;
  // On sauvegarde nous-même l'index de l'onglet actif
  int _activeTabIndex = 0; 

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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

  // Les hauteurs ne changent pas
  final double _collapsedHeight = 75.0;
  final double _expandedHeight = 200.0;

  @override
  Widget build(BuildContext context) {
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
            Row(children: [
              Expanded(child: TabBar(
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
                Tab(icon: Icon(Icons.star_outline), text: 'Aliments'),
                Tab(icon: Icon(Icons.restaurant_menu_outlined), text: 'Repas'),
              ],
            ),
            ),

            IconButton(
                  icon: const Icon(Icons.delete_sweep_outlined),
                  color: Colors.grey,
                  tooltip: 'Vider la liste',
                  onPressed: () {
                    // On appelle le callback en lui passant l'index de l'onglet actif
                    widget.onClearAllTapped(_tabController.index);
                  },
                )

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
  // On filtre la liste en fonction de la recherche
  final filteredItems = items.where((item) {
    return item.name?.toLowerCase().contains(_searchQuery) ?? false;
  }).toList();

  return Column(
    children: [
      _buildSearchView(hintText: 'Rechercher dans les favoris...'), // Notre champ de recherche
      Expanded(
        child: filteredItems.isEmpty
            ? const EmptyStateWidget(
              imagePath: 'assets/images/undraw_love-it_8pc0.svg', 
              title: 'Aucun aliment favori',
              subtitle: 'Sauvegardez vos aliments fréquents ici pour les ajouter en un clin d\'œil.',)
            : ListView.builder(
                itemCount: filteredItems.length,
                itemBuilder: (context, index) {
                  final food = filteredItems[index];
                  return ListTile(
                    leading: const Icon(Icons.star, color: Colors.amber),
                    title: Text(food.name ?? 'Sans nom'),
                    onTap: () => widget.onFavoriteTap(food),
                    onLongPress: () => widget.onFavoriteLongPress(food),
                  );
                },
              ),
      ),
    ],
  );
}



  Widget _buildSearchView({required String hintText}) {
  return Padding(
    padding: const EdgeInsets.all(8.0),
    child: TextField(
      controller: _searchController,
      decoration: InputDecoration(
        hintText: 'Rechercher dans les favoris...',
        prefixIcon: const Icon(Icons.search),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12.0),
          borderSide: BorderSide.none,
        ),
        filled: true,
        fillColor: Colors.grey.withOpacity(0.1),
      ),
    ),
  );
}

  Widget _buildSavedMealsView(List<SavedMeal> meals) {
  // On filtre la liste des repas en fonction de la recherche
  final filteredMeals = meals.where((meal) {
    return meal.name.toLowerCase().contains(_searchQuery);
  }).toList();

  return Column(
    children: [
      // On réutilise notre méthode de construction pour le champ de recherche
      _buildSearchView(hintText: 'Rechercher dans les repas...'),
      
      Expanded(
        child: filteredMeals.isEmpty
            ? const EmptyStateWidget(
                imagePath: 'assets/images/undraw_breakfast_rgx5.svg',
                title: 'Aucun résultat trouvé',
                subtitle: 'Essayez un autre terme de recherche ou sauvegardez de nouveaux repas.',
              )
            // On affiche la liste verticale
            : ListView.builder(
                padding: EdgeInsets.zero,
                itemCount: filteredMeals.length,
                itemBuilder: (context, index) {
                  final meal = filteredMeals[index];
                  // On utilise un ListTile pour un affichage propre et cliquable
                  return ListTile(
                    leading: const Icon(Icons.bookmark, color: Colors.green),
                    title: Text(meal.name),
                    onTap: () => widget.onSavedMealTap(meal),
                    onLongPress: () => widget.onSavedMealLongPress!(meal),
                  );
                },
              ),
      ),
    ],
  );
}
}
