import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/note.dart';

class FirestoreRepository {
  // Получить одну заметку по id
  Future<Note?> fetchNoteById(String id) async {
    final doc = await _notesRef.doc(id).get();
    if (!doc.exists) return null;
    return Note.fromJson(doc.data()!);
  }

  final String userId;
  FirestoreRepository(this.userId);

  // Путь к коллекции заметок конкретного пользователя
  CollectionReference<Map<String, dynamic>> get _notesRef => FirebaseFirestore
      .instance
      .collection('users')
      .doc(userId)
      .collection('notes');

  // Получить все заметки из облака один раз
  Future<List<Note>> fetchNotes() async {
    final snapshot = await _notesRef.get();
    return snapshot.docs.map((doc) => Note.fromJson(doc.data())).toList();
  }

  // Создать или обновить заметку в облаке
  Future<void> upsertNote(Note note) async {
    await _notesRef.doc(note.id).set(note.toJson());
  }

  // Удалить заметку из облака
  Future<void> deleteNote(String id) async {
    await _notesRef.doc(id).delete();
  }

  // Массовое удаление в облаке (Batch)
  Future<void> deleteMultiple(Set<String> ids) async {
    final batch = FirebaseFirestore.instance.batch();
    for (final id in ids) {
      batch.delete(_notesRef.doc(id));
    }
    await batch.commit();
  }
}
