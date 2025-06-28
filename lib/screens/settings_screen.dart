import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caloriesController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadGoals();
  }

  Future<void> _loadGoals() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _caloriesController.text = (prefs.getDouble('goalCalories') ?? 2100).toString();
      _carbsController.text = (prefs.getDouble('goalCarbs') ?? 258).toString();
      _proteinController.text = (prefs.getDouble('goalProtein') ?? 103).toString();
      _fatController.text = (prefs.getDouble('goalFat') ?? 68).toString();
    });
  }

  Future<void> _saveGoals() async {
    if (_formKey.currentState!.validate()) {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble('goalCalories', double.parse(_caloriesController.text));
      await prefs.setDouble('goalCarbs', double.parse(_carbsController.text));
      await prefs.setDouble('goalProtein', double.parse(_proteinController.text));
      await prefs.setDouble('goalFat', double.parse(_fatController.text));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objectifs enregistrés')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objectifs nutritionnels')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: ListView(
            children: [
              _buildTextField(_caloriesController, 'Calories (kcal)'),
              _buildTextField(_carbsController, 'Glucides (g)'),
              _buildTextField(_proteinController, 'Protéines (g)'),
              _buildTextField(_fatController, 'Lipides (g)'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _saveGoals,
                child: const Text('Enregistrer'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String label) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        decoration: InputDecoration(labelText: label, border: const OutlineInputBorder()),
        validator: (value) {
          if (value == null || value.isEmpty) return 'Champ obligatoire';
          if (double.tryParse(value) == null) return 'Entrez un nombre valide';
          return null;
        },
      ),
    );
  }
}
