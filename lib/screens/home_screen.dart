import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../models/daily_summary.dart';
import '../models/user_profile.dart';
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
import '../models/meal_type.dart';
import '../helpers/tip_service.dart';
import '../widgets/common/notification_service.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter/services.dart';
import 'meal_estimator_screen.dart';

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

  DateTime _selectedDate = DateTime.now(); // <-- AJOUTEZ CETTE LIGNE
  
  final GlobalKey<StatsScreenState> _statsScreenKey = GlobalKey<StatsScreenState>();

  // Valeurs max en dur
  double goalCalories = 1700;
  double goalProtein = 160;
  double goalCarbs = 150;
  double goalFat = 60;

  String _userName = 'Utilisateur';

  UserProfile? _userProfile;
  String _currentTip = "";

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

    _loadUserProfile().then((_) {
      // On génère un premier conseil après avoir chargé le profil
      _updateTip();
    });

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
      _controller.checkAndTriggerEveningNotification();
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
      await _saveCurrentDaySummary();
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

  Future<void> _loadUserProfile() async {
    final profile = await _controller.loadProfile();

    final prefs = await SharedPreferences.getInstance();
    if (prefs.getBool('coachingEnabled') ?? false) {
      await NotificationService().scheduleWeeklyReportReminder();
    }

    if (profile != null && mounted) {
      setState(() {
        _userProfile = profile;
        _userName = profile.name;
      });
    }
  }

  Future<void> _saveCurrentDaySummary() async {
  // On calcule les totaux par repas
  double calculateMealCalories(MealType mealType) {
    return foodItems
        .where((item) => item.mealType == mealType)
        .fold(0, (sum, item) => sum + item.totalCalories);
  }
  
  final breakfastCalories = calculateMealCalories(MealType.breakfast);
  final lunchCalories = calculateMealCalories(MealType.lunch);
  final dinnerCalories = calculateMealCalories(MealType.dinner);
  final snackCalories = calculateMealCalories(MealType.snack);

  // On collecte les types de repas uniques
  final Set<MealType> loggedMealsToday = foodItems
      .where((item) => item.mealType != null)
      .map((item) => item.mealType!)
      .toSet();

  // On crée l'objet résumé
  final summary = DailySummary(
    date: _selectedDate,
    totalCalories: totalCalories,
    totalCarbs: totalCarbs,
    totalProtein: totalProtein,
    totalFat: totalFat,
    goalCalories: goalCalories,
    loggedMeals: loggedMealsToday,
    breakfastCalories: breakfastCalories,
    lunchCalories: lunchCalories,
    dinnerCalories: dinnerCalories,
    snackCalories: snackCalories,
  );

  // On appelle le controller pour sauvegarder
  await _controller.saveOrUpdateSummary(summary);
  print("📈 Résumé du jour sauvegardé (via la méthode optimisée).");
}

  Future<void> _refreshData() async {
    // Les méthodes de chargement appellent maintenant le controller
    // et mettent à jour l'état de l'UI avec le résultat
    final goals = await _controller.loadGoals();
    final favorites = await _controller.loadFavorites();
    final savedMeals = await _controller.loadSavedMeals();
    final log = await _controller.loadFoodLogForDate(_selectedDate);

    final profile = await _controller.loadProfile();
      if (profile != null) {
       setState(() {
      _userName = profile.name;
      });
    }
  
    setState(() {
      goalCalories = goals['calories']!;
      goalCarbs = goals['carbs']!;
      goalProtein = goals['protein']!;
      goalFat = goals['fat']!;
      _favoriteFoods = favorites;
      _savedMeals = savedMeals;
      foodItems = log;
    });

    await _controller.updateSummaryForDate(_selectedDate);

    _updateTip();
  }

  void _updateTip() {
    final goals = {
      'calories': goalCalories,
      'carbs': goalCarbs,
      'protein': goalProtein,
      'fat': goalFat,
    };
    final newTip = TipService.generateTip(_userProfile, foodItems, goals);
    setState(() {
      _currentTip = newTip;
    });
  }

  Future<void> _addSavedMealToLog(SavedMeal savedMeal, MealType mealType) async {
  final now = _selectedDate;
  for (final itemTemplate in savedMeal.items) {
    final itemToLog = itemTemplate.copyWith(
      date: now,
      mealType: mealType,
      forceIdToNull: true,
    );
    await DatabaseHelper.instance.createFoodLog(itemToLog);
    HapticFeedback.lightImpact();

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
          setState(() {
            _selectedDate = _selectedDate.subtract(const Duration(days: 1));
            _refreshData();
          });
        },
      ),
      
      // La date, qui reste cliquable pour ouvrir le calendrier
      Expanded(
        child: GestureDetector(
          onTap: () async {
            // La logique du DatePicker ne change pas
            final DateTime? picked = await showDatePicker(context: context,
            initialDate: _selectedDate,
            firstDate: DateTime(2025), // Limite pour ne pas aller trop loin
            lastDate: DateTime.now(),);
            if (picked != null && picked != _selectedDate) {
              setState(() {
                _selectedDate = picked;
                _refreshData();
              });
            }
          },
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
            setState(() {
              _selectedDate = _selectedDate.add(const Duration(days: 1));
              _refreshData();
            });
          },
        ),
      ),

      isToday
            ? const SizedBox(width: 48.0) // Espaceur de la même taille que l'IconButton
            : IconButton(
                icon: const Icon(Icons.today, size: 22),
                tooltip: 'Retour à aujourd\'hui',
                onPressed: () {
                  setState(() {
                    _selectedDate = DateTime.now();
                    _refreshData();
                  });
                },
              ),
    ],
  );
}

Future<void> _loadFavoriteFoodsFromDb() async {
  final favorites = await DatabaseHelper.instance.getFavorites();
  setState(() {
    _favoriteFoods = favorites;
  });
}

Future<void> _loadFoodLogFromDb() async {
  final log = await DatabaseHelper.instance.getFoodLogForDate(_selectedDate);
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
                    date: _selectedDate,
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

  Future<void> _showClearAllDialog(int tabIndex) async {
  // On détermine sur quel onglet on se trouve pour adapter le message
    final bool isFavoritesTab = tabIndex == 0;
    final String title = isFavoritesTab ? 'Vider les favoris ?' : 'Vider les repas ?';
    final String content = isFavoritesTab 
        ? 'Toutes vos favoris seront supprimés. Cette action est irréversible.'
        : 'Tous vos repas sauvegardés seront supprimés. Cette action est irréversible.';

    return showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(title),
          content: Text(content),
          actions: [
            SecondaryButton(text: 'Annuler', onPressed: () => Navigator.pop(context)),
            PrimaryButton(
              text: 'Tout supprimer',
              onPressed: () async {
                if (isFavoritesTab) {
                  await _controller.clearAllFavorites();
                } else {
                  await _controller.clearAllSavedMeals();
                }
                if(context.mounted) Navigator.pop(context);
                _refreshData(); // On rafraîchit pour voir la liste vide
              },
            ),
          ],
        );
      },
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
  String greeting;

  if (hour < 12) {
    greeting = 'Bonjour';
  } else if (hour < 18) {
    greeting = 'Bon après-midi';
  } else {
    greeting = 'Bonsoir';
  }

  // --- LA CONDITION EST ICI ---
  // Si le nom est la valeur par défaut, on ne l'affiche pas.
  final String welcomeText = (_userName == 'Utilisateur')
      ? '$greeting !'
      : '$greeting, $_userName !';

  return Text(
    welcomeText,
    style: Theme.of(context).textTheme.headlineSmall,
  );
 }

  Widget _buildDateDisplay() {
    final String formattedDate = DateFormat('EEEE d MMMM', 'fr_FR').format(_selectedDate);

    return Text(
      formattedDate[0].toUpperCase() + formattedDate.substring(1),
      
      style: Theme.of(context).textTheme.bodySmall,
    );
  }

  
  Future<void> _showFoodItemActionsMenu(FoodItem item) async {

  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (context) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 24.0, horizontal: 16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            // On crée un widget personnalisé pour chaque bouton d'action
            _buildActionMenuItem(
              context: context,
              icon: Icons.edit_outlined,
              label: 'Modifier',
              onTap: () {
                Navigator.pop(context);
                _showEditQuantityDialog(item);
              },
            ),
            _buildActionMenuItem(
              context: context,
              icon: Icons.star_border_outlined,
              label: 'Favori',
              onTap: () async {
                Navigator.pop(context);
                final success = await _controller.addFoodItemToFavorites(item);
                if (!mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(success 
                      ? '"${item.name}" ajouté aux favoris !' 
                      : 'Cet aliment est déjà dans vos favoris.'),
                  ),
                );
                _refreshData();
              },
              ),
              _buildActionMenuItem(
              context: context,
              icon: Icons.delete_outline,
              label: 'Supprimer',
              color: Colors.red.shade700, // Couleur pour l'action destructive
              onTap: () {
                Navigator.pop(context);
                _controller.deleteFoodLogItem(item.id!);
                setState(() {
                  foodItems.remove(item);
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('"${item.name}" supprimé.')),
                );
              },
            ),
          ]
            ),
      );
    },
  );
}

void _showMealSelection() {
  // Fonction d'aide pour naviguer vers le wizard avec le bon type de repas
  void _navigateToEstimator(MealType mealType) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => MealEstimatorScreen(
          mealType: mealType, // On passe le repas choisi
          selectedDate: _selectedDate,
        ),
      ),
    ).then((result) {
      // Quand on revient, on ajoute l'aliment estimé
      if (result != null && result is FoodItem) {
        _controller.submitFood(result).then((_) {
          _refreshData();
        });
      }
    });
  }

  // Affiche le menu principal
  showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (ctx) {
      return SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewPadding.bottom),
          child: Wrap(
            children: [
              // Option "Estimer un plat"
              ListTile(
                leading: const Icon(Icons.auto_fix_high_outlined),
                title: const Text('Estimer un plat'),
                onTap: () {
                  Navigator.pop(ctx); // On ferme le premier menu

                  // ON OUVRE UN SECOND MENU POUR CHOISIR LE REPAS
                  showModalBottomSheet(
                    context: context,
                    builder: (mealCtx) {
                      return Wrap(
                        children: MealType.values.map((meal) {
                          return ListTile(
                            leading: Icon(_getIconForMeal(meal)),
                            title: Text(meal.frenchName),
                            onTap: () {
                              Navigator.pop(mealCtx); // On ferme le second menu
                              _navigateToEstimator(meal); // On lance le wizard
                            },
                          );
                        }).toList(),
                      );
                    },
                  );
                },
              ),
              const Divider(thickness: 1),

              // Le reste des options pour l'ajout classique
              ...MealType.values.map((meal) {
                return ListTile(
                  leading: Icon(_getIconForMeal(meal)),
                  title: Text(meal.frenchName),
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddFoodScreen(mealType: meal, selectedDate: _selectedDate),
                      ),
                    ).then((_) => _refreshData());
                  },
                );
              }).toList(),
            ],
          ),
        ),
      );
    },
  );
}

  IconData _getIconForMeal(MealType meal) {
    switch (meal) {
      case MealType.breakfast:
        return Icons.wb_sunny_outlined;
      case MealType.lunch:
        return Icons.lunch_dining_outlined;
      case MealType.dinner:
        return Icons.nightlight_round_outlined;
      case MealType.snack:
        return Icons.fastfood_outlined;
    }
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
            flexibleSpace: SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16.0),
                child: _buildJournalHeader(),
              ),
            ),
            
          ),
        );
    }
  }

  Widget _buildJournalHeader() {
    final now = DateTime.now();
    final bool isToday = _selectedDate.year == now.year &&
                       _selectedDate.month == now.month &&
                      _selectedDate.day == now.day;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildWelcomeMessage(), 
        _buildDateNavigation()// La ligne avec les flèches et la date
      ],
    );
  }

  Widget _buildJournalView() {
    
    final groupedFoodItems = _controller.groupFoodItemsByMeal(foodItems);
    final gaugeRadiusCalories = 90.0;

    final now = DateTime.now();
    final bool isToday = _selectedDate.year == now.year &&
                       _selectedDate.month == now.month &&
                       _selectedDate.day == now.day;

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
        if (isToday)
          if (_currentTip.isNotEmpty)
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
                        _currentTip,
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

          MealJournalCard(
              tabController: _tabController,
              groupedFoodItems: groupedFoodItems,
              buildMealList: _buildMealList,
              onSaveMeal: _showSaveMealDialog,
              onCopyMeal: (mealType) {_showCopyMealConfirmation(mealType);},// <-- ON PASSE LA NOUVELLE MÉTHODE
            ),

            const SizedBox(height: 16),

          SizedBox(
            height: 300,
            child: QuickAddCard(
              favoriteFoods: _favoriteFoods,
              savedMeals: _savedMeals,
              onFavoriteTap: _showAddFavoriteToMealDialog,
              onSavedMealTap: _showAddSavedMealToMealDialog,
              onFavoriteLongPress: _showDeleteFavoriteDialog,
              onSavedMealLongPress: _showDeleteSavedMealDialog,
              onClearAllTapped: _showClearAllDialog,
            ),
          ),
  
          const SizedBox(height: 16),

          
          
      ],
    ),
   );
  }
 
  @override
  Widget build(BuildContext context) {
    final List<Widget> pages = <Widget>[
      _buildJournalView(), 
      StatsScreen(key: _statsScreenKey),
      SettingsScreen(onGoalsChanged: _refreshData, 
        onProfileChanged: _loadUserProfile,),// Page 2 : L'écran des paramètres
    ];

    return Scaffold(
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
          if (index == 1) { // Si l'utilisateur clique sur l'onglet "Progrès"
            _statsScreenKey.currentState?.loadData(); // On appelle la méthode de chargement
          }
          setState(() {
            _selectedIndex = index;
          });
        },
      ),
      floatingActionButton: _selectedIndex == 0
          ? FloatingActionButton(
              onPressed: _showMealSelection,
              heroTag: 'fab_home',
              child: const Icon(Icons.add),
            )
          : null,
    );
}

Widget _buildActionMenuItem({
  required BuildContext context,
  required IconData icon,
  required String label,
  required VoidCallback onTap,
  Color? color,
}) {
  // On utilise la couleur primaire du thème par défaut
  final iconColor = color ?? Theme.of(context).colorScheme.primary;

  return InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12.0),
    child: Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Un cercle autour de l'icône pour un look plus soigné
          Container(
            padding: const EdgeInsets.all(12.0),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: iconColor.withOpacity(0.1),
            ),
            child: Icon(icon, color: iconColor, size: 28),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
              color: color, // Le texte "Supprimer" sera aussi en rouge
            ),
          ),
        ],
      ),
    ),
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
      imagePath: 'assets/images/undraw_chef.svg',
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
            return ListTile(
        title: Text(
          item.name ?? 'Aliment sans nom',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          '${item.quantity != null ? item.quantity!.toStringAsFixed(0) : '0'} g  •  G: ${item.totalCarbs.toStringAsFixed(0)} g P: ${item.totalProtein.toStringAsFixed(0)} g L: ${item.totalFat.toStringAsFixed(0)} g',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        trailing: Text(
          '${item.totalCalories.toStringAsFixed(0)} kcal',
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.primary,
          ),
        ),
        // Le clic court ouvre maintenant notre nouveau menu d'actions
        onTap: () => _showFoodItemActionsMenu(item),
      ).animate().fadeIn(duration: 400.ms).slideY(begin: 0.5);
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
                builder: (context) => AddFoodScreen(mealType: currentMealType, selectedDate: _selectedDate),
              ),
            ).then((_) => _refreshData());
          },
        ),
      ),
    ],
  );
}

Future<void> _showCopyMealConfirmation(MealType mealType) async {
  return showDialog<void>(
    context: context,
    builder: (BuildContext context) {
      return AlertDialog(
        title: const Text('Copier le repas d\'hier ?'),
        content: Text('Voulez-vous ajouter tous les aliments du ${mealType.frenchName.toLowerCase()} d\'hier à votre journal d\'aujourd\'hui ?'),
        actions: <Widget>[
          TextButton(
            child: const Text('Annuler'),
            onPressed: () => Navigator.of(context).pop(),
          ),
          ElevatedButton(
            child: const Text('Confirmer'),
            onPressed: () async {
              Navigator.of(context).pop(); // On ferme la popup
              await _controller.copyMealFromYesterday(mealType, _selectedDate);
              _refreshData(); // On rafraîchit l'interface

              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${mealType.frenchName} d\'hier copié !')),
                );
              }
            },
          ),
        ],
      );
    },
  );
}
}