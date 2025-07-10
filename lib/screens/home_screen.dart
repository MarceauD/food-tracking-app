// lib/screens/home_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/home_controller.dart';
import '../models/food_item.dart';
import '../widgets/common/empty_state_widget.dart';
import '../widgets/home/home_dialogs.dart';
import '../widgets/home/journal_view.dart';
import 'add_food_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with TickerProviderStateMixin, WidgetsBindingObserver {
  final ScrollController _scrollController = ScrollController();
  final PageStorageBucket _pageStorageBucket = PageStorageBucket();
  final PageStorageKey _journalListKey = const PageStorageKey('journalList');
  
  // --- L'ÉTAT LOCAL EST MAINTENANT MINIMAL ---
  late TabController _tabController;
  int _selectedIndex = 0;
  DateTime _selectedDate = DateTime.now();
  final GlobalKey<StatsScreenState> _statsScreenKey = GlobalKey<StatsScreenState>();

  @override
  void initState() {
     super.initState();
    _tabController = TabController(length: 4, vsync: this);
    WidgetsBinding.instance.addObserver(this);
    
    // ON DÉCALE L'APPEL DANS UN POST-FRAME CALLBACK
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // listen: false est important ici car nous sommes dans une méthode d'état
      // et nous ne voulons pas écouter les changements, juste appeler une fonction.
      context.read<HomeController>().initializeApp(_selectedDate);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // On notifie le controller de vérifier la date.
      context.read<HomeController>().checkAndResetLogIfNeeded();
    }
  }

  // --- MÉTHODES DE GESTION DE L'UI ---

  void _onDateChanged(DateTime newDate) {
    setState(() {
      _selectedDate = newDate;
    });
    // On demande au controller de rafraîchir les données pour la nouvelle date.
    context.read<HomeController>().refreshData(newDate);
  }

  void _onBottomNavTapped(int index) {
    if (index == 1) {
      _statsScreenKey.currentState?.loadData();
    }
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // On utilise Consumer pour écouter les changements du HomeController
    // et reconstruire l'UI en conséquence.
    return Consumer<HomeController>(
      builder: (context, controller, child) {
        final List<Widget> pages = [
          JournalView(
            key: _journalListKey, 
            scrollController: _scrollController,
            totalCalories: controller.totalCalories,
            goalCalories: controller.goalCalories,
            totalCarbs: controller.totalCarbs,
            goalCarbs: controller.goalCarbs,
            totalProtein: controller.totalProtein,
            goalProtein: controller.goalProtein,
            totalFat: controller.totalFat,
            goalFat: controller.goalFat,
            currentTip: controller.currentTip,
            favoriteFoods: controller.favoriteFoods,
            savedMeals: controller.savedMeals,
            isToday: _selectedDate.day == DateTime.now().day,
            tabController: _tabController,
            groupedFoodItems: controller.groupFoodItemsByMeal(controller.foodItems),
            buildMealList: (items) => _buildMealList(context, items, controller),
            onSaveMeal: (type, items) => HomeDialogs.showSaveMealDialog(context, type, items, (name) {
                controller.saveCurrentMeal(name, items).then((_) => controller.refreshData(_selectedDate));
            }),
            onCopyMeal: (type) => HomeDialogs.showCopyMealConfirmation(context, type, () {
                controller.copyMealFromYesterday(type, _selectedDate).then((_) => controller.refreshData(_selectedDate));
            }),
            onFavoriteTap: (food) {
          // On appelle le premier dialogue pour choisir le repas
              HomeDialogs.showAddFavoriteToMealDialog(context, food, (mealType) {
                // Une fois le repas choisi, on appelle le dialogue pour demander la quantité
                HomeDialogs.showQuantityDialog(context, food, mealType, _selectedDate, (itemToLog) {
                  // Une fois la quantité validée, on ajoute l'aliment au journal
                  controller.submitFood(itemToLog).then((_) => controller.refreshData(_selectedDate));
                });
              });
            },
            onSavedMealTap: (meal) => HomeDialogs.showAddSavedMealToMealDialog(context, meal, (mealType) {
              controller.addSavedMealToLog(meal, mealType, _selectedDate).then((_) => controller.refreshData(_selectedDate));
            }),
            onFavoriteLongPress: (food) => HomeDialogs.showDeleteFavoriteDialog(context, food, () {
                controller.deleteFavorite(food.id!).then((_) => controller.refreshData(_selectedDate));
            }),
            onSavedMealLongPress: (meal) => HomeDialogs.showDeleteSavedMealDialog(context, meal, () {
                controller.deleteSavedMeal(meal.id!).then((_) => controller.refreshData(_selectedDate));
            }),
            onClearAllTapped: (index) => HomeDialogs.showClearAllDialog(context, index == 0, () {
              if (index == 0) {
                controller.clearAllFavorites().then((_) => controller.refreshData(_selectedDate));
              } else {
                controller.clearAllSavedMeals().then((_) => controller.refreshData(_selectedDate));
              }
            }),
          ),
          StatsScreen(key: _statsScreenKey),
          SettingsScreen(
            onGoalsChanged: () => controller.refreshData(_selectedDate),
            onProfileChanged: () => controller.loadProfile(),
          ),
        ];

        return Scaffold(
          appBar: _buildAppBar(context, controller.userName),
          body: controller.isLoading
              ? const Center(child: CircularProgressIndicator())
              : PageStorage(
                  bucket: _pageStorageBucket,
                  child: IndexedStack(index: _selectedIndex, children: pages),
                ),
          bottomNavigationBar: BottomNavigationBar(
            items: const <BottomNavigationBarItem>[
              BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), activeIcon: Icon(Icons.menu_book), label: 'Journal'),
              BottomNavigationBarItem(icon: Icon(Icons.bar_chart_outlined), activeIcon: Icon(Icons.bar_chart), label: 'Progrès'),
              BottomNavigationBarItem(icon: Icon(Icons.settings_outlined), activeIcon: Icon(Icons.settings), label: 'Paramètres'),
            ],
            currentIndex: _selectedIndex,
            onTap: _onBottomNavTapped,
          ),
          floatingActionButton: _selectedIndex == 0
              ? FloatingActionButton(onPressed: () => HomeDialogs.showMealSelection(context, _selectedDate), child: const Icon(Icons.add), heroTag: 'fab_home')
              : null,
        );
      },
    );
  }

  // --- MÉTHODES DE CONSTRUCTION DE L'UI (MAINTENANT PLUS SIMPLES) ---

  PreferredSizeWidget _buildAppBar(BuildContext context, String userName) {
    switch (_selectedIndex) {
      case 1: return AppBar(title: Text('Mes Progrès', style: Theme.of(context).textTheme.headlineSmall));
      case 2: return AppBar(title: Text('Paramètres', style: Theme.of(context).textTheme.headlineSmall));
      case 0:
      default:
        return PreferredSize(
          preferredSize: const Size.fromHeight(80.0),
          child: AppBar(
            elevation: 0,
            backgroundColor: Colors.transparent,
            flexibleSpace: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildWelcomeMessage(context, userName),
                    _buildDateNavigation(),
                  ],
                ),
              ),
            ),
          ),
        );
    }
  }

  Widget _buildWelcomeMessage(BuildContext context, String userName) {
    final hour = DateTime.now().hour;
    String greeting;
    if (hour < 12) { greeting = 'Bonjour'; } 
    else if (hour < 18) { greeting = 'Bon après-midi'; } 
    else { greeting = 'Bonsoir'; }
    final String welcomeText = (userName == 'Utilisateur') ? '$greeting !' : '$greeting, $userName !';
    return Text(welcomeText, style: Theme.of(context).textTheme.headlineSmall);
  }


  Future<void> _selectDate(BuildContext context) async {
  final DateTime? picked = await showDatePicker(
    context: context,
    initialDate: _selectedDate, // La date actuellement affichée
    firstDate: DateTime(2023),   // La date la plus ancienne sélectionnable
    lastDate: DateTime.now(),    // On ne peut pas sélectionner une date dans le futur
    locale: const Locale('fr', 'FR'), // Pour s'assurer que le calendrier est en français
  );

  // Si l'utilisateur a choisi une date et que ce n'est pas la même qu'avant
  if (picked != null && picked != _selectedDate) {
    // On appelle notre méthode pour changer la date et rafraîchir les données
    _onDateChanged(picked);
  }
}

  Widget _buildDateNavigation() {
  final now = DateTime.now();
  final bool isToday = _selectedDate.year == now.year &&
                     _selectedDate.month == now.month &&
                     _selectedDate.day == now.day;

  return Row(
    // On centre les éléments horizontalement
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      // Flèche de gauche
      IconButton(
        // On augmente la taille de l'icône
        icon: const Icon(Icons.chevron_left, size: 28.0),
        // On utilise la couleur du texte définie dans le thème de l'AppBar
        color: Theme.of(context).appBarTheme.iconTheme?.color,
        onPressed: () {
          _onDateChanged(_selectedDate.subtract(const Duration(days: 1)));
        },
      ),
      
      // La date, qui reste cliquable pour ouvrir le calendrier
      Expanded(
        child: GestureDetector(
          onTap: () => _selectDate(context),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children:[
              Text('Vous consultez le journal du',
              style: Theme.of(context).textTheme.bodySmall),
            // --- C'EST ICI QUE L'ANIMATION EST APPLIQUÉE ---
            Text(
              DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDate),
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                // On s'assure que la couleur s'adapte au thème
                color: isToday ? Theme.of(context).appBarTheme.titleTextStyle?.color : Colors.orangeAccent,
              ),
            )
            // On attache l'animation directement au widget Text
            .animate(
              // La clé unique force l'animation à se relancer à chaque changement de date
              key: ValueKey(_selectedDate),
            )
            // On applique un effet de glissement et de fondu
            .slideX(duration: 250.ms, begin: 0.2, curve: Curves.easeOut)
            .fadeIn(duration: 250.ms),
            ],
          ),
        ),
      ),

      // Flèche de droite
      Opacity(
        opacity: isToday ? 0.0 : 1.0,
        child: IconButton(
          icon: const Icon(Icons.chevron_right, size: 28.0),
          color: Theme.of(context).appBarTheme.iconTheme?.color,
          onPressed: isToday ? null : () {
            _onDateChanged(_selectedDate.add(const Duration(days: 1)));
          },
        ),
      ),

      isToday
            ? const SizedBox(width: 48.0) // Espaceur de la même taille que l'IconButton
            : IconButton(
                icon: const Icon(Icons.today, size: 22),
                tooltip: 'Retour à aujourd\'hui',
                onPressed: () {
                  _onDateChanged(DateTime.now());
                },
              ),
    ],
  );
}

  Widget _buildMealList(BuildContext context, List<FoodItem> mealItems, HomeController controller) {
  if (mealItems.isEmpty) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48.0),
      child: EmptyStateWidget(
        imagePath: 'assets/images/undraw_chef.svg',
        title: 'Ce repas est encore vide',
        subtitle: 'Appuyez sur le bouton "+" pour ajouter votre premier aliment.',
      ),
    );
  }

  // ON REMPLACE LE LISTVIEW.BUILDER PAR UN SINGLECHILDSCROLLVIEW + WRAP
  return ListView.builder(
    padding: const EdgeInsets.all(8.0),
    itemCount: mealItems.length,
    itemBuilder: (context, index) {
      final item = mealItems[index];

      // Chaque aliment est maintenant une Card cliquable et bien structurée
      return Card(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        child: InkWell(
          borderRadius: BorderRadius.circular(12.0),
          onTap: () => HomeDialogs.showFoodItemActionsMenu(
            context,
            item,
            onDelete: () => controller.deleteFoodLogItem(item.id!).then((_) => controller.refreshData(_selectedDate)),
            onAddToFavorites: () => controller.addFoodItemToFavorites(item).then((_) => controller.refreshData(_selectedDate)),
            onEdit: (newQuantity) => controller.updateFoodLogItemQuantity(item.id!, newQuantity).then((_) => controller.refreshData(_selectedDate)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12.0),
            child: Row(
              children: [
                // Colonne principale avec Nom, Quantité et Macros
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.name ?? 'Aliment sans nom',
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${item.quantity?.toStringAsFixed(0) ?? '0'} g',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                      const SizedBox(height: 8),
                      // Affichage clair des 3 macros
                      Row(
                        children: [
                          _buildMacroChip('G ', item.totalCarbs, Colors.blue),
                          const SizedBox(width: 8),
                          _buildMacroChip('P ', item.totalProtein, Colors.red),
                          const SizedBox(width: 8),
                          _buildMacroChip('L ', item.totalFat, Colors.orange),
                        ],
                      )
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                // Les calories, bien visibles à droite
                Text(
                  '${item.totalCalories.toStringAsFixed(0)}\nkcal',
                  textAlign: TextAlign.center,
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
  );
}

Widget _buildMacroChip(String label, double value, Color color) {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.1),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      '$label: ${value.toStringAsFixed(0)} g',
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 10,
      ),
    ),
  );
}
}



