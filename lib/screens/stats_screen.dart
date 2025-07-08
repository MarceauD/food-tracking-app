// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_summary.dart';
import '../widgets/common/empty_state_widget.dart';
import '../controllers/home_controller.dart'; // Assurez-vous que ce chemin est correct
import '../models/meal_type.dart';
import 'package:share_plus/share_plus.dart';
import '../helpers/database_helper.dart';
import '../models/food_item.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter_animate/flutter_animate.dart';




// ON TRANSFORME LE WIDGET EN STATELESSWIDGET
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => StatsScreenState();
}

class StatsScreenState extends State<StatsScreen> {
  final HomeController _controller = HomeController();
  List<DailySummary> _summaries = [];
  bool _isLoading = true;
  bool _coachingEnabled = false;


  final DateFormat dayFormat = DateFormat('EEEE d MMMM', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadCoachingEnabled();
    loadData();
  }

  Future<void> _loadCoachingEnabled() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _coachingEnabled = prefs.getBool('coachingEnabled') ?? false;
    });
  }

  Future<void> _showShareOptions({
    required String reportText,
    required String subject,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final coachEmail = prefs.getString('coachEmail') ?? '';

    void sendEmail() async {
      if (coachEmail.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Veuillez configurer l\'email du coach dans les paramètres.')),
        );
        return;
      }
      final Uri emailLaunchUri = Uri(
        scheme: 'mailto',
        path: coachEmail,
        query: 'subject=${Uri.encodeComponent(subject)}&body=${Uri.encodeComponent(reportText)}',
      );
      
      try {
        // On essaie de lancer l'URL
        final bool aPusLancer = await launchUrl(emailLaunchUri);
        if (!aPusLancer) {
          // Si launchUrl retourne false, c'est qu'il ne peut pas gérer ce type d'URL
          throw Exception('Impossible d\'ouvrir l\'application de messagerie.');
        }
      } catch (e) {
        // Si une erreur se produit, on l'affiche à l'utilisateur
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Erreur : Impossible d\'ouvrir une application de messagerie. Assurez-vous qu\'une application est bien installée et configurée.')),
          );
        }
      }
    }

    void sharePlainText() {
      Share.share(reportText, subject: subject);
    }

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Wrap(
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.email_outlined),
              title: const Text('Envoyer par Email'),
              onTap: () {
                Navigator.pop(context);
                sendEmail();
              },
            ),
            ListTile(
              leading: const Icon(Icons.share_outlined),
              title: const Text('Partager en texte brut'),
              onTap: () {
                Navigator.pop(context);
                sharePlainText();
              },
            ),
          ],
        );
      },
    );
  }

 Future<void> loadData() async {
    final allSummaries = await _controller.getRecentSummaries();

    final today = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
    final pastSummaries = allSummaries.where((summary) {
      // On s'assure de ne comparer que les jours, sans les heures
      final summaryDate = DateTime(summary.date.year, summary.date.month, summary.date.day);
      // On ne garde que les dates STRICTEMENT antérieures à aujourd'hui
      return summaryDate.isBefore(today);
    }).toList();

    // On s'assure que le widget est toujours "monté" (affiché) avant de mettre à jour son état
    if (mounted) {
      setState(() {
        // 3. On utilise la liste FILTRÉE pour l'affichage
        _summaries = pastSummaries;
        _isLoading = false;
      });
    }
  }

  Future<void> _shareDaySummary(BuildContext context, DailySummary summary) async {  
    // On utilise le package 'share_plus'
    final String report = await _controller.generateDailyReport(summary);
    final userProfile = await DatabaseHelper.instance.getUserProfile();
    final userName = userProfile?.name ?? 'Utilisateur'; 

    final String subject = 'Bilan du ${DateFormat('d/M/y').format(summary.date)} - $userName';
    // On partage le texte généré
    _showShareOptions(reportText: report, subject: subject);
  }

  
  Future<void> _shareWeekSummary() async {
  if (_summaries.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Aucune donnée à partager.')),
    );
    return;
  }

  final userProfile = await DatabaseHelper.instance.getUserProfile();
  final userName = userProfile?.name ?? 'Utilisateur'; 

  final buffer = StringBuffer();
  buffer.writeln("Bilan Nutritionnel de la Semaine - $userName");
  buffer.writeln("=================================");

  for (final summary in _summaries) {
    buffer.writeln();
    // On appelle notre fonction d'aide pour générer le rapport de chaque jour
    final dailyReport = await _controller.generateDailyReport(summary);
    buffer.writeln(dailyReport);
    buffer.writeln("--------------------");
  }

  final String subject = 'Bilan Nutritionnel de la Semaine - $userName';

  // ON APPELLE NOTRE NOUVELLE MÉTHODE
  _showShareOptions(reportText: buffer.toString(), subject: subject);
}
  
   @override
  Widget build(BuildContext context) {
    _loadCoachingEnabled();
    
     return Scaffold(
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _summaries.isEmpty
              ? const EmptyStateWidget(
                imagePath: 'assets/images/undraw_stats.svg',
                title: 'Les statistiques apparaîtront ici',
                subtitle: 'Enregistrez vos repas pendant quelques jours pour voir vos progrès se dessiner.',
              )
              : ListView.builder(
                  padding: const EdgeInsets.all(8.0),
                  itemCount: _summaries.length,
                  itemBuilder: (context, index) {
                    final summary = _summaries[index];
                    final goalReached = summary.totalCalories <= summary.goalCalories;
                    final dayFormat = DateFormat('EEEE d MMMM', 'fr_FR');

                    final bool hasAllMeals = summary.loggedMeals.containsAll([
                      MealType.breakfast,
                      MealType.lunch,
                      MealType.dinner,
                    ]);
                    final bool isDayComplete = hasAllMeals && goalReached;

                    // ON ENVELOPPE LA CARD DANS UN ROW POUR AJOUTER LA BARRE DE COULEUR
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. LA BARRE DE COULEUR LATERALE
                        Container(
                          width: 5,
                          height: 80, // Hauteur approximative de la carte
                          margin: const EdgeInsets.only(top: 10.0),
                          decoration: BoxDecoration(
                            color: goalReached ? Colors.green : Colors.red,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                        
                        // ON ENVELOPPE LA CARD DANS UN EXPANDED POUR QU'ELLE PRENNE LA LARGEUR RESTANTE
                        Expanded(
                          child: Card(
                            elevation: 2.0,
                            margin: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12.0),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // La ligne Date + Coche/Croix ne change pas
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(
                                    dayFormat.format(summary.date),
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  if (_coachingEnabled)
                                  IconButton(
                                    icon: const Icon(Icons.share_outlined),
                                    onPressed: () => _shareDaySummary(context, summary),
                                    tooltip: 'Partager le bilan',
                                    ),
                                  if (hasAllMeals)
                                    Icon(
                                      isDayComplete ? Icons.check_circle : Icons.cancel,
                                      color: isDayComplete ? Colors.green : Colors.red,
                                    )
                                  else
                                    Text(
                                      'Données manquantes',
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                ],
                              ),
                              const Divider(height: 24),
                              // La ligne des calories ne change pas
                              Text(
                                '${summary.totalCalories.toStringAsFixed(0)} / ${summary.goalCalories.toStringAsFixed(0)} kcal',
                                style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 16),

                              // 2. LA NOUVELLE BARRE DE PROGRESSION DES MACROS
                              _buildMacrosRatioBar(summary),

                              const SizedBox(height: 12), // Espace entre la barre et les textes
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  // On réutilise notre méthode d'aide pour afficher le détail
                                  _buildMacroText(context, 'Glucides', summary.totalCarbs, Colors.blue),
                                  _buildMacroText(context, 'Protéines', summary.totalProtein, Colors.red),
                                  _buildMacroText(context, 'Lipides', summary.totalFat, Colors.orange),
                                ],
                              ),
                              const SizedBox(height: 12),
                              Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMealCalorieText('Petit-déj', summary.breakfastCalories),
                                _buildMealCalorieText('Déjeuner', summary.lunchCalories),
                                _buildMealCalorieText('Dîner', summary.dinnerCalories),
                                _buildMealCalorieText('Collation', summary.snackCalories),
                              ],
                            )
                            ],
                          ),
                          ),
                        ),
                      ),
                    ],
                  ).animate()
    .fadeIn(delay: (100 * index).ms, duration: 500.ms) // Décale chaque animation
    .slideX(begin: -0.2, curve: Curves.easeOut);
                },
              ),
      
              floatingActionButton: _coachingEnabled ?
               FloatingActionButton.extended(
              onPressed: _shareWeekSummary,
              heroTag: 'fab_stats',
              label: const Text('Partager le bilan'),
              icon: const Icon(Icons.share),
            ) : null,
    );
  }

  Widget _buildMealCalorieText(String label, double value) {
    return Column(
      children: [
        Text(label, style: Theme.of(context).textTheme.bodySmall),
        Text(
          '${value.toStringAsFixed(0)} kcal',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _buildMacroText(BuildContext context, String label, double value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: color, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          '${value.toStringAsFixed(0)} g',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMacrosRatioBar(DailySummary summary) {
    final totalMacros = summary.totalCarbs + summary.totalProtein + summary.totalFat;
    if (totalMacros == 0) return const SizedBox.shrink(); // Ne rien afficher si pas de macros

    return Row(
      children: [
        Expanded(
          flex: (summary.totalCarbs / totalMacros * 100).round(),
          child: Container(height: 8, color: Colors.blue),
        ),
        Expanded(
          flex: (summary.totalProtein / totalMacros * 100).round(),
          child: Container(height: 8, color: Colors.red),
        ),
        Expanded(
          flex: (summary.totalFat / totalMacros * 100).round(),
          child: Container(height: 8, color: Colors.orange),
        ),
      ],
    );
  }
}

