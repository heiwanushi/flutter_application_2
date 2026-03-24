import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class NotesRepository {
  static const _key = 'notes';

  Future<List<Note>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? [];
    return raw.map((e) => Note.fromJson(jsonDecode(e) as Map<String, dynamic>)).toList();
  }

  Future<void> saveAll(List<Note> notes) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, notes.map((e) => jsonEncode(e.toJson())).toList());
  }
}
