import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit._(this._preferences, ThemeMode initialThemeMode)
      : super(initialThemeMode);

  static const String _themePreferenceKey = 'theme_mode';

  final SharedPreferences _preferences;

  static Future<ThemeCubit> create() async {
    final preferences = await SharedPreferences.getInstance();
    final savedThemeMode = preferences.getString(_themePreferenceKey);

    return ThemeCubit._(
      preferences,
      savedThemeMode == ThemeMode.dark.name
          ? ThemeMode.dark
          : ThemeMode.light,
    );
  }

  bool get isDarkMode => state == ThemeMode.dark;

  Future<void> setThemeMode(ThemeMode themeMode) async {
    if (themeMode == state) return;
    emit(themeMode);
    await _preferences.setString(_themePreferenceKey, themeMode.name);
  }

  Future<void> toggleTheme() async {
    await setThemeMode(isDarkMode ? ThemeMode.light : ThemeMode.dark);
  }
}
