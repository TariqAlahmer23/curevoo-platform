import 'package:curevoo_doctor/theme/app_theme.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeStyleCubit extends Cubit<String> {
  ThemeStyleCubit._(this._preferences, String initialThemeStyle)
    : super(initialThemeStyle);

  static const String _themeStylePreferenceKey = 'theme_style';

  final SharedPreferences _preferences;

  static const List<String> allowedThemeStyles = [
    MyTheme.themeBlue,
    MyTheme.themeGreen,
    MyTheme.themeIndigo,
    MyTheme.themeRose,
    MyTheme.themeCyan,
  ];

  static Future<ThemeStyleCubit> create() async {
    final preferences = await SharedPreferences.getInstance();
    final savedThemeStyle =
        preferences.getString(_themeStylePreferenceKey) ?? MyTheme.themeBlue;

    final normalized = allowedThemeStyles.contains(savedThemeStyle)
        ? savedThemeStyle
        : MyTheme.themeBlue;
    return ThemeStyleCubit._(preferences, normalized);
  }

  Future<void> setThemeStyle(String themeStyle) async {
    if (!allowedThemeStyles.contains(themeStyle) || themeStyle == state) return;
    emit(themeStyle);
    await _preferences.setString(_themeStylePreferenceKey, themeStyle);
  }
}
