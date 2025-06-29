import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../controllers/settings_controller.dart';


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

  final _controller = SettingsController();

  bool _autoResetEnabled = true;
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
      _autoResetEnabled = settings['autoResetEnabled'] as bool;
      _isLoading = false;
    });
  }

  Future<void> _saveAutoResetSetting(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoResetEnabled', value);
    setState(() {
      _autoResetEnabled = value;
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
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objectifs enregistrés')),
      );
      Navigator.pop(context, true); // On signale que les données ont changé
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Objectifs nutritionnels')),
      body: _isLoading
      ? Center(child: CircularPercentIndicator(radius: 40))
      : Padding(
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
                child: const Text('Enregistrer les objectifs'),
              ),
              const Divider(height: 40),

              SwitchListTile(
              title: const Text('Réinitialisation journalière'),
              subtitle: const Text('Vider le journal automatiquement chaque jour à minuit.'),
              value: _autoResetEnabled,
              onChanged: _saveAutoResetSetting,
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
