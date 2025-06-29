// lib/widgets/common/empty_state_widget.dart
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

class EmptyStateWidget extends StatelessWidget {
  final String imagePath;
  final String title;
  final String subtitle;

  const EmptyStateWidget({
    super.key,
    required this.imagePath,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    // ON ENVELOPPE LE TOUT DANS UN SINGLECHILDSCROLLVIEW
    return SingleChildScrollView(
      child: Center(
        child: Padding(
          // On peut réduire un peu le padding pour gagner de la place
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SvgPicture.asset(
                imagePath,
                // On peut aussi réduire légèrement la hauteur de l'image
                height: 100, 
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}