import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum AIModel {
  gemini,
  qwen,
}

final settingsServiceProvider = Provider((ref) => SettingsService());
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);
final accentColorProvider = StateProvider<int?>((ref) => null);
final aiModelProvider = StateProvider<AIModel>((ref) => AIModel.gemini);
final fallbackApiKeyProvider = StateProvider<String?>((ref) => null);
final useFallbackApiKeyProvider = StateProvider<bool>((ref) => false);

class SettingsService {
  static const _themeKey = 'theme_index';
  static const _viewModeKey = 'view_mode_index';
  static const _sortModeKey = 'sort_mode_index';
  static const _sortAscKey = 'sort_asc_bool';
  static const _accentColorKey = 'accent_color_value';
  static const _aiModelKey = 'ai_model_index';
  static const _fallbackApiKey = 'fallback_api_key';
  static const _useFallbackApiKey = 'use_fallback_api_key_bool';
  static const _mainModeKey = 'main_mode_index';

  Future<void> saveThemeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, index);
  }

  Future<int> loadThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeKey) ?? ThemeMode.system.index;
  }

  Future<void> saveViewMode(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_viewModeKey, index);
  }

  Future<int> loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_viewModeKey) ?? 0;
  }

  Future<void> saveMainMode(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_mainModeKey, index);
  }

  Future<int> loadMainMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_mainModeKey) ?? 0;
  }

  Future<void> saveSortMode(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sortModeKey, index);
  }

  Future<int> loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sortModeKey) ?? 0;
  }

  Future<void> saveSortAsc(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sortAscKey, value);
  }

  Future<bool> loadSortAsc() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sortAscKey) ?? false;
  }

  Future<void> saveAccentColor(int? value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value == null) {
      await prefs.remove(_accentColorKey);
      return;
    }
    await prefs.setInt(_accentColorKey, value);
  }

  Future<int?> loadAccentColor() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_accentColorKey);
  }

  Future<void> saveAIModel(AIModel model) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_aiModelKey, model.index);
  }

  Future<AIModel> loadAIModel() async {
    final prefs = await SharedPreferences.getInstance();
    final index = prefs.getInt(_aiModelKey) ?? AIModel.gemini.index;
    return AIModel.values[index];
  }

  Future<void> saveFallbackApiKey(String? key) async {
    final prefs = await SharedPreferences.getInstance();
    if (key == null || key.isEmpty) {
      await prefs.remove(_fallbackApiKey);
      return;
    }
    await prefs.setString(_fallbackApiKey, key);
  }

  Future<String?> loadFallbackApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_fallbackApiKey);
  }

  Future<void> saveUseFallbackApiKey(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_useFallbackApiKey, value);
  }

  Future<bool> loadUseFallbackApiKey() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_useFallbackApiKey) ?? false;
  }
}
