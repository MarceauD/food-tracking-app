import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/settings_controller.dart';
import '../widgets/common/primary_button.dart';

class SettingsScreen extends StatefulWidget {

  final VoidCallback onSettingsChanged;

  const SettingsScreen({super.key,required this.onSettingsChanged,});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _caloriesController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();

  final _controller = SettingsController();

  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final settings = await _controller.loadSettings();
    if (!mounted) return;
    setState(() {
      _caloriesController.text = (settings['goalCalories'] as double).toString();
      _carbsController.text = (settings['goalCarbs'] as double).toString();
      _proteinController.text = (settings['goalProtein'] as double).toString();
      _fatController.text = (settings['goalFat'] as double).toString();
      _isLoading = false;
    });
  }

  Future<void> _saveGoals() async {
    if (_formKey.currentState!.validate()) {
      final goals = {
        'calories': double.parse(_caloriesController.text),
        'carbs': double.parse(_carbsController.text),
        'protein': double.parse(_proteinController.text),
        'fat': double.parse(_fatController.text),
      };

      await _controller.saveGoals(goals);

      if (!mounted) return;
      
      widget.onSettingsChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objectifs enregistrés')),
      );
      

    }
  }

  @override
  Widget build(BuildContext context) {
    // L'AppBar est gérée par HomeScreen, nous construisons uniquement le corps.
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          // On utilise un ListView pour que l'écran soit scrollable sur les petits téléphones
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                // --- CARTE 1 : LES OBJECTIFS ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // On utilise le style de titre du thème
                          Text(
                            'Mes Objectifs Nutritionnels',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(_caloriesController, 'Calories (kcal)'),
                          const SizedBox(height: 12),
                          _buildTextField(_carbsController, 'Glucides (g)'),
                          const SizedBox(height: 12),
                          _buildTextField(_proteinController, 'Protéines (g)'),
                          const SizedBox(height: 12),
                          _buildTextField(_fatController, 'Lipides (g)'),
                          const SizedBox(height: 24),
                          // On utilise notre bouton personnalisé
                          PrimaryButton(
                            text: 'Enregistrer les modifications',
                            onPressed: _saveGoals,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 24),
              ],
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
