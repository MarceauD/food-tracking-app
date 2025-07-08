import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_profile.dart'; // N'oubliez pas l'import
import '../helpers/database_helper.dart'; 

class SettingsController {
  // Charge tous les paramètres et les retourne dans une Map
  Future<Map<String, dynamic>> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();

    
    return {
      'goalCalories': prefs.getDouble('goalCalories') ?? 1700,
      'goalCarbs': prefs.getDouble('goalCarbs') ?? 150,
      'goalProtein': prefs.getDouble('goalProtein') ?? 160,
      'goalFat': prefs.getDouble('goalFat') ?? 70,
    };
  }

  // Sauvegarde les objectifs
  Future<void> saveGoals(Map<String, double> goals) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('goalCalories', goals['calories']!);
    await prefs.setDouble('goalCarbs', goals['carbs']!);
    await prefs.setDouble('goalProtein', goals['protein']!);
    await prefs.setDouble('goalFat', goals['fat']!);
  }

  Future<UserProfile?> loadProfile() async {
    return await DatabaseHelper.instance.getUserProfile();
  }

  Future<void> saveProfile(UserProfile profile) async {
    await DatabaseHelper.instance.saveOrUpdateUserProfile(profile);
  }

  Future<void> saveCoachEmail(String email) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('coachEmail', email);
  }

}