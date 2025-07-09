import 'package:flutter/material.dart';
import '../controllers/settings_controller.dart';
import '../widgets/common/primary_button.dart';
import '../widgets/common/secondary_button.dart';
import 'package:provider/provider.dart'; // <-- Importer Provider
import '../providers/theme_provider.dart'; // <-- Importer le provider
import '../models/user_profile.dart'; // Importer le modèle et les enums
import 'package:intl/intl.dart';
import '../helpers/nutrition_calculator.dart';
import '../controllers/home_controller.dart';
import '../widgets/common/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';


class SettingsScreen extends StatefulWidget {

  final VoidCallback onGoalsChanged;
  final VoidCallback onProfileChanged; 

  const SettingsScreen({
    super.key,
    required this.onGoalsChanged,
    required this.onProfileChanged, // AJOUTER AU CONSTRUCTEUR
  });

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final _goalsformKey = GlobalKey<FormState>();
  final _profileFormKey = GlobalKey<FormState>();

  final _caloriesController = TextEditingController();
  final _carbsController = TextEditingController();
  final _proteinController = TextEditingController();
  final _fatController = TextEditingController();
  final _nameController = TextEditingController();
  Objective _selectedObjective = Objective.maintain;
  final _coachEmailController = TextEditingController(); // Nouveau contrôleur
  
  Gender _selectedGender = Gender.male;
  DateTime? _dateOfBirth;
  final _heightController = TextEditingController();
  final _weightController = TextEditingController();
  ActivityLevel _selectedActivityLevel = ActivityLevel.moderate;

  bool _coachingEnabled = false;

  final _controller = SettingsController();

  bool _isLoading = true;


  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
    final settings = await _controller.loadSettings();
    final profile = await _controller.loadProfile();
    final prefs = await SharedPreferences.getInstance();
    _coachingEnabled = prefs.getBool('coachingEnabled') ?? false;
    _coachEmailController.text = prefs.getString('coachEmail') ?? 'coach@gmail.com'; // On charge l'email

    if (profile != null) {
      setState(() {
        _nameController.text = profile.name;
        _selectedGender = profile.gender;
        _dateOfBirth = profile.dateOfBirth;
        _heightController.text = profile.height.toString();
        _weightController.text = profile.weight.toString();
        _selectedActivityLevel = profile.activityLevel;
        _selectedObjective = profile.objective;
      });

    if (!mounted) return;

    setState(() {
      _caloriesController.text = (settings['goalCalories'] as double).toString();
      _carbsController.text = (settings['goalCarbs'] as double).toString();
      _proteinController.text = (settings['goalProtein'] as double).toString();
      _fatController.text = (settings['goalFat'] as double).toString();
      _isLoading = false;
    });
    }
    } catch (e, stackTrace) {
      // SI UNE ERREUR SE PRODUIT, ON L'AFFICHE DANS LA CONSOLE
      print('🚨 ERREUR LORS DU CHARGEMENT DES PARAMÈTRES : $e');
      print('STACK TRACE : $stackTrace');
      // On peut aussi afficher un message à l'utilisateur
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Erreur lors du chargement du profil.')),
        );
      }
    } finally {
      // QUE L'OPÉRATION RÉUSSISSE OU ÉCHOUE, ON ARRÊTE LE CHARGEMENT
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _suggestGoals() async {
  // On s'assure que le profil est valide avant de calculer
  if (_profileFormKey.currentState!.validate() && _dateOfBirth != null) {
    // On crée un objet profil temporaire avec les données actuelles des champs
    final profile = UserProfile(
      name: _nameController.text,
      gender: _selectedGender,
      dateOfBirth: _dateOfBirth!,
      height: double.tryParse(_heightController.text) ?? 0,
      weight: double.tryParse(_weightController.text) ?? 0,
      activityLevel: _selectedActivityLevel,
      objective: _selectedObjective, // <-- On sauvegarde l'objectif
    );

    // On utilise notre calculateur
    final calculatedGoals = NutritionCalculator.calculateGoals(profile);

    // On met à jour les contrôleurs de texte avec les nouvelles valeurs
    setState(() {
      _caloriesController.text = calculatedGoals['calories']!.toStringAsFixed(0);
      _carbsController.text = calculatedGoals['carbs']!.toStringAsFixed(0);
      _proteinController.text = calculatedGoals['protein']!.toStringAsFixed(0);
      _fatController.text = calculatedGoals['fat']!.toStringAsFixed(0);
    });

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Objectifs suggérés en fonction de votre profil.')),
    );
  } else {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Veuillez remplir votre profil correctement avant de calculer les objectifs.'),
        backgroundColor: Colors.red,
      ),
    );
  }
}

  Future<void> _saveGoals() async {
    if (_goalsformKey.currentState!.validate()) {
      final goals = {
        'calories': double.parse(_caloriesController.text),
        'carbs': double.parse(_carbsController.text),
        'protein': double.parse(_proteinController.text),
        'fat': double.parse(_fatController.text),
      };

      await _controller.saveGoals(goals);

      if (!mounted) return;
      
      widget.onGoalsChanged();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Objectifs enregistrés')),
      );
      

    }
  }

  Future<void> _saveProfile() async {
    // On vérifie la validité des champs du profil (à faire dans le Form)
    // Pour l'instant, on sauvegarde directement
    if (!_profileFormKey.currentState!.validate()) {
      return; // Arrête la fonction si les champs sont invalides
    }

    if (_dateOfBirth != null) {
      final profile = UserProfile(
        name: _nameController.text,
        gender: _selectedGender,
        dateOfBirth: _dateOfBirth!,
        height: double.tryParse(_heightController.text) ?? 0,
        weight: double.tryParse(_weightController.text) ?? 0,
        activityLevel: _selectedActivityLevel,
        objective: _selectedObjective, // <-- On sauvegarde l'objectif
      );
      await _controller.saveProfile(profile);

      widget.onProfileChanged();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profil enregistré !')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez sélectionner une date de naissance.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _dateOfBirth ?? DateTime(2000),
      firstDate: DateTime(1920),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _dateOfBirth) {
      setState(() {
        _dateOfBirth = picked;
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    final themeProvider = Provider.of<ThemeProvider>(context);
    
    // L'AppBar est gérée par HomeScreen, nous construisons uniquement le corps.
    return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          // On utilise un ListView pour que l'écran soit scrollable sur les petits téléphones
          : ListView(
              padding: const EdgeInsets.all(16.0),
              children: [
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(key: _profileFormKey, 
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mon Profil', style: Theme.of(context).textTheme.titleLarge),
                        const SizedBox(height: 16),
                        _buildTextField(_nameController, "Nom ou pseudo"),
                        
                        // Sélecteur de genre
                        SegmentedButton<Gender>(
                          segments: const [
                            ButtonSegment<Gender>(
                              value: Gender.male,
                              icon: Icon(Icons.male_outlined), // Icône pour Homme
                            ),
                            ButtonSegment<Gender>(
                              value: Gender.female,
                              icon: Icon(Icons.female_outlined), // Icône pour Femme
                            ),
                          ],
                          selected: {_selectedGender},
                          onSelectionChanged: (newSelection) {
                            setState(() { _selectedGender = newSelection.first; });
                          },
                        ),
                        const SizedBox(height: 16),
                        // Sélecteur de date de naissance
                        TextFormField(
                          readOnly: true, // Pour ne pas pouvoir écrire dedans
                          controller: TextEditingController(
                            text: _dateOfBirth == null
                                ? 'Non définie'
                                : DateFormat('d MMMM yyyy', 'fr_FR').format(_dateOfBirth!),
                          ),
                          decoration: const InputDecoration(
                            labelText: 'Date de naissance',
                            suffixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () => _selectDate(context),
                        ),
                        const SizedBox(height: 12),
                        _buildTextField(_heightController, "Taille (cm)", isNumeric: true),
                        _buildTextField(_weightController, "Poids (kg)", isNumeric: true),
                        const SizedBox(height: 12),
                        // Sélecteur de niveau d'activité
                        DropdownButtonFormField<ActivityLevel>(
                          value: _selectedActivityLevel,
                          decoration: const InputDecoration(labelText: 'Niveau d\'activité'),
                          items: ActivityLevel.values.map((level) {
                            // On peut créer une extension pour traduire les niveaux d'activité
                            return DropdownMenuItem(value: level, child: Text(level.frenchName));
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedActivityLevel = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<Objective>(
                          value: _selectedObjective,
                          decoration: const InputDecoration(labelText: 'Mon Objectif'),
                          items: Objective.values.map((obj) {
                            return DropdownMenuItem(value: obj, child: Text(obj.frenchName));
                          }).toList(),
                          onChanged: (value) {
                            setState(() {
                              _selectedObjective = value!;
                            });
                          },
                        ),
                        const SizedBox(height: 24),
                        PrimaryButton(text: 'Enregistrer le profil', onPressed: _saveProfile),
                      ],
                    ),
                  ),
                  ),
                ),
                
                Padding(
                padding: const EdgeInsets.symmetric(vertical: 16.0),
                child: Center(
                  child: SecondaryButton(
                    text: 'Suggérer mes objectifs',
                    icon: Icons.lightbulb_outline,
                    onPressed: _suggestGoals,
                  ),
                ),
              ),

                const SizedBox(height: 24),
                // --- CARTE 1 : LES OBJECTIFS ---
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Form(
                      key: _goalsformKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // On utilise le style de titre du thème
                          Text(
                            'Mes Objectifs Nutritionnels',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          const SizedBox(height: 16),
                          _buildTextField(_caloriesController, 'Calories (kcal)', isNumeric: true),
                          const SizedBox(height: 12),
                          _buildTextField(_carbsController, 'Glucides (g)', isNumeric: true),
                          const SizedBox(height: 12),
                          _buildTextField(_proteinController, 'Protéines (g)',isNumeric: true),
                          const SizedBox(height: 12),
                          _buildTextField(_fatController, 'Lipides (g)', isNumeric: true),
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

                const SizedBox(height: 24),

                // BOUTON POUR GENERATION ALEATOIRES DE DONNEES DE TEST
              
              // CARTE DE COACHING
              Card(
                child: Column(
                  children: [
                    SwitchListTile(
                      title: Text(
                        'Activer le mode coaching',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      value: _coachingEnabled,
                      activeColor: Theme.of(context).colorScheme.primary,
                      onChanged: (bool value) async {
                        setState(() => _coachingEnabled = value);
                      final prefs = await SharedPreferences.getInstance();
                      await prefs.setBool('coachingEnabled', value);
                      if (value) {
                  // ...et qu'aucun email de coach n'est déjà sauvegardé...
                  if (prefs.getString('coachEmail') == null || prefs.getString('coachEmail')!.isEmpty) {
                    const defaultEmail = 'coach@gmail.com';
                    // ...alors on sauvegarde l'email par défaut...
                    await _controller.saveCoachEmail(defaultEmail);
                    // ...et on met à jour l'affichage dans le champ de texte.
                    _coachEmailController.text = defaultEmail;
                  }
                  
                  // On programme la notification
                  await NotificationService().scheduleWeeklyReportReminder();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Vous pouvez maintenant partager les bilans avec votre coach !')),
                  );
                } else {
                  // Si on désactive, on annule la notification
                  await NotificationService().cancelWeeklyReportReminder();
                    }
                  },
                ),
                    // On affiche le champ de texte uniquement si l'option est activée,
                    // avec un padding pour l'aligner.
                    if (_coachingEnabled)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16.0, 0, 16.0, 16.0),
                        child: TextFormField(
                          controller: _coachEmailController,
                          decoration: const InputDecoration(
                            labelText: "Email du coach",
                            isDense: true, // Rend le champ plus compact
                          ),
                          keyboardType: TextInputType.emailAddress,
                          onEditingComplete: () {
                            // Quand l'utilisateur a fini d'éditer, on sauvegarde
                          _controller.saveCoachEmail(_coachEmailController.text);
                          FocusScope.of(context).unfocus(); // Pour cacher le clavier
                          },
                        ),
                      ),
                  ],
                ),
              ),
            
                // CARD DU MODE SOMBRE
                Card(
            child: SwitchListTile(
              title: Text(
                'Mode Sombre',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              // La valeur du Switch dépend du thème actuel
              value: themeProvider.themeMode == ThemeMode.dark,
              activeColor: Theme.of(context).colorScheme.primary,
              // Quand l'utilisateur bascule le Switch
              onChanged: (bool value) {
                // On utilise context.read pour appeler une méthode du provider
                // C'est la bonne pratique dans un callback comme onChanged.
                context.read<ThemeProvider>().setThemeMode(
                  value ? ThemeMode.dark : ThemeMode.light,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(
  TextEditingController controller,
  String label,
  // ON AJOUTE UN PARAMÈTRE OPTIONNEL, qui est false par défaut
  {bool isNumeric = false}) {
    
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: TextFormField(
      controller: controller,
      // Le type de clavier dépend maintenant de 'isNumeric'
      keyboardType: isNumeric
          ? const TextInputType.numberWithOptions(decimal: true)
          : TextInputType.text,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      validator: (value) {
        // La validation s'applique à tous les champs pour vérifier s'ils sont vides
        if (value == null || value.isEmpty) {
          return 'Champ obligatoire';
        }
        // La validation numérique ne s'applique que si 'isNumeric' est vrai
        if (isNumeric) {
          if (double.tryParse(value) == null) {
            return 'Entrez un nombre valide';
          }
        }
        return null; // Pas d'erreur
      },
    ),
  );
}
}
