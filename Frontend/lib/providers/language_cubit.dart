import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:shared_preferences/shared_preferences.dart';

class LanguageCubit extends Cubit<Locale> {
  LanguageCubit._(this._preferences, Locale initialLocale) : super(initialLocale);

  static const String _languagePreferenceKey = 'language_code';

  final SharedPreferences _preferences;

  static Future<LanguageCubit> create() async {
    final preferences = await SharedPreferences.getInstance();
    final savedLanguageCode = preferences.getString(_languagePreferenceKey) ?? 'en';

    return LanguageCubit._(preferences, Locale(savedLanguageCode));
  }

  Future<void> setLanguage(String languageCode) async {
    if (languageCode == state.languageCode) return;
    final locale = Locale(languageCode);
    emit(locale);
    await _preferences.setString(_languagePreferenceKey, languageCode);
  }
}
