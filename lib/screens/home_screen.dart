import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../models/daily_summary.dart';
import 'add_food_screen.dart';
import 'settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart'; 
import 'package:intl/intl.dart';
import '../widgets/home/summary_card.dart';
import '../widgets/home/meal_journal_card.dart';
import '../controllers/home_controller.dart';
import '../models/saved_meals.dart';
import '../widgets/home/quick_add_card.dart';
import '../widgets/common/empty_state_widget.dart';
import 'stats_screen.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/secondary_button.dart';


class HomeScreen extends StatefulWidget  {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  final HomeController _controller = HomeController();

  List<FoodItem> foodItems = [];
  List<FoodItem> _favoriteFoods = [];
  List<SavedMeal> _savedMeals = [];

  late TabController _tabController;

  int _selectedIndex = 0;

  // Valeurs max en dur
  double goalCalories = 1700;
  double goalProtein = 160;
  double goalCarbs = 150;
  double goalFat = 60;

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addObserver(this);

    _controller.checkAndResetLogIfNeeded().then((_) {
      _refreshData();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Si l'état est "resumed", ça veut dire que l'app était en pause et revient
    if (state == AppLifecycleState.resumed) {
      _checkDateAndResetIfNeeded();
    }
  }

  Future<void> _checkDateAndResetIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    
    // 2. Récupérer la dernière date de visite
    final String? lastVisitDateStr = prefs.getString('lastVisitDate');
    final today = DateTime.now();
    
    // On ne garde que la partie "Année-Mois-Jour" pour comparer les jours
    final todayDateOnly = DateTime(today.year, today.month, today.day);

    // 3. Si c'est la toute première visite, on sauvegarde la date et on continue
    if (lastVisitDateStr == null) {
      await prefs.setString('lastVisitDate', todayDateOnly.toIso8601String());
      _refreshData();
      return;
    }

    final lastVisitDate = DateTime.parse(lastVisitDateStr);

    // 4. LA CONDITION CLÉ : Si la dernière visite était avant aujourd'hui
    if (lastVisitDate.isBefore(todayDateOnly)) {
      // On vide le journal de la BDD
      await DatabaseHelper.instance.clearFoodLog();
      // On met à jour la date de dernière visite à aujourd'hui
      await prefs.setString('lastVisitDate', todayDateOnly.toIso8601String());
    } else {
    }
    
    // Dans tous les cas (reset ou pas), on rafraîchit l'affichage
    _refreshData();
  }

  @override
  void dispose() {
    // Très important de se désabonner pour éviter les fuites de mémoire
    _tabController.dispose(); 
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _refreshData() async {
    // Les méthodes de chargement appellent maintenant le controller
    // et mettent à jour l'état de l'UI avec le résultat
    final goals = await _controller.loadGoals();
    final favorites = await _controller.loadFavorites();
    final log = await _controller.loadFoodLogForToday();
    final savedMeals = await _controller.loadSavedMeals();
    
    setState(() {
      goalCalories = goals['calories']!;
      goalCarbs = goals['carbs']!;
      goalProtein = goals['protein']!;
      goalFat = goals['fat']!;
      _favoriteFoods = favorites;
      _savedMeals = savedMeals;
      foodItems = log;
    });

    final summary = DailySummary(
      date: DateTime.now(),
      totalCalories: totalCalories,
      totalCarbs: totalCarbs,
      totalProtein: totalProtein,
      totalFat: totalFat,
      goalCalories: goalCalories,
    );
    await _controller.saveOrUpdateSummary(summary);
  }

  Future<void> _addSavedMealToLog(SavedMeal savedMeal, MealType mealType) async {
  final now = DateTime.now();
  for (final itemTemplate in savedMeal.items) {
    final itemToLog = itemTemplate.copyWith(
      date: now,
      mealType: mealType,
      forceIdToNull: true,
    );
    await DatabaseHelper.instance.createFoodLog(itemToLog);

  }
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
  
  Future<void> _showDeleteFavoriteDialog(FoodItem favorite) async {
    // L'ID ne peut pas être null ici car il vient de la BDD
    final int favoriteId = favorite.id!; 

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Supprimer le favori ?'),
          content: Text('Voulez-vous vraiment supprimer "${favorite.name}" de vos favoris ?'),
          actions: <Widget>[
            SecondaryButton(
              text: 'Annuler',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            PrimaryButton(
              text: 'Confirmer',
              onPressed: () async {
                await DatabaseHelper.instance.deleteFavorite(favoriteId);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  _refreshData();
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _showSaveMealDialog(MealType mealType, List<FoodItem> items) async {
  final nameController = TextEditingController();
  
  // On pré-remplit avec un nom par défaut
  nameController.text = '${mealType.frenchName} favori';
  return showDialog<void>(
    context: context,
    builder: (context) {
      return AlertDialog(
        title: const Text('Sauvegarder le repas'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(labelText: 'Nom du repas'),
          autofocus: true,
        ),
        actions: [
          SecondaryButton(
              text: 'Annuler',
              onPressed: () {
                Navigator.of(context).pop();
              },
          ),
          PrimaryButton(
              text: 'Confirmer',
              onPressed: () async {
                if (nameController.text.isNotEmpty) {
                await _controller.saveCurrentMeal(nameController.text, items);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  _refreshData();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Repas sauvegardé !')),
                  );
                }
                }
              }
            ),
        ],
      );
    },
  );

  
}

// lib/screens/home_screen.dart > _HomeScreenState

Future<void> _showAddSavedMealToMealDialog(SavedMeal meal) async {
  // 1. On attend que le menu se ferme ET nous renvoie un résultat
  final bool? refreshNeeded = await showModalBottomSheet<bool>(
    context: context,
    useSafeArea: true,
    builder: (BuildContext context) {
      final bottomPadding = MediaQuery.of(context).viewPadding.bottom;

      // Fonction interne pour éviter de répéter du code
      void handleMealSelection(MealType mealType) async {
        await _addSavedMealToLog(meal, mealType);
        if (context.mounted) {
          // 2. Une fois la sauvegarde terminée, on ferme le menu
          //    en renvoyant 'true' pour dire "opération réussie".
          Navigator.pop(context, true);
        }
      }

      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPadding),
          child: Wrap(
            children: [
              ListTile(
                title: Text('Ajouter "${meal.name}" à...', style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
              const Divider(thickness: 1),
              ListTile(
                leading: const Icon(Icons.wb_sunny_outlined),
                title: const Text('Petit-déjeuner'),
                onTap: () => handleMealSelection(MealType.breakfast),
              ),
              ListTile(
                leading: const Icon(Icons.lunch_dining_outlined),
                title: const Text('Déjeuner'),
                onTap: () => handleMealSelection(MealType.lunch),
              ),
              ListTile(
                leading: const Icon(Icons.dinner_dining_outlined),
                title: const Text('Dîner'),
                onTap: () => handleMealSelection(MealType.dinner),
              ),
              ListTile(
                leading: const Icon(Icons.fastfood_outlined),
                title: const Text('Collation'),
                onTap: () => handleMealSelection(MealType.snack),
              ),
            ],
          ),
        ),
      );
    },
  );

  // 3. Ce code s'exécute APRÈS la fermeture du menu.
  //    Si on a reçu le signal 'true', on rafraîchit l'interface.
  if (refreshNeeded == true && mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('"${meal.name}" ajouté au journal !')),
    );
    _refreshData();
  }
}

  Future<void> _showQuantityDialog(FoodItem favorite, MealType meal) async {
    final quantityController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    // On peut pré-remplir avec la quantité par défaut du favori si elle existe
    quantityController.text = favorite.quantity?.toStringAsFixed(0) ?? '100';

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Quelle quantité ?'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: quantityController,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Quantité (g)',
                suffixText: 'g',
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Champ requis';
                }
                if (double.tryParse(value) == null || double.parse(value) <= 0) {
                  return 'Quantité invalide';
                }
                return null;
              },
              autofocus: true,
            ),
          ),
          actions: <Widget>[
            SecondaryButton(
              text: 'Annuler',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            PrimaryButton(
              text: 'Confirmer',
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final double newQuantity = double.parse(quantityController.text);

                  // On utilise copyWith pour créer un nouvel item avec la bonne quantité et la date du jour
                  final itemToLog = favorite.copyWith(
                    quantity: newQuantity,
                    date: DateTime.now(),
                    mealType: meal, 
                    forceIdToNull: true,
                  );
                  
                  // On insère ce nouvel item dans le journal
                  await DatabaseHelper.instance.createFoodLog(itemToLog);

                  // On ferme la popup et on rafraîchit la liste
                  if (context.mounted) {
                    Navigator.of(context).pop();
                    _loadFoodLogFromDb();
                  }
                }
              },
            ),
          ],
        );
      },
    );
  }

   Future<void> _showAddFavoriteToMealDialog(FoodItem favorite) async {
  // Fonction interne pour gérer la logique après la sélection d'un repas
    addFavoriteAndRefresh(MealType meal) async {
      // 1. On ferme le menu
      Navigator.of(context).pop();

      // 2. On affiche la popup pour demander la quantité
      await _showQuantityDialog(favorite, meal);

      // 3. On rafraîchit les données (au cas où, bien que _showQuantityDialog le fasse déjà)
      _refreshData();
    }

    return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (BuildContext context) {
      final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
      return SingleChildScrollView(child: Padding(padding: EdgeInsets.only(bottom: bottomPadding),child: Wrap(
        children: <Widget>[
          const ListTile(
            title: Text('Ajouter ce favori à...', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Petit-déjeuner'),
            onTap: () => addFavoriteAndRefresh(MealType.breakfast),
          ),
          ListTile(
            leading: const Icon(Icons.lunch_dining_outlined),
            title: const Text('Déjeuner'),
            onTap: () => addFavoriteAndRefresh(MealType.lunch),
          ),
          ListTile(
            leading: const Icon(Icons.dinner_dining_outlined),
            title: const Text('Dîner'),
            onTap: () => addFavoriteAndRefresh(MealType.dinner),
          ),
          ListTile(
            leading: const Icon(Icons.fastfood_outlined),
            title: const Text('Collation'),
            onTap: () => addFavoriteAndRefresh(MealType.snack),
          ),
        ],
      ),
      ),
      );
    },
    );
  }

  void _clearFoodItems() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirmation'),
        content: const Text('Supprimer tous les aliments consommés aujourd''hui ?'),
        actions: [
          SecondaryButton(
              text: 'Annuler',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          PrimaryButton(
              text: 'Confirmer',
              onPressed: () async {
                await _controller.clearLog(); 
              _refreshData();
              Navigator.pop(context);
              },
            ),
        ],
      ),
    );
  }

  Future<void> _showDeleteSavedMealDialog(SavedMeal meal) async {
    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Supprimer ce repas ?'),
          content: Text('Voulez-vous vraiment supprimer le repas "${meal.name}" ? Cette action est irréversible.'),
          actions: <Widget>[
            SecondaryButton(
              text: 'Annuler',
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            PrimaryButton(
              text: 'Confirmer',
              onPressed: () async {
                await _controller.deleteSavedMeal(meal.id!);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  _refreshData(); // On rafraîchit tout pour voir le changement
                }
              },
            ),
          ],
        );
      },
    );
  }

 Widget _buildWelcomeMessage() {
    final hour = DateTime.now().hour;

    String message;
    if (hour < 12) {
      message = 'Bonjour ! 👋';
    } else if (hour < 18) {
      message = 'Bon après-midi ! ☀️';
    } else {
      message = 'Bonsoir ! 🌙 ';
    }
    return Text(
      message,
      style: Theme.of(context).textTheme.headlineSmall,
    );
  }

  Widget _buildDateDisplay() {
    final String formattedDate = DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now());

    return Text(
      formattedDate[0].toUpperCase() + formattedDate.substring(1),
      
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  void _showMealSelection() {
    // Le menu va lancer l'écran d'ajout avec le bon repas en paramètre
    navigateToAddFoodScreen(MealType meal) {
      Navigator.pop(context); // On ferme le menu
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => AddFoodScreen(mealType: meal),
        ),
      ).then((_) => _refreshData()); // On rafraîchit quand on revient
    }

      showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (context) {
        final bottomPadding = MediaQuery.of(context).viewPadding.bottom;
        return SingleChildScrollView(
          child: Padding(padding: EdgeInsets.only(bottom: bottomPadding), 
        child:  
        Wrap(
          children: [
            ListTile(
              leading: const Icon(Icons.wb_sunny_outlined),
              title: const Text('Petit-déjeuner'),
              onTap: () => navigateToAddFoodScreen(MealType.breakfast),
            ),
            ListTile(
              leading: const Icon(Icons.lunch_dining_outlined),
              title: const Text('Déjeuner'),
              onTap: () => navigateToAddFoodScreen(MealType.lunch),
            ),
            ListTile(
              leading: const Icon(Icons.dinner_dining_outlined),
              title: const Text('Dîner'),
              onTap: () => navigateToAddFoodScreen(MealType.dinner),
            ),
            ListTile(
              leading: const Icon(Icons.fastfood_outlined),
              title: const Text('Collation'),
              onTap: () => navigateToAddFoodScreen(MealType.snack),
            ),
          ],
        ),
        ),
        );
      },
      );
    }

    PreferredSizeWidget _buildAppBar() {
    switch (_selectedIndex) {
      // Cas 1 : Onglet "Progrès" (index 1)
      case 1:
        return AppBar(
          title: Text(
            'Mes Progrès',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );

      // Cas 2 : Onglet "Paramètres" (index 2)
      case 2:
        // Notre SettingsScreen a déjà sa propre AppBar, mais par sécurité,
        // si un jour vous la changez, celle-ci s'affichera.
        return AppBar(
          title: Text(
            'Paramètres',
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        );

      // Cas 0 : Onglet "Journal" (par défaut)
      case 0:
      default:
        // On retourne notre AppBar personnalisée et complexe
        return PreferredSize(
          preferredSize: const Size.fromHeight(80.0),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            title: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildWelcomeMessage(),
                _buildDateDisplay(),
              ],
            ),
            centerTitle: false,
            
          ),
        );
    }
  }

  Widget _buildJournalView() {
    final groupedFoodItems = _controller.groupFoodItemsByMeal(foodItems);
    final gaugeRadiusCalories = 90.0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
        child: ListView(
          children: [
            // --- ON APPELLE NOTRE NOUVEAU WIDGET DE RÉSUMÉ ---
            SummaryCard(
              totalCalories: totalCalories,
              goalCalories: goalCalories,
              totalCarbs: totalCarbs,
              goalCarbs: goalCarbs,
              totalProtein: totalProtein,
              goalProtein: goalProtein,
              totalFat: totalFat,
              goalFat: goalFat,
              gaugeRadiusCalories: gaugeRadiusCalories,
            ),
            
          const SizedBox(height: 16),

          QuickAddCard(
              favoriteFoods: _favoriteFoods,
              savedMeals: _savedMeals,
              onFavoriteTap: _showAddFavoriteToMealDialog,
              onSavedMealTap: _showAddSavedMealToMealDialog,
              onFavoriteLongPress: _showDeleteFavoriteDialog,
              onSavedMealLongPress: _showDeleteSavedMealDialog,
            ),
  
          const SizedBox(height: 16),

          
          MealJournalCard(
              tabController: _tabController,
              groupedFoodItems: groupedFoodItems,
              buildMealList: _buildMealList,
              onSaveMeal: _showSaveMealDialog, // <-- ON PASSE LA NOUVELLE MÉTHODE
            ),

            const SizedBox(height: 80),
      ],
    ),
   );
  }
 
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      _buildJournalView(), // Page 0 : Notre journal
      StatsScreen(),   // Page 1 : L'écran de statistiques
      SettingsScreen(onSettingsChanged: _refreshData),// Page 2 : L'écran des paramètres
    ];

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _buildAppBar(),
    body: IndexedStack(
        index: _selectedIndex,
        children: pages,
      ),
       bottomNavigationBar: BottomNavigationBar(
        // La liste des boutons de la barre
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.menu_book_outlined),
            activeIcon: Icon(Icons.menu_book),
            label: 'Journal',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.bar_chart_outlined),
            activeIcon: Icon(Icons.bar_chart),
            label: 'Progrès',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings_outlined),
            activeIcon: Icon(Icons.settings),
            label: 'Paramètres',
          ),
        ],
        currentIndex: _selectedIndex, // L'onglet actuellement actif
        selectedItemColor: Theme.of(context).colorScheme.primary, // Couleur de l'item actif
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: false,
        // La fonction à appeler quand on clique sur un onglet
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showMealSelection,
              child: const Icon(Icons.add),
            )
          : null,
    );
}

Future<void> _showEditQuantityDialog(FoodItem item) async {
  final quantityController = TextEditingController(text: (item.quantity ?? 100).toStringAsFixed(0));
  
  // On affiche une popup similaire à celle que nous connaissons
  final newQuantity = await showDialog<double>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Modifier la quantité de "${item.name}"'),
      content: TextField(
        controller: quantityController,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: const InputDecoration(labelText: 'Nouvelle quantité (g)'),
        autofocus: true,
      ),
      actions: [
        TextButton(child: const Text('Annuler'), onPressed: () => Navigator.pop(context)),
        ElevatedButton(
          child: const Text('Valider'),
          onPressed: () {
            final double? parsedQuantity = double.tryParse(quantityController.text);
            if (parsedQuantity != null && parsedQuantity > 0) {
              Navigator.pop(context, parsedQuantity);
            }
          },
        ),
      ],
    ),
  );

  // Si l'utilisateur a validé une nouvelle quantité, on met à jour la BDD et l'interface
  if (newQuantity != null && newQuantity != item.quantity) {
    await _controller.updateFoodLogItemQuantity(item.id!, newQuantity);
    _refreshData(); // On rafraîchit tout pour mettre à jour les totaux
  }
}

Widget _buildMealList(List<FoodItem> mealItems) {
  if (mealItems.isEmpty) {
    // L'état vide ne change pas
    return const EmptyStateWidget(
      imagePath: 'assets/images/undraw_healthy-habit_2ata.svg',
      title: 'Ce repas est encore vide',
      subtitle: 'Appuyez sur le bouton "+" pour ajouter votre premier aliment.',
    );
  }

  // ON RETOURNE UNE COLUMN POUR POUVOIR AJOUTER UN BOUTON PLUS TARD
  return Column(
    children: [
      // La liste doit être dans un Expanded pour prendre la place disponible
      Expanded(
        child: ListView.builder(
          padding: const EdgeInsets.symmetric(horizontal: 8.0),
          itemCount: mealItems.length,
          itemBuilder: (context, index) {
            final item = mealItems[index];
            return Dismissible(
              key: ValueKey(item.id),
              onDismissed: (direction) { // On appelle le controller pour supprimer l'item de la base de données
          _controller.deleteFoodLogItem(item.id!);
          
          // On met à jour l'interface IMMÉDIATEMENT pour une meilleure réactivité
          // sans attendre le retour de la base de données.
          setState(() {
            foodItems.remove(item);
          });

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('"${item.name}" supprimé.')),
          );},
              background: Container(color: Colors.red,
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 20.0),
          child: const Icon(Icons.delete_outline, color: Colors.white),),
              child: InkWell(
                onTap: () => _showEditQuantityDialog(item),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 8.0),
                  child: Row(
                    children: [
                      // Colonne pour le nom et les macros
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name ?? 'Aliment sans nom',
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // NOUVEAU : Affichage des macros
                            Text(
                              '${item.quantity != null ? item.quantity!.toStringAsFixed(0) : 'N/A'} g  •  G : ${item.totalCarbs.toStringAsFixed(0)} g P : ${item.totalProtein.toStringAsFixed(0)} g L : ${item.totalFat.toStringAsFixed(0)} g',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          ],
                        ),
                      ),
                      // Calories à la fin
                      Text(
                        '${item.totalCalories.toStringAsFixed(0)} kcal',
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
      Padding(
        padding: const EdgeInsets.all(16.0),
        child: SecondaryButton( // On utilise notre bouton secondaire
          text: 'Ajouter un aliment',
          icon: Icons.add,
          onPressed: () {
            // On identifie le repas actuellement sélectionné dans le TabController
            final currentMealType = MealType.values[_tabController.index];
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => AddFoodScreen(mealType: currentMealType),
              ),
            ).then((_) => _refreshData());
          },
        ),
      ),
    ],
  );
}
}