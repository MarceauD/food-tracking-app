import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/food_item.dart';
import 'add_food_screen.dart';
import 'settings_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../helpers/database_helper.dart'; 
import 'package:intl/intl.dart';


class HomeScreen extends StatefulWidget  {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver, TickerProviderStateMixin {
  List<FoodItem> foodItems = [];
  List<FoodItem> _favoriteFoods = [];

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
    _checkDateAndResetIfNeeded();
    _refreshData();
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
    await _loadGoals();
    await _loadFavoriteFoodsFromDb();
    await _loadFoodLogFromDb();
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
  
  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      goalCalories = prefs.getDouble('goalCalories') ?? 1700;
      goalCarbs = prefs.getDouble('goalCarbs') ?? 150;
      goalProtein = prefs.getDouble('goalProtein') ?? 160;
      goalFat = prefs.getDouble('goalFat') ?? 60;
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
              await DatabaseHelper.instance.clearFoodLog();
              _loadFoodLogFromDb(); // Recharger la liste vide
              Navigator.pop(context);
            },
            child: const Text('Confirmer'),
          ),
        ],
      ),
    );
  }

 Widget _buildWelcomeMessage() {
    final hour = DateTime.now().hour;

    String message;
    if (hour < 12) {
      message = 'Bonjour !';
    } else if (hour < 18) {
      message = 'Bon après-midi !';
    } else {
      message = 'Bonsoir !';
    }
    return Text(
      message,
      style: GoogleFonts.poppins(
        color: Colors.black87,
        fontSize: 20, 
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


  Map<MealType, List<FoodItem>> _groupFoodItemsByMeal(List<FoodItem> items) {
    // On initialise une map avec une liste vide pour chaque repas
    final Map<MealType, List<FoodItem>> groupedItems = {
      MealType.breakfast: [],
      MealType.lunch: [],
      MealType.dinner: [],
      MealType.snack: [],
    };

    // On parcourt la liste et on place chaque aliment dans la bonne catégorie
    for (final item in items) {
      if (item.mealType != null) {
        groupedItems[item.mealType]!.add(item);
      }
    }
    return groupedItems;
  }

  // lib/screens/home_screen.dart > _HomeScreenState

  // NOUVELLE MÉTHODE pour construire la liste d'aliments d'un repas
  Widget _buildMealList(List<FoodItem> mealItems) {
    if (mealItems.isEmpty) {
      return const Center(
        child: Text('Aucun aliment pour ce repas.'),
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

  @override
  Widget build(BuildContext context) {
    
    final screenWidth = MediaQuery.of(context).size.width;
    final totalPadding = 16.0 * 4;
    final availableWidth = screenWidth - totalPadding;

    final gaugeRadiusMacro = (availableWidth / 3) / 2; // Calcul dynamique du rayon
    final gaugeRadiusCalories = 90.0;

    final groupedFoodItems = _groupFoodItemsByMeal(foodItems);

    return Scaffold(
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
    body: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      child: 
      Column(
        children: [
          Card(
            elevation:4.0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10.0)),
            child: Padding(
              padding: const EdgeInsets.all(10.0),
              child: Column(
                children: [
                  // La colonne que vous aviez déjà pour les jauges
                  Column(
                    children: [
                      CircularPercentIndicator(
                radius: gaugeRadiusCalories,
                lineWidth: 12.0,
                percent: (totalCalories / goalCalories).clamp(0, 1),
                center: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      totalCalories.toStringAsFixed(0),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 36),
                    ),
                    const Text(
                      'KCAL CONSOMMÉES', // J'ai ajusté le texte pour plus de clarté
                      style: TextStyle(fontSize: 10, color: Colors.grey),
                    ),
                  ],
                ),
            progressColor: Colors.green,
            backgroundColor: Colors.green.shade100,
            circularStrokeCap: CircularStrokeCap.round,
          ),
          const SizedBox(height: 7.0),
          Text(
                '${(goalCalories - totalCalories).clamp(0, goalCalories).toStringAsFixed(0)} restantes',
                style: const TextStyle(fontSize: 14, color: Colors.black54),
              ), 
                    ],
          ),
          // Jauges macronutriments en ligne
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMacroIndicator(
                  radius: gaugeRadiusMacro,
                  iconData: Icons.local_fire_department_outlined,
                  label: 'Glucides',
                  value: totalCarbs,
                  max: goalCarbs,
                  color: Colors.blue),
              _buildMacroIndicator(
                  radius: gaugeRadiusMacro,
                  iconData: Icons.fitness_center_outlined,
                  label: 'Protéines',
                  value: totalProtein,
                  max: goalProtein,
                  color: Colors.red),
              _buildMacroIndicator(
                  radius: gaugeRadiusMacro,
                  iconData: Icons.water_drop_outlined,
                  label: 'Lipides',
                  value: totalFat,
                  max: goalFat,
                  color: Colors.orange),
            ],
            ),
          ]
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_favoriteFoods.isNotEmpty) 
            Card(
              elevation:2.0,
              shape : RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                  'Favoris',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: _favoriteFoods.map((food) {
                    // On enveloppe le bouton dans un GestureDetector
                    return GestureDetector(
                      onLongPress: () {
                        // L'appui long déclenche la suppression
                        _showDeleteFavoriteDialog(food);
                      },
                      child: ElevatedButton(
                        // L'appui court (onPressed) garde son comportement normal
                        onPressed: () => _showAddFavoriteToMealDialog(food),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[200],
                          foregroundColor: Colors.black,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        ),
                        child: Text(food.name ?? 'Sans nom'),
                      ),
                    );
                  }).toList(),
                ),
                ],
              ),
            ),
          ),
  
          const SizedBox(height: 16),

          Expanded(
            child: Card(
              elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                clipBehavior: Clip.antiAlias, // Important pour que les coins arrondis coupent bien le contenu
                child: Column(
                  children: [
                    // 1. LA BARRE D'ONGLETS
                    TabBar(
                      controller: _tabController,
                      labelColor: Theme.of(context).colorScheme.primary,
                      unselectedLabelColor: Colors.grey,
                      tabs: const [
                        Tab(text: 'Petit-déj'),
                        Tab(text: 'Déjeuner'),
                        Tab(text: 'Dîner'),
                        Tab(text: 'Collation'),
                      ],
                    ),
                    const Divider(height: 1),

                    // 2. LA VUE AVEC LE CONTENU SWIPABLE
                    Expanded(
                      child: TabBarView(
                        controller: _tabController,
                        children: [
                          // On génère une vue pour chaque type de repas
                          _buildMealList(groupedFoodItems[MealType.breakfast]!),
                          _buildMealList(groupedFoodItems[MealType.lunch]!),
                          _buildMealList(groupedFoodItems[MealType.dinner]!),
                          _buildMealList(groupedFoodItems[MealType.snack]!),
                        ],
                      ),
                    ),
                  ],
                ),
            ),
          ),
            
        const SizedBox(height:80),
      ],
    ),
  ),
  floatingActionButton: FloatingActionButton(
    onPressed: _showMealSelection, // <-- On appelle le menu
    child: const Icon(Icons.add),
    ),
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
          value.toStringAsFixed(0) + ' g / ' + max.toStringAsFixed(0) + ' g',
          style: TextStyle(
            color: color,
            fontSize: radius * 0.2, // Taille proportionnelle
            fontWeight: FontWeight.bold,
           ),
          ),
        ],
      ),
    );
  }
}
