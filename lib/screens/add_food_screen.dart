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
    // Annule le timer précédent à chaque nouvelle lettre
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    
    // Démarre un nouveau timer de 500ms
    _debounce = Timer(const Duration(milliseconds: 500), () async {
      // Une fois le timer écoulé, on lance la recherche
      if (_searchController.text.length < 3) {
        setState(() { _openFoodFactsResults = []; });
        return;
      }
      setState(() { _isSearching = true; });

      final usdaFuture = _controller.searchGenericFoods(_searchController.text);
      final openFoodFactsFuture = _controller.searchProducts(_searchController.text);

      final results = await Future.wait([usdaFuture, openFoodFactsFuture]);
      final usdaResults = results[0] as List<FoodItem>;
      final openFoodFactsResults = results[1] as List<Product>;
    
      final openFoodFactsItems = openFoodFactsResults.map((product) {
      // On récupère les calories pour vérifier que le produit est valide
      final calories = product.nutriments?.getValue(Nutrient.energyKCal, PerSize.oneHundredGrams);

      // On retourne un FoodItem complet
      return FoodItem(
        // On utilise les données du 'product' de l'API
        name: product.productName ?? 'Produit inconnu',
        caloriesPer100g: calories ?? 0.0,
        proteinPer100g: product.nutriments?.getValue(Nutrient.proteins, PerSize.oneHundredGrams) ?? 0.0,
        carbsPer100g: product.nutriments?.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams) ?? 0.0,
        fatPer100g: product.nutriments?.getValue(Nutrient.fat, PerSize.oneHundredGrams) ?? 0.0,
        // On met une quantité par défaut, car c'est un modèle
        quantity: 100.0,
      );
    })
    // On ne garde que les aliments qui ont bien des données caloriques
    .where((item) => item.caloriesPer100g > 0) 
    .toList();

      if (mounted) {
        setState(() {
          _usdaResults = results[0] as List<FoodItem>;
          _openFoodFactsResults = _openFoodFactsResults = results[1] as List<Product>;
          _isSearching = false;
        });
      }
    });
  }

  void _onGenericFoodSelected(FoodItem item) {
    _populateFields(item);
    // On cache les résultats de recherche
    setState(() {
      _usdaResults = [];
      _openFoodFactsResults = [];
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  void _onApiProductSelected(Product product) async {
    // On convertit le Product en FoodItem
    final foodItem = convertProductToFoodItem(product);

    if (foodItem != null) {
      _populateFields(foodItem);
      // On charge les portions possibles pour ce nouvel aliment
      final portions = await _controller.getPortionsForFood(foodItem.name ?? '');
      setState(() {
        _availablePortions = portions;
        if (portions.isNotEmpty) {
          _selectedPortion = portions.first;
          _useGrams = false;
        } else {
          _useGrams = true;
        }
      });
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Données nutritionnelles manquantes pour ce produit.'))
      );
    }
    
    // On cache les résultats de recherche
    setState(() {
      _usdaResults = [];
      _openFoodFactsResults = [];
      _searchController.clear();
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _onProductSelected(Product product) async {
    // On utilise la même logique que pour le scan pour pré-remplir les champs
    _populateFieldsFromProduct(product);

    List<Portion> portions = [];

    final String? servingSizeFromApi = product.servingSize;
    if (servingSizeFromApi != null && servingSizeFromApi.isNotEmpty) {
      // On essaie d'extraire le poids en grammes de la chaîne de texte (ex: "50 g")
      final RegExp regex = RegExp(r'(\d+(\.\d+)?)');
      final Match? match = regex.firstMatch(servingSizeFromApi);
      if (match != null) {
        final double? weight = double.tryParse(match.group(1)!);
        if (weight != null) {
          print('ℹ️ Portion trouvée via API : $servingSizeFromApi');
          portions.add(Portion(name: '1 portion ($servingSizeFromApi)', weightInGrams: weight));
        }
      }
    }

    if (portions.isEmpty) {
      print('ℹ️ Aucune portion API, recherche dans la base de données locale...');
      portions = await _controller.getPortionsForFood(product.productName ?? '');
    }

    // On vide la recherche pour cacher la liste des résultats
    setState(() {
      _availablePortions = portions;
      if (portions.isNotEmpty) {
        _selectedPortion = portions.first;
        _useGrams = false; // On passe en mode portion
      } else {
        _useGrams = true; // On reste en mode grammes
      }
      _searchController.clear();
      _openFoodFactsResults = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _populateFieldsFromProduct(Product product) {
    final calories = product.nutriments?.getValue(Nutrient.energyKCal, PerSize.oneHundredGrams);
    // On ne pré-remplit que si les données de base sont là
    if (calories != null) {
      _nameController.text = product.productName ?? '';
      _caloriesController.text = calories.toStringAsFixed(2);
      _proteinController.text = (product.nutriments?.getValue(Nutrient.proteins, PerSize.oneHundredGrams) ?? 0.0).toStringAsFixed(2);
      _carbsController.text = (product.nutriments?.getValue(Nutrient.carbohydrates, PerSize.oneHundredGrams) ?? 0.0).toStringAsFixed(2);
      _fatController.text = (product.nutriments?.getValue(Nutrient.fat, PerSize.oneHundredGrams) ?? 0.0).toStringAsFixed(2);
      _quantityController.text = '100';
    } else {
      // Si le produit est incomplet, on informe l'utilisateur
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Ce produit n\'a pas de données nutritionnelles complètes.'))
      );
    }
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

      const SizedBox(height: 24),
      // Sélecteur pour choisir entre Grammes et Portions
      ToggleButtons(
        isSelected: [_useGrams, !_useGrams],
        onPressed: (index) {
          // On ne peut pas désactiver les portions s'il n'y en a pas de disponible
          if (index == 1 && _availablePortions.isEmpty) return;
          setState(() {
            _useGrams = index == 0;
          });
        },
        borderRadius: BorderRadius.circular(8.0),
        children: const [
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Grammes')),
          Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Portions')),
        ],
      ),
      const SizedBox(height: 16),

      // On affiche le champ de saisie correspondant au mode choisi
      _useGrams
          ? _buildTextField(label: 'Quantité (g)', controller: _quantityController, isNumeric: true)
          : Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _portionQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<Portion>(
                    value: _selectedPortion,
                    items: _availablePortions.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (portion) => setState(() => _selectedPortion = portion),
                    decoration: const InputDecoration(labelText: 'Portion'),
                  ),
                ),
              ],
            ),
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
  final totalItemCount = _usdaResults.length + _openFoodFactsResults.length;

  return ListView.builder(
    itemCount: totalItemCount,
    itemBuilder: (context, index) {
      // Si l'index correspond à un résultat de la base locale/USDA
      if (index < _usdaResults.length) {
        final item = _usdaResults[index];
        return ListTile(
          leading: Container(
            width: 56, height: 56,
            decoration: BoxDecoration(color: Colors.green[50], borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.eco_outlined, color: Colors.green),
          ),
          title: Text(item.name ?? 'Aliment générique'),
          subtitle: Text('${item.caloriesPer100g.toStringAsFixed(0)} kcal pour 100g'),
          // ON APPELLE DIRECTEMENT LA MÉTHODE QUI GÈRE LES FoodItem
          onTap: () => _onGenericFoodSelected(item),
        );
      } 
      // Sinon, c'est un résultat de Open Food Facts
      else {
        final product = _openFoodFactsResults[index - _usdaResults.length];
        final imageUrl = product.imageFrontSmallUrl;
        
        return ListTile(
          leading: SizedBox(
            width: 56, height: 56,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8.0),
              child: (imageUrl != null && imageUrl.isNotEmpty)
                  ? Image.network(imageUrl, fit: BoxFit.cover, /*... loading & error builders ...*/)
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(Icons.fastfood_outlined, color: Colors.grey),
                    ),
            ),
          ),
          title: Text(product.productName ?? 'Produit sans nom'),
          subtitle: Text(product.brands ?? 'Marque inconnue'),
          // ON APPELLE LA MÉTHODE QUI GÈRE LES Product DE L'API
          onTap: () {
            final foodItem = convertProductToFoodItem(product);
            if (foodItem != null) {
              _onGenericFoodSelected(foodItem);
            } else {
              // Gérer le cas où le produit est incomplet
               ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Données nutritionnelles manquantes pour ce produit.'))
              );
            }
          },
        );
      }
    },
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
          ToggleButtons(
            isSelected: [_useGrams, !_useGrams],
            onPressed: (index) {
              if (index == 1 && _availablePortions.isEmpty) return;
              setState(() { _useGrams = index == 0; });
            },
            borderRadius: BorderRadius.circular(8.0),
            children: const [
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Grammes')),
              Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Portions')),
            ],
          ),
          const SizedBox(height: 16),
          
          // On affiche le bon champ de saisie de manière conditionnelle
          if (_useGrams)
            _buildTextField(label: 'Quantité (g)', controller: _quantityController, isNumeric: true)
          else
            Row(
              children: [
                Expanded(
                  flex: 2,
                  child: TextFormField(
                    controller: _portionQuantityController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  flex: 3,
                  child: DropdownButtonFormField<Portion>(
                    value: _selectedPortion,
                    items: _availablePortions.map((p) => DropdownMenuItem(value: p, child: Text(p.name))).toList(),
                    onChanged: (portion) => setState(() => _selectedPortion = portion),
                    decoration: const InputDecoration(labelText: 'Portion'),
                  ),
                ),
              ],
            ),
            
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


