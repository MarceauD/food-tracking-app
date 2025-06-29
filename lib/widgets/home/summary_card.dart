// lib/widgets/home/summary_card.dart

import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

class SummaryCard extends StatelessWidget {
  final double totalCalories;
  final double goalCalories;
  final double totalCarbs;
  final double goalCarbs;
  final double totalProtein;
  final double goalProtein;
  final double totalFat;
  final double goalFat;
  final double gaugeRadiusMacro;
  final double gaugeRadiusCalories;
  final Widget Function({
    required String label,
    required double value,
    required double max,
    required Color color,
    required double radius,
    required IconData iconData,
  }) buildMacroIndicator;

  const SummaryCard({
    super.key,
    required this.totalCalories,
    required this.goalCalories,
    required this.totalCarbs,
    required this.goalCarbs,
    required this.totalProtein,
    required this.goalProtein,
    required this.totalFat,
    required this.goalFat,
    required this.gaugeRadiusMacro,
    required this.gaugeRadiusCalories,
    required this.buildMacroIndicator,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4.0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        child: Column(
          children: [
            // Jauge principale de calories
            CircularPercentIndicator(
              radius: gaugeRadiusCalories,
              lineWidth: 12.0,
              percent: (totalCalories / goalCalories).clamp(0, 1),
              center: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    totalCalories.toStringAsFixed(0),
                    style: TextStyle(
                      fontWeight: FontWeight.w600, // Semi-gras
                      fontSize: 42, // Plus grand
                    ),
                  ),
                  Text(
                    'KCAL CONSOMMÉES',
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[700], // Un gris plus foncé
                      letterSpacing: 0.5, // On aère les lettres
                    ),
                  ),
                ],
              ),
              progressColor: Colors.green,
              backgroundColor: Colors.green.shade100,
              circularStrokeCap: CircularStrokeCap.round,

              animation: true, // Active l'animation
              animateFromLastPercent: true, // Anime depuis la valeur précédente, pas depuis zéro
              animationDuration: 1200, // Durée en millisecondes (1.2 secondes)
              curve: Curves.easeInOutCubic, // Style de l'animation pour un effet doux
              
            ),
            const SizedBox(height: 7.0),
            Text(
              '${(goalCalories - totalCalories).clamp(0, goalCalories).toStringAsFixed(0)} restantes',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w500, // Medium
                color: Colors.grey[800],
              ),
            ),
            const SizedBox(height: 16),
            // Jauges des macronutriments
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                buildMacroIndicator(
                    radius: gaugeRadiusMacro,
                    iconData: Icons.local_fire_department_outlined,
                    label: 'Glucides',
                    value: totalCarbs,
                    max: goalCarbs,
                    color: Colors.blue),
                buildMacroIndicator(
                    radius: gaugeRadiusMacro,
                    iconData: Icons.fitness_center_outlined,
                    label: 'Protéines',
                    value: totalProtein,
                    max: goalProtein,
                    color: Colors.red),
                buildMacroIndicator(
                    radius: gaugeRadiusMacro,
                    iconData: Icons.water_drop_outlined,
                    label: 'Lipides',
                    value: totalFat,
                    max: goalFat,
                    color: Colors.orange),
              ],
            ),
          ],
        ),
      ),
    );
  }
}