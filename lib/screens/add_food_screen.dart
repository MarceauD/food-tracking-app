import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../models/portion.dart';
import '../helpers/database_helper.dart';
import 'barcode_scanner_screen.dart';
import '../controllers/add_food_controller.dart';
import 'dart:async'; // Pour gérer le délai de recherche
import 'package:openfoodfacts/openfoodfacts.dart'; // Pour utiliser le type Product
import '../widgets/common/secondary_button.dart';
import '../widgets/common/primary_button.dart';
import '../models/meal_type.dart';

class AddFoodScreen extends StatefulWidget {

  final FoodItem? initialFoodItem;
  final MealType mealType;
  final DateTime selectedDate;

  const AddFoodScreen({super.key, required this.mealType, required this.selectedDate, this.initialFoodItem});
  
  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _controller = AddFoodController();
  final _formKey = GlobalKey<FormState>();

  // --- NOUVELLES VARIABLES D'ÉTAT POUR LA RECHERCHE ---
  final _searchController = TextEditingController();
  bool _useGrams = true; // Par défaut, on saisit en grammes
  List<Portion> _availablePortions = [];
  Portion? _selectedPortion;
  final _portionQuantityController = TextEditingController(text: '1');
  List<FoodItem> _usdaResults = [];
  List<Product> _openFoodFactsResults = [];
  List<FoodItem> _historyResults = [];
  bool _isSearching = false; // Pour afficher un indicateur de chargement
  Timer? _debounce; // Pour ne pas lancer une recherche à chaque lettre tapée

  // Contrôleurs de champ
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void initState() {
    super.initState();
    // Si un aliment initial est fourni (par le scanner), on remplit les champs
    _searchController.addListener(_onSearchChanged);
    if (widget.initialFoodItem != null) {
      _populateFields(widget.initialFoodItem!);
    }
  }

  void _populateFields(FoodItem food) {
    _nameController.text = food.name ?? '';
    _caloriesController.text = food.caloriesPer100g.toStringAsFixed(1);
    _proteinController.text = food.proteinPer100g.toStringAsFixed(1);
    _carbsController.text = food.carbsPer100g.toStringAsFixed(1);
    _fatController.text = food.fatPer100g.toStringAsFixed(1);
    _quantityController.text = food.quantity?.toStringAsFixed(0) ?? '0';
  }

  @override
  void dispose() {
    // Nettoyage
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _quantityController.dispose();
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    _debounce?.cancel();

    super.dispose();
  }

  void _onSearchChanged() {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      if (_searchController.text.length < 2) {
        setState(() {
          _historyResults = [];
          _usdaResults = [];
          _openFoodFactsResults = [];
        });
        return;
      }
      setState(() { _isSearching = true; });

      final historyFuture = _controller.searchUserHistory(_searchController.text);
      final usdaFuture = _controller.searchGenericFoods(_searchController.text);
      final openFoodFactsFuture = _controller.searchProducts(_searchController.text);

      final results = await Future.wait([historyFuture, usdaFuture, openFoodFactsFuture]);

      if (mounted) {
        setState(() {
          _historyResults = results[0] as List<FoodItem>;
          _usdaResults = results[1] as List<FoodItem>;
          _openFoodFactsResults = results[2] as List<Product>;
          _isSearching = false;
        });
      }
    });
  }

  
  Future<void> _handleFoodSelection({
  required FoodItem foodItem,
  Product? originalProduct, // Le produit original, s'il vient d'OpenFoodFacts
}) async {
  // 1. On pré-remplit les champs
  _populateFields(foodItem);

  // 2. On appelle le controller pour trouver les portions
  final portions = await _controller.findAvailablePortions(
    foodItem.name.toString(),
    originalProduct: originalProduct,
  );

  // 3. On met à jour l'interface
  setState(() {
    _availablePortions = portions;
    _selectedPortion = portions.first;
    _useGrams = false;

    // On nettoie les résultats de recherche
    _usdaResults = [];
    _openFoodFactsResults = [];
    _searchController.clear();
  });

  FocusScope.of(context).unfocus();
}

Future<void> _showAddPortionDialog() async {
    final portionNameController = TextEditingController();
    final portionWeightController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    return showDialog<void>(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('Ajouter une portion'),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                TextFormField(
                  controller: portionNameController,
                  decoration: const InputDecoration(labelText: 'Nom de la portion (ex: 1 tranche)'),
                  validator: (value) => value!.isEmpty ? 'Champ requis' : null,
                ),
                TextFormField(
                  controller: portionWeightController,
                  decoration: const InputDecoration(labelText: 'Poids en grammes'),
                  keyboardType: TextInputType.number,
                  validator: (value) => value!.isEmpty || double.tryParse(value) == null ? 'Poids invalide' : null,
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: const Text('Annuler'),
              onPressed: () => Navigator.of(context).pop(),
            ),
            ElevatedButton(
              child: const Text('Sauvegarder'),
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final foodName = _nameController.text;
                  final portionName = portionNameController.text;
                  final weight = double.parse(portionWeightController.text);

                  await _controller.saveUserPortion(foodName, portionName, weight);
                  Navigator.of(context).pop();

                  // On rafraîchit la liste des portions disponibles
                  final updatedPortions = await _controller.findAvailablePortions(
                    foodName // On passe un FoodItem temporaire
                  );
                  setState(() {
                    _availablePortions = updatedPortions;
                    _selectedPortion = updatedPortions.firstWhere((p) => p.name == portionName);
                  });
                }
              },
            ),
          ],
        );
      },
    );
  }

  Future<void> _addToFavorites(FoodItem item) async {
    final success = await _controller.addFoodToFavorites(item);

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Nouveau favori enregistré')),
      );
      // On ferme l'écran uniquement en cas de succès
      Navigator.pop(context, true);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Cet aliment est déjà dans vos favoris')),
      );
    }
  }

  void _submitForm() async {    
     if (_formKey.currentState!.validate()) {
      double finalQuantity;
      // On calcule la quantité finale en grammes
      if (_useGrams) {
        finalQuantity = double.parse(_quantityController.text);
      } else {
        final portionCount = double.tryParse(_portionQuantityController.text) ?? 1.0;
        final portionWeight = _selectedPortion?.weightInGrams ?? 0.0;
        finalQuantity = portionCount * portionWeight; 
      }

      final item = FoodItem(
        name: _nameController.text.isEmpty ? 'Aliment' : _nameController.text,
        mealType: widget.mealType,
        caloriesPer100g: double.parse(_caloriesController.text),
        proteinPer100g: double.parse(_proteinController.text),
        carbsPer100g: double.parse(_carbsController.text),
        fatPer100g: double.parse(_fatController.text),
        quantity: finalQuantity,
        date: widget.selectedDate,
      );

      await DatabaseHelper.instance.createFoodLog(item);
  }
      if (context.mounted) {
        Navigator.pop(context, true); // On retourne 'true' pour rafraîchir la home page
      }
      
  }

  Widget _buildQuantityInput() {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Grammes')),
                  ButtonSegment(value: false, label: Text('Portions')),
                ],
                selected: {_useGrams},
                onSelectionChanged: (selection) => setState(() => _useGrams = selection.first),
              ),
            ),
            // NOUVEAU BOUTON pour ajouter une portion
            if (!_useGrams)
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                tooltip: 'Ajouter une portion personnalisée',
                onPressed: _showAddPortionDialog,
              ),
          ],
        ),
        const SizedBox(height: 10),
        if (_useGrams)
          _buildTextField(label: 'Quantité (g)', controller: _quantityController, isNumeric: true)
        else if (_availablePortions.isNotEmpty)
          DropdownButtonFormField<Portion>(
            value: _selectedPortion,
            items: _availablePortions.map((Portion portion) {
              return DropdownMenuItem<Portion>(
                value: portion,
                child: Text(portion.name),
              );
            }).toList(),
            onChanged: (Portion? newValue) => setState(() => _selectedPortion = newValue),
            decoration: const InputDecoration(labelText: 'Choisir une portion'),
          )
        else
          const Text("Aucune portion disponible pour cet aliment."),
      ],
    );
  }

  Widget _buildTextField(
    {required String label,
    required TextEditingController controller,
    bool isNumeric = false}) {
  return TextFormField(
    controller: controller,
    keyboardType:
        isNumeric ? const TextInputType.numberWithOptions(decimal: true) : TextInputType.text,
    decoration: InputDecoration(labelText: label),
    validator: (value) {
      if (isNumeric) {
        if (value == null || value.isEmpty) return 'Champ requis';
        final parsed = double.tryParse(value);
        if (parsed == null || parsed < 0) return 'Nombre invalide';
      }
      return null;
    },
  );
  }

  void _scanBarcode() async {
    // On navigue vers l'écran de scan et on attend un résultat
    final FoodItem? scannedFood = await Navigator.push(
      context,
      MaterialPageRoute(
        // On passe notre instance de controller à l'écran de scan
        builder: (context) => BarcodeScannerScreen(controller: _controller),
      ),
    );

    // Si on a reçu un aliment en retour (scan réussi et données valides)
    if (scannedFood != null && mounted) {
      // On utilise la méthode qui pré-remplit les champs du formulaire
      _populateFields(scannedFood);
    }
  }


@override
Widget build(BuildContext context) {
  return Scaffold(
    appBar: AppBar(
      title: const Text('Ajouter un aliment'),
      // On place le bouton de scan ici pour un accès facile et permanent
      actions: [
        IconButton(
          icon: const Icon(Icons.qr_code_scanner),
          tooltip: 'Scanner un code-barres',
          onPressed: _scanBarcode, 
        ),
      ],
    ),
    body: Column(
      children: [
        // --- 1. LA BARRE DE RECHERCHE ---
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              labelText: 'Rechercher un aliment...',
              hintText: 'Ex: Yaourt nature, banane...',
              suffixIcon: _isSearching
                  ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2.0))
                  : const Icon(Icons.search),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12.0),
              ),
            ),
          ),
        ),

        // --- 2. LA ZONE DE CONTENU DYNAMIQUE ---
        // On utilise Expanded pour que cette zone prenne tout l'espace restant
        Expanded(
          child:
              // Si on a des résultats de recherche, on les affiche
              _openFoodFactsResults.isNotEmpty
                  ? _buildSearchResultsList()
                  // Sinon, on affiche le formulaire de saisie manuelle
                  : _buildManualEntryForm(),
        ),
      ],
    ),
  );
}

// lib/screens/add_food_screen.dart > _AddFoodScreenState

// NOUVELLE MÉTHODE qui construit la liste des résultats de recherche
Widget _buildSearchResultsList() {
    return ListView(
      children: [
        if (_historyResults.isNotEmpty) ...[
          const ListTile(title: Text('Vos Habitudes', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.purple))),
          ..._historyResults.map((item) => ListTile(
            leading: const Icon(Icons.history, color: Colors.purple),
            title: Text(item.name ?? ''),
            onTap: () => _handleFoodSelection(foodItem: item),
          )),
          const Divider(),
        ],
        if (_usdaResults.isNotEmpty) ...[
          const ListTile(title: Text('Aliments de Base', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.green))),
          ..._usdaResults.map((item) => ListTile(
            leading: const Icon(Icons.eco_outlined, color: Colors.green),
            title: Text(item.name ?? ''),
            subtitle: Text('${item.caloriesPer100g.toInt()} kcal pour 100 g'),
            onTap: () => _handleFoodSelection(foodItem: item),
          )),
          const Divider(),
        ],
        if (_openFoodFactsResults.isNotEmpty) ...[
          const ListTile(title: Text('Produits du Commerce', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue))),
          ..._openFoodFactsResults.map((product) {
            final foodItem = convertProductToFoodItem(product);
            if (foodItem == null) return const SizedBox.shrink();
            return ListTile(
              leading: SizedBox(width: 56, height: 56, child: product.imageFrontSmallUrl != null ? Image.network(product.imageFrontSmallUrl!) : const Icon(Icons.shopping_cart_outlined)),
              title: Text(foodItem.name ?? ''),
              subtitle: Text(product.brands ?? 'Marque inconnue'),
              onTap: () => _handleFoodSelection(foodItem: foodItem, originalProduct: product),
            );
          }),
        ],
      ],
    );
  }

FoodItem? convertProductToFoodItem(Product product) {
  final calories = product.nutriments?.getValue(Nutrient.energyKCal, PerSize.oneHundredGrams);
  if (calories == null) return null;

  return FoodItem(
    name: product.productName ?? 'Produit inconnu',
    caloriesPer100g: calories,
    proteinPer100g: product.nutriments?.getValue(Nutrient.proteins, PerSize.oneHundredGrams) ?? 0.0,
    carbsPer100g: product.nutriments?.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams) ?? 0.0,
    fatPer100g: product.nutriments?.getValue(Nutrient.fat, PerSize.oneHundredGrams) ?? 0.0,
    quantity: 100.0,
  );
}

Widget _buildManualEntryForm() {
  // On reprend le code de votre ancien 'body' ici
  return Padding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
    child: Form(
      key: _formKey,
      child: ListView(
        children: [
          Center(
            child: Text(
              'Ou entrez les valeurs manuellement',
              style: TextStyle(color: Colors.grey[600]),
            ),
          ),
          const SizedBox(height: 16),
          _buildTextField(label: 'Nom', controller: _nameController),
          _buildTextField(label: 'Calories / 100g', controller: _caloriesController, isNumeric: true),
          _buildTextField(label: 'Protéines / 100g', controller: _proteinController, isNumeric: true),
          _buildTextField(label: 'Glucides / 100g', controller: _carbsController, isNumeric: true),
          _buildTextField(label: 'Lipides / 100g', controller: _fatController, isNumeric: true),
          const SizedBox(height: 24),
          _buildQuantityInput(),
          const SizedBox(height: 16),
          
          // On affiche le bon champ de saisie de manière conditionnelle
                   
          const SizedBox(height: 20),
          PrimaryButton(
            text: 'Ajouter au journal',
            onPressed: _submitForm,
          ),
          SecondaryButton(
            text: 'Ajouter aux favoris',
            icon: Icons.star_border_outlined,
            onPressed: () {
              if (_formKey.currentState!.validate()) {
                final item = FoodItem(
                  name: _nameController.text.isEmpty ? 'Aliment' : _nameController.text,
                  mealType: widget.mealType,
                  caloriesPer100g: double.parse(_caloriesController.text),
                  proteinPer100g: double.parse(_proteinController.text),
                  carbsPer100g: double.parse(_carbsController.text),
                  fatPer100g: double.parse(_fatController.text),
                  quantity: 100,
                  date: widget.selectedDate,
                );
                _addToFavorites(item);
              }
            },
          ),
        ],
      ),
    ),
  );
}

}


