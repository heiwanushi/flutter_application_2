import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

final settingsServiceProvider = Provider((ref) => SettingsService());
final themeModeProvider = StateProvider<ThemeMode>((ref) => ThemeMode.system);

class SettingsService {
  static const _themeKey = 'theme_index';
  static const _viewModeKey = 'view_mode_index';
  static const _sortModeKey = 'sort_mode_index';
  static const _sortAscKey = 'sort_asc_bool';

  // Тема
  Future<void> saveThemeIndex(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_themeKey, index);
  }

  Future<int> loadThemeIndex() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_themeKey) ?? ThemeMode.system.index;
  }

  // Вид (Сетка/Список)
  Future<void> saveViewMode(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_viewModeKey, index);
  }

  Future<int> loadViewMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_viewModeKey) ?? 0; // По умолчанию сетка
  }

  // Режим сортировки
  Future<void> saveSortMode(int index) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_sortModeKey, index);
  }

  Future<int> loadSortMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_sortModeKey) ?? 0; // По умолчанию по обновлению
  }

  // Порядок сортировки
  Future<void> saveSortAsc(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_sortAscKey, value);
  }

  Future<bool> loadSortAsc() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_sortAscKey) ?? false; // По умолчанию убывание
  }
}