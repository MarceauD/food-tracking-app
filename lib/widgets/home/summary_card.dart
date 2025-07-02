// lib/widgets/home/summary_card.dart

import 'package:flutter/material.dart';
import 'package:percent_indicator/percent_indicator.dart';

// lib/widgets/home/summary_card.dart

// --- WIDGET PRIVÉ POUR LA JAUGE DE CALORIES ---
class _CalorieIndicator extends StatelessWidget {
  final double radius;
  final double total;
  final double goal;

  const _CalorieIndicator({
    required this.radius,
    required this.total,
    required this.goal,
  });

  @override
  Widget build(BuildContext context) {
    // On récupère les styles depuis le thème global
    final headlineStyle = Theme.of(context).textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600);
    final captionStyle = Theme.of(context).textTheme.bodySmall;

    return Column(
      children: [
        CircularPercentIndicator(
          radius: radius,
          lineWidth: 12.0,
          percent: (goal > 0.0 ? total / goal : 0.0).clamp(0.0, 1.0),
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(total.toStringAsFixed(0), style: headlineStyle),
              Text('KCAL CONSOMMÉES', style: captionStyle),
            ],
          ),
          progressColor: Colors.green,
          backgroundColor: Colors.green.withOpacity(0.2),
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
          animateFromLastPercent: true,
          animationDuration: 1200,
          curve: Curves.easeInOutCubic,
        ),
        const SizedBox(height: 8.0),
        Text(
          '${(goal - total).clamp(0, goal).toStringAsFixed(0)} restantes',
          // On utilise le style de corps de texte du thème
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }
}

// --- WIDGET PRIVÉ POUR LES MACROS ---
class _MacroIndicator extends StatelessWidget {
  final IconData iconData;
  final String label;
  final double value;
  final double max;
  final Color color;

  // On n'a plus besoin du paramètre 'radius'
  const _MacroIndicator({
    required this.iconData,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    // FittedBox va automatiquement réduire la taille de la Column
    // pour qu'elle rentre dans l'espace fourni par le parent (Expanded).
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              CircularPercentIndicator(
                // On lui donne une taille de base fixe et assez grande.
                // FittedBox s'occupera de la réduire si nécessaire.
                radius: 50.0,
                lineWidth: 9.0,
                percent: (max > 0.0 ? value / max : 0.0).clamp(0.0, 1.0),
                backgroundColor: color.withAlpha(50),
                progressColor: color,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animateFromLastPercent: true,
                animationDuration: 800,
              ),
              Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(iconData, color: color, size: 22), // Taille fixe
                  const SizedBox(height: 4),
                  Text(
                    '${value.toStringAsFixed(0)} g / ${max.toStringAsFixed(0)} g', // Texte simplifié pour gagner de la place
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
          ),
        ],
      ),
    );
  }
}

// LE WIDGET SummaryCard PRINCIPAL, SIMPLIFIÉ
class SummaryCard extends StatelessWidget {
  final double totalCalories;
  final double goalCalories;
  final double totalCarbs;
  final double goalCarbs;
  final double totalProtein;
  final double goalProtein;
  final double totalFat;
  final double goalFat;
  final double gaugeRadiusCalories;

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
    required this.gaugeRadiusCalories,
  });

  @override
  Widget build(BuildContext context) {
    // ON REMPLACE LA Card PAR UN CONTAINER POUR UN CONTRÔLE TOTAL DU STYLE
    return 
    Container(
      // La décoration nous permet de définir la couleur, les bordures, l'ombre, etc.
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface, // Le blanc de notre thème
        borderRadius: const BorderRadius.vertical(
          bottom: Radius.circular(24.0), // On arrondit uniquement les coins du bas
        ),
        // On ajoute une ombre personnalisée et plus douce
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 24),
        child: Column(
          children: [
            _CalorieIndicator(
              radius: gaugeRadiusCalories,
              total: totalCalories,
              goal: goalCalories,
            ),
            const SizedBox(height: 24),
            // LA NOUVELLE ROW, QUI UTILISE EXPANDED
            Row(
              children: [
                Expanded(
                  child: _MacroIndicator(
                    label: 'Glucides',
                    iconData: Icons.local_fire_department_outlined,
                    value: totalCarbs,
                    max: goalCarbs,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(width: 8), // Espaceur entre les jauges
                Expanded(
                  child: _MacroIndicator(
                    label: 'Protéines',
                    iconData: Icons.fitness_center_outlined,
                    value: totalProtein,
                    max: goalProtein,
                    color: Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _MacroIndicator(
                    label: 'Lipides',
                    iconData: Icons.water_drop_outlined,
                    value: totalFat,
                    max: goalFat,
                    color: Colors.orange,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

