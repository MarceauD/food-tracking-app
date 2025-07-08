// lib/models/user_profile.dart

// Un enum pour le genre, plus sûr qu'une chaîne de caractères
enum Gender { male, female }

// Un enum pour le niveau d'activité
enum ActivityLevel { sedentary, light, moderate, active, veryActive }

extension ActivityLevelExtension on ActivityLevel {
  String get frenchName {
    switch (this) {
      case ActivityLevel.sedentary:
        return 'Sédentaire';
      case ActivityLevel.light:
        return 'Léger';
      case ActivityLevel.moderate:
        return 'Modéré';
      case ActivityLevel.active:
        return 'Actif';
      case ActivityLevel.veryActive:
        return 'Très Actif';
    }
  }
}

enum Objective { lose, maintain, gain }

// --- AJOUTER UNE EXTENSION POUR LA TRADUCTION ---
extension ObjectiveExtension on Objective {
  String get frenchName {
    switch (this) {
      case Objective.lose:
        return 'Perte de poids';
      case Objective.maintain:
        return 'Maintien';
      case Objective.gain:
        return 'Prise de masse';
    }
  }
}

class UserProfile {
  final int? id; // L'ID sera toujours 1 car il n'y a qu'un seul utilisateur
  final Gender gender;
  final DateTime dateOfBirth;
  final double height; // en cm
  final double weight; // en kg
  final ActivityLevel activityLevel;
  final Objective objective;
  final String name;

  UserProfile({
    this.id = 1, // On fixe l'ID à 1
    required this.name,
    required this.gender,
    required this.dateOfBirth,
    required this.height,
    required this.weight,
    required this.activityLevel,
    required this.objective, // <-- AJOUTER AU CONSTRUCTEUR
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'gender': gender.name, // On stocke l'enum sous forme de texte
      'date_of_birth': dateOfBirth.toIso8601String(),
      'height': height,
      'weight': weight,
      'name': name,
      'activity_level': activityLevel.name,
      'objective': objective.name,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    return UserProfile(
      id: map['id'],
      name: map['name'] ?? 'Utilisateur',
      gender: Gender.values.byName(map['gender']),
      dateOfBirth: DateTime.parse(map['date_of_birth']),
      height: map['height'],
      weight: map['weight'],
      activityLevel: ActivityLevel.values.byName(map['activity_level']),
      objective: map['objective'] != null
          ? Objective.values.byName(map['objective'])
          : Objective.maintain,
    );
  }
}