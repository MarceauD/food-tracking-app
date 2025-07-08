// lib/providers/theme_provider.dart
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider with ChangeNotifier {
  static const String _themeModeKey = 'theme_mode';
  ThemeMode _themeMode;

  // Le constructeur prend maintenant le mode initial en paramètre
  ThemeProvider(this._themeMode);

  ThemeMode get themeMode => _themeMode;

  void setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;

    _themeMode = mode;
    
    // La logique de sauvegarde ne change pas
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeModeKey, mode.name);
    
    notifyListeners();
  }

  void _loadThemeMode() async {
    final prefs = await SharedPreferences.getInstance();
    
    // On lit la préférence. Si elle est vide, on utilise ThemeMode.light par défaut.
    final savedTheme = prefs.getString(_themeModeKey) ?? ThemeMode.light.name; // <-- MODIFICATION ICI

    _themeMode = ThemeMode.values.firstWhere(
      (e) => e.name == savedTheme,
      orElse: () => ThemeMode.light, // Sécurité supplémentaire
    );
  }
}