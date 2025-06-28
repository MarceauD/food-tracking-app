import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'package:flutter/material.dart';
import '../models/food_item.dart';
import '../helpers/database_helper.dart';

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
    await DatabaseHelper.instance.createFavorite(item);
    
    if(context.mounted) {
      Navigator.pop(context, true); // On retourne 'true' pour signaler un changement
    }
  }

  void _submitForm() async {    
     if (_formKey.currentState!.validate()) {
      final item = FoodItem(
        name: _nameController.text.isEmpty ? 'Aliment' : _nameController.text,
        caloriesPer100g: double.parse(_caloriesController.text),
        proteinPer100g: double.parse(_proteinController.text),
        carbsPer100g: double.parse(_carbsController.text),
        fatPer100g: double.parse(_fatController.text),
        quantity: double.parse(_quantityController.text),
        date: DateTime.now(),
      );

      await DatabaseHelper.instance.createFoodLog(item);
  }
      if (context.mounted) {
        Navigator.pop(context, true); // On retourne 'true' pour rafraîchir la home page
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
                  // Le template du favori est basé sur les valeurs pour 100g,
                  // mais on peut garder la quantité entrée comme suggestion par défaut.
                  final item = FoodItem(
                    name: _nameController.text,
                    caloriesPer100g: double.parse(_caloriesController.text),
                    carbsPer100g: double.parse(_carbsController.text),
                    proteinPer100g: double.parse(_proteinController.text),
                    fatPer100g: double.parse(_fatController.text),
                    // La quantité sauvegardée ici servira de valeur par défaut dans la popup
                    quantity: double.parse(_quantityController.text), 
                    date: DateTime.now(),
                  );
                  
                  // On utilise la méthode du helper qui évite les doublons
                  DatabaseHelper.instance.createFavorite(item);

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
