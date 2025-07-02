// lib/screens/stats_screen.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/daily_summary.dart';
import '../widgets/common/empty_state_widget.dart';
import '../controllers/home_controller.dart'; // Assurez-vous que ce chemin est correct

// ON TRANSFORME LE WIDGET EN STATELESSWIDGET
class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}
class _StatsScreenState extends State<StatsScreen> {
  final HomeController _controller = HomeController();
  List<DailySummary> _summaries = [];
  bool _isLoading = true;

  final DateFormat dayFormat = DateFormat('EEEE d MMMM', 'fr_FR');

  @override
  void initState() {
    super.initState();
    _loadData();
  }

 Future<void> _loadData() async {
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
  
   @override
  Widget build(BuildContext context) {
     return Scaffold(
      // ...
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

                    // ON ENVELOPPE LA CARD DANS UN ROW POUR AJOUTER LA BARRE DE COULEUR
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // 1. LA BARRE DE COULEUR LATERALE
                        Container(
                          width: 5,
                          height: 140, // Hauteur approximative de la carte
                          margin: const EdgeInsets.only(top: 8.0),
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
                            Icon(
                              goalReached ? Icons.check_circle : Icons.cancel,
                              color: goalReached ? Colors.green : Colors.red,
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
                    ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
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

