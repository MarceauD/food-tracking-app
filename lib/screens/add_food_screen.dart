import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/food_item.dart';

class AddFoodScreen extends StatefulWidget {
  const AddFoodScreen({super.key});

  @override
  State<AddFoodScreen> createState() => _AddFoodScreenState();
}

class _AddFoodScreenState extends State<AddFoodScreen> {
  final _formKey = GlobalKey<FormState>();

  // Contrôleurs de champ
  final _nameController = TextEditingController();
  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _quantityController = TextEditingController();

  @override
  void dispose() {
    // Nettoyage
    _nameController.dispose();
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _quantityController.dispose();
    super.dispose();
  }

  Future<void> _addToFavorites(FoodItem item) async {
    final prefs = await SharedPreferences.getInstance();
    final List<String> favoriteJsonList = prefs.getStringList('favoriteFoods') ?? [];

    // Convertir l’aliment en Map, puis en JSON string
    final newItemJson = jsonEncode({
      'name': item.name,
      'calories': item.caloriesPer100g,
      'carbs': item.carbsPer100g,
      'protein': item.proteinPer100g,
      'fat': item.fatPer100g,
      'quantity': item.quantity,
    });

    // Ajouter uniquement s’il n’existe pas déjà (facultatif)
    if (!favoriteJsonList.contains(newItemJson)) {
        favoriteJsonList.add(newItemJson);
        await prefs.setStringList('favoriteFoods', favoriteJsonList);
      }

  print('✅ Favori ajouté, fermeture de AddFoodScreen');
  if(context.mounted) {
    Navigator.pop(context, {
      'foodItem': item,
      'favoriAjoute': true, // ou false selon ce que tu fais
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      final item = FoodItem(
        name: _nameController.text.isEmpty ? null : _nameController.text,
        caloriesPer100g: double.parse(_caloriesController.text),
        proteinPer100g: double.parse(_proteinController.text),
        carbsPer100g: double.parse(_carbsController.text),
        fatPer100g: double.parse(_fatController.text),
        quantity: double.parse(_quantityController.text),
        date: DateTime.now(),
      );

      Navigator.pop(context, {
      'foodItem': item,
      'favoriAjoute': false, // ou false selon ce que tu fais
      });
      
    }
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ajouter un aliment'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(label: 'Nom', controller: _nameController),
              _buildTextField(label: 'Calories / 100g', controller: _caloriesController, isNumeric: true),
              _buildTextField(label: 'Protéines / 100g', controller: _proteinController, isNumeric: true),
              _buildTextField(label: 'Glucides / 100g', controller: _carbsController, isNumeric: true),
              _buildTextField(label: 'Lipides / 100g', controller: _fatController, isNumeric: true),
              _buildTextField(label: 'Quantité consommée (g)', controller: _quantityController, isNumeric: true),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _submitForm,
                child: const Text('Ajouter'),
              ),
              ElevatedButton.icon(
                onPressed: () {
                if (_formKey.currentState!.validate()) {
                  final item = FoodItem(
                    name: _nameController.text,
                    caloriesPer100g: double.parse(_caloriesController.text),
                    carbsPer100g: double.parse(_carbsController.text),
                    proteinPer100g: double.parse(_proteinController.text),
                    fatPer100g: double.parse(_fatController.text),
                    date: DateTime.now(),
                    quantity: double.parse(_quantityController.text), //modifier la quantité de l'aliment au moment de l'ajout du favori dans le menu
                  );

                  _addToFavorites(item);

                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Ajouté aux favoris')),
                  );
                }
              },
                icon: const Icon(Icons.star),
                label: const Text('Ajouter aux favoris'),
                style: ElevatedButton.styleFrom(
                backgroundColor: Colors.orange,
              ),
            ),
          ],
        ),
      ),
    ),
  );
} 
}
