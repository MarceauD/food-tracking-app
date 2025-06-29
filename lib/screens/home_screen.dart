import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/food_item.dart';
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
    
    // 1. Vérifier si l'option est activée
    final bool autoResetEnabled = prefs.getBool('autoResetEnabled') ?? true;
    if (!autoResetEnabled) {
      _refreshData(); // On charge les données sans réinitialiser
      return;
    }

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
  }

  Future<void> _addSavedMealToLog(SavedMeal savedMeal, MealType mealType) async {
  final now = DateTime.now();
  // On parcourt chaque aliment du repas sauvegardé
  for (final itemTemplate in savedMeal.items) {
    // Pour chaque, on crée une nouvelle entrée de log avec la bonne date et le bon repas
    final itemToLog = itemTemplate.copyWith(
      date: now,
      mealType: mealType,
      forceIdToNull: true, // Crucial pour obtenir un nouvel ID dans la BDD
    );
    await DatabaseHelper.instance.createFoodLog(itemToLog);
  }
  _refreshData(); // On rafraîchit toute l'interface
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
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
              onPressed: () async {
                // On appelle la nouvelle méthode du helper
                await DatabaseHelper.instance.deleteFavorite(favoriteId);
                
                if (context.mounted) {
                  Navigator.of(context).pop(); // Ferme la popup
                  _loadFavoriteFoodsFromDb(); // Recharge la liste des favoris pour rafraîchir l'UI
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
  nameController.text = 'Mon ${mealType.name} habituel';
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
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text('Sauvegarder'),
            onPressed: () async {
              if (nameController.text.isNotEmpty) {
                await _controller.saveCurrentMeal(nameController.text, items);
                if (context.mounted) {
                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Repas sauvegardé !')),
                  );
                }
              }
            },
          ),
        ],
      );
    },
  );

  
}

// lib/screens/home_screen.dart > _HomeScreenState

Future<void> _showAddSavedMealToMealDialog(SavedMeal meal) async {
  return showModalBottomSheet<void>(
    context: context,
    builder: (BuildContext context) {
      return Wrap(
        children: <Widget>[
          ListTile(
            title: Text(
              'Ajouter "${meal.name}" à...',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          const Divider(thickness: 1),

          // On transforme le onTap en fonction asynchrone
          ListTile(
            leading: const Icon(Icons.wb_sunny_outlined),
            title: const Text('Petit-déjeuner'),
            onTap: () async { // <-- async
              Navigator.pop(context); // On ferme le menu d'abord
              await _addSavedMealToLog(meal, MealType.breakfast); // <-- On ATTEND la fin de l'opération
            },
          ),

          ListTile(
            leading: const Icon(Icons.lunch_dining_outlined),
            title: const Text('Déjeuner'),
            onTap: () async { // <-- async
              Navigator.pop(context);
              await _addSavedMealToLog(meal, MealType.lunch); // <-- await
            },
          ),

          ListTile(
            leading: const Icon(Icons.dinner_dining_outlined),
            title: const Text('Dîner'),
            onTap: () async { // <-- async
              Navigator.pop(context);
              await _addSavedMealToLog(meal, MealType.dinner); // <-- await
            },
          ),

          ListTile(
            leading: const Icon(Icons.fastfood_outlined),
            title: const Text('Collation'),
            onTap: () async { // <-- async
              Navigator.pop(context);
              await _addSavedMealToLog(meal, MealType.snack); // <-- await
            },
          ),
        ],
      );
    },
  );
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
            TextButton(
              child: const Text('Annuler'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
            ElevatedButton(
              child: const Text('Ajouter'),
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
    builder: (BuildContext context) {
      return Wrap(
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
      );
    },
    );
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
              await _controller.clearLog(); // APPEL AU CONTROLLER
              _refreshData(); // On rafraîchit l'UI
              Navigator.pop(context);
            },
            child: const Text('Confirmer'),
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
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              child: const Text('Supprimer'),
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
      style: GoogleFonts.poppins(
        color: Colors.black87,
        fontSize: 22, 
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildDateDisplay() {
    final String formattedDate = DateFormat('EEEE d MMMM', 'fr_FR').format(DateTime.now());

    return Text(
      formattedDate[0].toUpperCase() + formattedDate.substring(1),
      
      style: GoogleFonts.lato(
        fontSize: 14,
        color: Colors.black54, // On passe en blanc-cassé pour la lisibilité sur fond coloré
      ),
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
      builder: (context) {
        return Wrap(
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
        );
      },
      );
    }
 
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final totalPadding = 16.0 * 4;
    final availableWidth = screenWidth - totalPadding;

    final gaugeRadiusMacro = (availableWidth / 3) / 2; // Calcul dynamique du rayon
    final gaugeRadiusCalories = 90.0;


    final groupedFoodItems = _controller.groupFoodItemsByMeal(foodItems);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: PreferredSize(
        preferredSize: const Size.fromHeight(80.0),
      child: AppBar(
        elevation: 0,
        backgroundColor: Colors.transparent,
        title: Column(
            mainAxisAlignment: MainAxisAlignment.center, // Centre verticalement les textes
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildWelcomeMessage(),
              _buildDateDisplay(),
            ],
          ),
          centerTitle: false,
        actions: [
          IconButton(
        color: Colors.black54,
        icon: const Icon(Icons.delete),
        tooltip: 'Effacer tous les aliments',
        onPressed: _clearFoodItems,
       ),
       IconButton(
        color: Colors.black54,
        icon: const Icon(Icons.settings),
        tooltip: 'Objectifs',
        onPressed: () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => const SettingsScreen()),
              );
    
            // Si le résultat est 'true', cela veut dire qu'on a sauvegardé
            if (result == true) {
            // On recharge les objectifs (et tout le reste si besoin)
            _refreshData(); 
            }
          },
        ),
      ],
    ),
    ),
    body: 
    Container(
    decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Colors.green.withOpacity(0.1), // Vert très léger en haut
            const Color(0xFFF7F9F9),     // Le blanc cassé de notre thème en bas
          ],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
      ),
    child:
    Padding(
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
              gaugeRadiusMacro: gaugeRadiusMacro,
              gaugeRadiusCalories: gaugeRadiusCalories,
              buildMacroIndicator: _buildMacroIndicator, // On passe la fonction de construction
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
   ),
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: _showMealSelection, // <-- On appelle le menu
    child: const Icon(Icons.add),
    ),
    );
}

Widget _buildMealList(List<FoodItem> mealItems) {
  if (mealItems.isEmpty) {
    return const EmptyStateWidget(
        imagePath: 'assets/images/undraw_healthy-habit_2ata.svg', // Remplacez par le nom de votre fichier
        title: 'Ce repas est encore vide',
        subtitle: 'Appuyez sur le bouton "+" pour ajouter votre premier aliment.',
      );
  }
  return ListView.builder(
    padding: EdgeInsets.zero, // Enlève le padding par défaut du ListView
    itemCount: mealItems.length,
    itemBuilder: (context, index) {
      final item = mealItems[index];
      // On retourne le même ListTile que vous aviez avant
      return ListTile(
        title: Text(item.name ?? 'Aliment sans nom'),
        subtitle: Text('${item.quantity}g'),
        trailing: Text('${item.totalCalories.toStringAsFixed(0)} kcal'),
      );
    },
  );
}

Widget _buildMacroIndicator({
  required double radius,
  required IconData iconData,
  required String label,
  required double value,
  required double max,
  required Color color,
}) {
  return CircularPercentIndicator(
    radius: radius,
    lineWidth: 9.0, // On peut se permettre une ligne un peu plus épaisse
    percent: (value / max).clamp(0, 1),
    backgroundColor: color.withAlpha(50), // Fond plus subtil
    progressColor: color,
    circularStrokeCap: CircularStrokeCap.round,
    center: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(iconData, color: color, size: radius * 0.45), // Taille proportionnelle au rayon
        
        const SizedBox(height: 4),

        Text(
          '${value.toStringAsFixed(0)} g',
          style: TextStyle(
            color: Colors.black87,
            fontSize: radius * 0.28, // Légèrement plus grand
            fontWeight: FontWeight.w600, // Semi-gras pour la clarté
          ),
        ),
        Text(
          '/ ${max.toStringAsFixed(0)} g', // On sépare la cible pour un style différent
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: radius * 0.18, // Plus petit
          ),
          ),
        ],
      ),

      animation: true,
      animateFromLastPercent: true,
      animationDuration: 800, // Un peu plus rapide pour une sensation de réactivité
      curve: Curves.easeOut,
    );
  }
}
