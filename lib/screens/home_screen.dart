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

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  List<FoodItem> foodItems = [];
  List<FoodItem> _favoriteFoods = [];

  // Valeurs max en dur
  double goalCalories = 1700;
  double goalProtein = 160;
  double goalCarbs = 150;
  double goalFat = 60;

  @override
  void initState() {
    super.initState();
    _refreshData();
    WidgetsBinding.instance.addObserver(this);
    _checkDateAndResetIfNeeded();
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

  Future<void> _showQuantityDialog(FoodItem favorite) async {
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

  @override
  Widget build(BuildContext context) {
    
    final screenWidth = MediaQuery.of(context).size.width;
    final totalPadding = 16.0 * 4;
    final availableWidth = screenWidth - totalPadding;

    final gaugeRadiusMacro = (availableWidth / 3) / 2; // Calcul dynamique du rayon
    final gaugeRadiusCalories = 90.0;

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
          padding: const EdgeInsets.all(2),
          child: 
          ListView(
            children: [
              Card(
                elevation:4.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
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
                      label: 'Glucides',
                      value: totalCarbs,
                      max: goalCarbs,
                      color: Colors.blue),
                  _buildMacroIndicator(
                      radius: gaugeRadiusMacro,
                      label: 'Protéines',
                      value: totalProtein,
                      max: goalProtein,
                      color: Colors.red),
                  _buildMacroIndicator(
                     radius: gaugeRadiusMacro,
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
                          onPressed: () => _showQuantityDialog(food),
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
              
              Card(
                elevation: 2.0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Column(
                    children: [
                      const ListTile( // Un titre pour la section
                        leading: Icon(Icons.menu_book_rounded, color: Colors.green),
                        title: Text('Journal du jour', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                      ),
                const Divider(),
                      foodItems.isEmpty
                          ? const Padding(
                              padding: EdgeInsets.all(24.0),
                              child: Text('Aucun aliment ajouté aujourd\'hui'),
                            )
                          : ListView.builder(
                              // Important pour que le ListView dans un autre ListView fonctionne
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(), 
                              itemCount: foodItems.length,
                              itemBuilder: (context, index) {
                                final item = foodItems[index];
                                return ListTile(
                                  title: Text(item.name ?? 'Aliment sans nom'),
                            subtitle: Text(
                                '${item.quantity}g — ${item.totalCalories.toStringAsFixed(0)} kcal'),
                            trailing: Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text('${item.totalProtein.toStringAsFixed(1)} g P'),
                                Text('${item.totalCarbs.toStringAsFixed(1)} g G'),
                                Text('${item.totalFat.toStringAsFixed(1)} g L'),
                              ],
                            ),
                          );
                        },
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
        onPressed: () async {
          final shouldRefresh = await Navigator.push<bool>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddFoodScreen(),
            ),
          );
  
          // Si on a reçu 'true', c'est qu'un ajout a été fait
          if (shouldRefresh == true && mounted) {
            _refreshData(); // On recharge toutes les données
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildMacroIndicator({
    required double radius,
    required String label,
    required double value,
    required double max,
    required Color color,
  }) {
    double percent = (value / max).clamp(0, 1);

    return Column(
      children: [
        CircularPercentIndicator(
          radius : radius,
          lineWidth: 8,
          percent: percent,
          center: Text('${value.toStringAsFixed(0)}\n/\n${max.toStringAsFixed(0)}',
              textAlign: TextAlign.center,
              style:
                  TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 14)),
          progressColor: color,
          backgroundColor: color.withAlpha((0.3 * 255).toInt()),
          circularStrokeCap: CircularStrokeCap.round,
        ),
        const SizedBox(height: 8),
        Text(label, style: TextStyle(color: color, fontWeight: FontWeight.bold)),
      ],
    );
  }
}
