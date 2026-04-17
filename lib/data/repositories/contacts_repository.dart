import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/note.dart';

class ContactsRepository {
  static const _pinnedKey = 'pinned_contacts';

  Future<List<NoteContact>> getPinnedContacts() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_pinnedKey) ?? [];
    return raw
        .map((e) => NoteContact.fromJson(jsonDecode(e) as Map<String, dynamic>))
        .toList();
  }

  Future<void> togglePin(NoteContact contact) async {
    final prefs = await SharedPreferences.getInstance();
    final current = await getPinnedContacts();
    
    final index = current.indexWhere((e) => e.phoneNumber == contact.phoneNumber);
    if (index >= 0) {
      current.removeAt(index);
    } else {
      current.add(contact);
    }
    
    final raw = current.map((e) => jsonEncode(e.toJson())).toList();
    await prefs.setStringList(_pinnedKey, raw);
  }

  Future<bool> isPinned(NoteContact contact) async {
    final pinned = await getPinnedContacts();
    return pinned.any((e) => e.phoneNumber == contact.phoneNumber);
  }
}
