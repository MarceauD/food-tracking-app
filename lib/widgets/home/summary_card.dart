// lib/widgets/home/summary_card.dart

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';

// --- WIDGET D'ANIMATION DE NOMBRES, AUTONOME ET ROBUSTE ---
class AnimatedCountUp extends StatefulWidget {
  final double end;
  final TextStyle? style;
  final String suffix;
  final Duration duration;

  const AnimatedCountUp({
    super.key,
    required this.end,
    this.style,
    this.suffix = '',
    this.duration = const Duration(milliseconds: 900),
  });

  @override
  State<AnimatedCountUp> createState() => _AnimatedCountUpState();
}

class _AnimatedCountUpState extends State<AnimatedCountUp> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;
  double _currentBeginValue = 0;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: widget.duration, vsync: this);
    _animation = Tween<double>(begin: _currentBeginValue, end: widget.end).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeOut),
    );
    _controller.forward();
  }

  @override
  void didUpdateWidget(AnimatedCountUp oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Si la valeur cible change, on lance une nouvelle animation
    if (widget.end != oldWidget.end) {
      _currentBeginValue = oldWidget.end; // On part de l'ancienne valeur
      _animation = Tween<double>(
        begin: _currentBeginValue,
        end: widget.end,
      ).animate(
        CurvedAnimation(parent: _controller, curve: Curves.easeOut),
      );
      _controller.reset();
      _controller.forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Text(
          '${_animation.value.toStringAsFixed(0)}${widget.suffix}',
          style: widget.style,
        );
      },
    );
  }
}


// --- WIDGET PRIVÉ POUR LES CALORIES, MAINTENANT UN STATELESSWIDGET SIMPLE ---
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
    final textTheme = Theme.of(context).textTheme;
    final isOverGoal = total > goal;
    final progressColor = isOverGoal ? Colors.orange.shade700 : Colors.green;
    final remainingCalories = (goal - total).clamp(0, goal);

    return Column(
      children: [
        CircularPercentIndicator(
          radius: radius,
          lineWidth: 12.0,
          percent: (goal > 0 ? total / goal : 0).clamp(0.0, 1.0) as double,
          center: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              AnimatedCountUp(
                end: total,
                style: textTheme.displaySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              Text('KCAL CONSOMMÉES', style: textTheme.bodySmall?.copyWith(letterSpacing: 0.5)),
            ],
          ),
          progressColor: progressColor,
          backgroundColor: progressColor.withOpacity(0.2),
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
          animateFromLastPercent: true,
          animationDuration: 1200,
        ),
        const SizedBox(height: 8.0),
        AnimatedCountUp(
          end: isOverGoal ? (total - goal).toDouble() : remainingCalories.toDouble(),
          suffix: isOverGoal ? ' de dépassement' : ' restantes',
          style: textTheme.bodyLarge?.copyWith(
            fontWeight: FontWeight.w500,
            color: isOverGoal ? Colors.orange.shade800 : null,
          ),
        ),
      ],
    );
  }
}

// --- WIDGET PRIVÉ POUR LES MACROS, AUSSI UN STATELESSWIDGET SIMPLE ---
class _MacroIndicator extends StatelessWidget {
  final double radius;
  final IconData iconData;
  final String label;
  final double value;
  final double max;
  final Color color;

  const _MacroIndicator({
    required this.radius,
    required this.iconData,
    required this.label,
    required this.value,
    required this.max,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isOverGoal = value > max;
    final progressColor = isOverGoal ? color.withOpacity(0.8) : color;

    return Column(
      children: [
        Stack(
          alignment: Alignment.center,
          children: [
            CircularPercentIndicator(
              radius: radius,
              lineWidth: 9.0,
              percent: (max > 0 ? value / max : 0).clamp(0.0, 1.0) as double,
              backgroundColor: color.withAlpha(50),
              progressColor: progressColor,
              circularStrokeCap: CircularStrokeCap.round,
              animation: true,
              animateFromLastPercent: true,
              animationDuration: 800,
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(iconData, color: progressColor, size: radius * 0.45),
                const SizedBox(height: 4),
                AnimatedCountUp(
                  end: value,
                  suffix: ' g',
                  style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                Text(
                  ' / ${max.toStringAsFixed(0)} g',
                    style: textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600], // Un style plus léger pour l'objectif
                    ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          label,
          style: textTheme.labelLarge?.copyWith(color: progressColor, fontWeight: FontWeight.bold),
        ),
      ],
    );
  }
}

// --- WIDGET PUBLIC PRINCIPAL, RESTE STATELESS CAR IL NE FAIT QU'ASSEMBLER ---
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
    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24.0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
        child: Column(
          children: [
            _CalorieIndicator(
              radius: gaugeRadiusCalories,
              total: totalCalories,
              goal: goalCalories,
            ),
            const SizedBox(height: 24),
            LayoutBuilder(
              builder: (context, constraints) {
                final double gaugeRadius = (constraints.maxWidth / 3) / 2.3;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _MacroIndicator(label: 'Glucides', radius: gaugeRadius, iconData: Icons.local_fire_department_outlined, value: totalCarbs, max: goalCarbs, color: Colors.blue),
                    _MacroIndicator(label: 'Protéines', radius: gaugeRadius, iconData: Icons.fitness_center_outlined, value: totalProtein, max: goalProtein, color: Colors.red),
                    _MacroIndicator(label: 'Lipides', radius: gaugeRadius, iconData: Icons.water_drop_outlined, value: totalFat, max: goalFat, color: Colors.orange),
                  ],
                );
              },
            ),
            
          ],
        ),
      ),
    );
  }
}