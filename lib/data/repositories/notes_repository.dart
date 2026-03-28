import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

List<Note> _parseNotes(List<String> raw) {
  return raw
      .map((e) => Note.fromJson(jsonDecode(e) as Map<String, dynamic>))
      .toList();
}

class NotesRepository {
  static const _spKey = 'notes';
  static const _boxName = 'notesBox';

  Box<String> get _box => Hive.box<String>(_boxName);

  Future<List<Note>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    
    // Бесшовная миграция из SharedPreferences в Hive
    if (prefs.containsKey(_spKey)) {
      final oldRaw = prefs.getStringList(_spKey) ?? [];
      final oldNotes = await compute(_parseNotes, oldRaw);
      
      final Map<String, String> mapToSave = {};
      for (final note in oldNotes) {
        mapToSave[note.id] = jsonEncode(note.toJson());
      }
      await _box.putAll(mapToSave);
      await prefs.remove(_spKey);
      
      return oldNotes;
    }
    
    final raw = _box.values.toList();
    if (raw.isEmpty) return [];
    
    // Парсинг больших данных в отдельном изоляте
    return compute(_parseNotes, raw);
  }

  Future<void> saveAll(List<Note> notes) async {
    final Map<String, String> mapToSave = {};
    for (final note in notes) {
      mapToSave[note.id] = jsonEncode(note.toJson());
    }
    await _box.clear();
    await _box.putAll(mapToSave);
  }

  Future<void> putNote(Note note) async {
    await _box.put(note.id, jsonEncode(note.toJson()));
  }

  Future<void> putNotes(List<Note> notes) async {
    final Map<String, String> mapToSave = {};
    for (final note in notes) {
      mapToSave[note.id] = jsonEncode(note.toJson());
    }
    await _box.putAll(mapToSave);
  }

  Future<void> deleteNote(String id) async {
    await _box.delete(id);
  }

  Future<void> deleteNotes(Set<String> ids) async {
    await _box.deleteAll(ids);
  }
}
