import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/note.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/firestore_repository.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/services/sync_service.dart';
import '../../../core/services/notification_service.dart';

final notesRepositoryProvider = Provider((_) => NotesRepository());
final selectedIdsProvider = StateProvider<Set<String>>((ref) => {});
final notesProvider = AsyncNotifierProvider<NotesNotifier, List<Note>>(
  NotesNotifier.new,
);

class NotesNotifier extends AsyncNotifier<List<Note>> {
  static const _uuid = Uuid();
  NotesRepository get _localRepo => ref.read(notesRepositoryProvider);

  FirestoreRepository? get _remoteRepo {
    final user = ref.watch(authStateProvider).value;
    return user != null ? FirestoreRepository(user.uid) : null;
  }

  @override
  Future<List<Note>> build() async {
    final user = ref.watch(authStateProvider).value;
    final localNotes = await _localRepo.loadAll();

    if (user != null) {
      // Запускаем синхронизацию в фоне, не блокируя UI
      _backgroundSync(user.uid, localNotes);
    }

    return localNotes;
  }

  // Публичный метод для ручного обновления (pull-to-refresh)
  Future<void> refreshSync() async {
    final user = ref.read(authStateProvider).value;
    if (user == null) return;
    await _backgroundSync(user.uid, state.value ?? []);
  }

  Future<void> _backgroundSync(String uid, List<Note> initialNotes) async {
    try {
      final remoteRepo = FirestoreRepository(uid);
      final cloudNotes = await remoteRepo.fetchNotes();
      final cloudIds = cloudNotes.map((n) => n.id).toSet();

      // Используем актуальное состояние, если оно уже изменилось пока мы шли в облако
      final currentLocal = state.value ?? initialNotes;

      // 1. Заметки, помеченные как синхронизированные, но отсутствующие в облаке.
      // Это означает, что они были удалены на другом устройстве.

      // 2. Новые локальные заметки, которых еще нет в облаке
      final notesToUpload =
          currentLocal.where((n) => !n.isNoteSynced && !cloudIds.contains(n.id));

      // 3. Облачные заметки помечаем как синхронизированные
      final syncedCloudNotes =
          cloudNotes.map((n) => n.copyWith(isNoteSynced: true)).toList();

      // 4. Формируем финальный список: все из облака + новые локальные
      final finalNotes = [...syncedCloudNotes, ...notesToUpload];

      // Обновляем состояние и локальное хранилище
      state = AsyncData(finalNotes);
      await _localRepo.saveAll(finalNotes);

      // 5. Запускаем загрузку новых локальных заметок в облако
      for (final note in notesToUpload) {
        _performFullCloudSync(uid, note);
      }
    } catch (e) {
      debugPrint('Ошибка фоновой синхронизации: $e');
    }
  }

  // Общий метод для сохранения и запуска фоновой синхронизации
  Future<void> _persist(
    List<Note> notes, {
    Note? noteToSync,
    String? deletedId,
    Set<String>? deletedIds,
  }) async {
    state = AsyncData(notes);
    
    // Оптимизация: используем Hive точечно вместо полной перезаписи всего списка
    if (noteToSync != null) {
      await _localRepo.putNote(noteToSync);
    } else if (deletedId != null) {
      await _localRepo.deleteNote(deletedId);
    } else if (deletedIds != null) {
      await _localRepo.deleteNotes(deletedIds);
    } else {
      await _localRepo.saveAll(notes);
    }

    final user = ref.read(authStateProvider).value;
    if (user != null) {
      final remoteFirestore = FirestoreRepository(user.uid);
      if (deletedId != null) await remoteFirestore.deleteNote(deletedId);
      if (deletedIds != null) await remoteFirestore.deleteMultiple(deletedIds);

      if (noteToSync != null) {
        // Запускаем фоновую синхронизацию (Supabase + Firestore)
        _performFullCloudSync(user.uid, noteToSync);
      }
    }
  }

  // Фоновая магия: загружаем фото в Supabase, потом обновляем ссылки в Firestore
  Future<void> _performFullCloudSync(String uid, Note note) async {
    try {
      final syncService = SyncService(uid);
      final remoteFirestore = FirestoreRepository(uid);

      // 1. Загружаем только локальные картинки (не ссылки) в Supabase и получаем ссылки
      final localImages = note.imagePaths
          .where((img) => !img.startsWith('http'))
          .toList();
      final remoteImages = note.imagePaths
          .where((img) => img.startsWith('http'))
          .toList();
      final uploadedUrls = await syncService.uploadImages(localImages);
      // Собираем итоговый список: уже существующие ссылки + новые загруженные
      // Если картинка не загрузилась (пустая строка), оставляем локальный путь
      final filteredUrls = [
        ...remoteImages,
        for (int i = 0; i < uploadedUrls.length; i++)
          uploadedUrls[i].isNotEmpty ? uploadedUrls[i] : localImages[i],
      ];
      final syncedNote = note.copyWith(
        imagePaths: filteredUrls,
        isNoteSynced: true,
      );

      // 2. Обновляем заметку в Firestore (теперь там ссылки https://...)
      await remoteFirestore.upsertNote(syncedNote);

      // 3. Обновляем локальное состояние, чтобы UI использовал облачные ссылки (для кеша)
      final currentNotes = state.value ?? <Note>[];
      final newList = <Note>[
        for (final n in currentNotes)
          if (n.id == syncedNote.id) syncedNote else n,
      ];
      state = AsyncData(newList);
      await _localRepo.putNote(syncedNote);
    } catch (e) {
      debugPrint('Ошибка фоновой синхронизации: $e');
    }
  }

  Future<Note> add({
    required String title,
    required String content,
    required List<String> tags,
    List<String> imagePaths = const [],
    int? colorIndex,
    bool isPinned = false,
    DateTime? eventAt,
    int? reminderMinutes,
    String? calendarEventId,
    String? calendarId,
    NoteRepeatMode repeatMode = NoteRepeatMode.none,
    String? originalContent,
    List<NoteContact> contacts = const [],
  }) async {
    final note = Note(
      id: _uuid.v4(),
      title: title,
      content: content,
      tags: tags,
      imagePaths: imagePaths,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
      colorIndex: colorIndex,
      isPinned: isPinned,
      isNoteSynced: false,
      eventAt: eventAt,
      reminderMinutes: reminderMinutes,
      calendarEventId: calendarEventId,
      calendarId: calendarId,
      repeatMode: repeatMode,
      originalContent: originalContent,
      contacts: contacts,
    );
    final notes = <Note>[...(state.value ?? <Note>[]), note];
    await _persist(notes, noteToSync: note);
    // Планируем уведомление
    await ref.read(notificationServiceProvider).scheduleNoteNotification(note);
    return note;
  }

  Future<Note?> editNote(
    String id, {
    required String title,
    required String content,
    required List<String> tags,
    required List<String> imagePaths,
    DateTime? eventAt,
    int? reminderMinutes,
    String? calendarEventId,
    String? calendarId,
    NoteRepeatMode? repeatMode,
    bool clearEvent = false,
    String? originalContent,
    List<NoteContact>? contacts,
    int? colorIndex,
  }) async {
    Note? updatedNote;
    final currentNotes = state.value ?? <Note>[];
    final oldNote = currentNotes.where((n) => n.id == id).isNotEmpty
        ? currentNotes.firstWhere((n) => n.id == id)
        : null;
    // Если были удалены картинки, удаляем их из Supabase
    if (oldNote != null) {
      final removedImages = oldNote.imagePaths
          .where((img) => !imagePaths.contains(img))
          .toList();
      final user = ref.read(authStateProvider).value;
      if (removedImages.isNotEmpty && user != null) {
        final syncService = SyncService(user.uid);
        await syncService.deleteImagesByUrls(removedImages);
      }
    }
    final notes = <Note>[
      for (final n in currentNotes)
        if (n.id == id)
          (() {
            updatedNote = n.copyWith(
              title: title,
              content: content,
              tags: tags,
              imagePaths: imagePaths,
              updatedAt: DateTime.now(),
              isNoteSynced: false,
              eventAt: eventAt,
              reminderMinutes: reminderMinutes,
              calendarEventId: calendarEventId,
              calendarId: calendarId,
              repeatMode: repeatMode,
              clearEvent: clearEvent,
              originalContent: originalContent,
              contacts: contacts,
              colorIndex: colorIndex ?? n.colorIndex,
            );
            return updatedNote!;
          })()
        else
          n,
    ];
    if (updatedNote != null) {
      await _persist(notes, noteToSync: updatedNote);
      // Обновляем уведомление
      await ref.read(notificationServiceProvider).scheduleNoteNotification(updatedNote!);
    }
    return updatedNote;
  }

  Future<void> delete(String id) async {
    final currentNotes = state.value ?? <Note>[];
    final noteToDelete = currentNotes.where((n) => n.id == id).isNotEmpty
        ? currentNotes.firstWhere((n) => n.id == id)
        : null;

    if (noteToDelete != null) {
      try {
        await ref.read(calendarServiceProvider).deleteNoteEvent(noteToDelete);
      } catch (_) {}
    }

    Note? updatedNote;
    final notes = <Note>[
      for (final n in currentNotes)
        if (n.id == id)
          (() {
            updatedNote = n.copyWith(isDeleted: true, isNoteSynced: false);
            return updatedNote!;
          })()
        else
          n,
    ];

    if (updatedNote != null) {
      await _persist(notes, noteToSync: updatedNote);
      // Отменяем уведомление
      await ref.read(notificationServiceProvider).cancelNoteNotification(id);
    }
  }

  Future<void> deleteMultiple(Set<String> ids) async {
    final currentNotes = state.value ?? <Note>[];
    final updatedNotesList = <Note>[];

    for (final n in currentNotes) {
      if (ids.contains(n.id)) {
        try {
          await ref.read(calendarServiceProvider).deleteNoteEvent(n);
        } catch (_) {}
        final updated = n.copyWith(isDeleted: true, isNoteSynced: false);
        updatedNotesList.add(updated);
        await _remoteRepo?.upsertNote(updated);
      } else {
        updatedNotesList.add(n);
      }
    }
    state = AsyncData(updatedNotesList);
    await _localRepo.putNotes(updatedNotesList);
    
    // Отменяем уведомления для всех выбранных
    for (final id in ids) {
      await ref.read(notificationServiceProvider).cancelNoteNotification(id);
    }
  }

  Future<void> permanentlyDelete(String id) async {
    final currentNotes = state.value ?? <Note>[];
    final noteToDelete = currentNotes.where((n) => n.id == id).isNotEmpty
        ? currentNotes.firstWhere((n) => n.id == id)
        : null;
    final user = ref.read(authStateProvider).value;
    if (noteToDelete != null && user != null) {
      final syncService = SyncService(user.uid);
      await syncService.deleteImagesByUrls(noteToDelete.imagePaths);
    }
    if (noteToDelete != null) {
      try {
        await ref.read(calendarServiceProvider).deleteNoteEvent(noteToDelete);
      } catch (_) {}
    }
    final notes = <Note>[
      for (final n in currentNotes)
        if (n.id != id) n,
    ];
    await _persist(notes, deletedId: id);
    // Отменяем уведомление окончательно
    await ref.read(notificationServiceProvider).cancelNoteNotification(id);
  }

  Future<void> permanentlyDeleteMultiple(Set<String> ids) async {
    final currentNotes = state.value ?? <Note>[];
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      final syncService = SyncService(user.uid);
      final imagesToDelete = <String>[];
      for (final n in currentNotes) {
        if (ids.contains(n.id)) {
          imagesToDelete.addAll(n.imagePaths);
        }
      }
      await syncService.deleteImagesByUrls(imagesToDelete);
    }
    for (final note in currentNotes) {
      if (ids.contains(note.id)) {
        try {
          await ref.read(calendarServiceProvider).deleteNoteEvent(note);
        } catch (_) {}
      }
    }
    final notes = <Note>[
      for (final n in currentNotes)
        if (!ids.contains(n.id)) n,
    ];
    await _persist(notes, deletedIds: ids);
    // Отменяем все
    for (final id in ids) {
      await ref.read(notificationServiceProvider).cancelNoteNotification(id);
    }
  }

  Future<void> restore(String id) async {
    final currentNotes = state.value ?? <Note>[];
    Note? updatedNote;
    final notes = <Note>[
      for (final n in currentNotes)
        if (n.id == id)
          (() {
            updatedNote = n.copyWith(isDeleted: false, isNoteSynced: false);
            return updatedNote!;
          })()
        else
          n,
    ];
    if (updatedNote != null) {
      await _persist(notes, noteToSync: updatedNote);
      // Восстанавливаем уведомление
      await ref.read(notificationServiceProvider).scheduleNoteNotification(updatedNote!);
    }
  }

  Future<void> emptyTrash() async {
    final currentNotes = state.value ?? <Note>[];
    final idsToDelete = currentNotes
        .where((n) => n.isDeleted)
        .map((n) => n.id)
        .toSet();
    if (idsToDelete.isNotEmpty) {
      await permanentlyDeleteMultiple(idsToDelete);
    }
  }

  Future<void> clearArchive() async {
    final currentNotes = state.value ?? <Note>[];
    final idsToDelete = currentNotes
        .where((n) => n.eventAt != null && n.isCompleted && !n.isDeleted)
        .map((n) => n.id)
        .toSet();
    if (idsToDelete.isNotEmpty) {
      await permanentlyDeleteMultiple(idsToDelete);
    }
  }

  Future<void> toggleCompleted(String id) async {
    Note? updatedNote;
    final notes = <Note>[
      for (final n in state.value ?? <Note>[])
        if (n.id == id)
          (() {
            updatedNote = n.copyWith(
              isCompleted: !n.isCompleted,
              isNoteSynced: false,
            );
            return updatedNote!;
          })()
        else
          n,
    ];
    if (updatedNote != null) {
      state = AsyncData(notes);
      await _localRepo.putNote(updatedNote!);
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await FirestoreRepository(user.uid).upsertNote(updatedNote!);
        final syncedNote = updatedNote!.copyWith(isNoteSynced: true);
        final currentNotes = state.value ?? <Note>[];
        final newList = <Note>[
          for (final n in currentNotes)
            if (n.id == id) syncedNote else n,
        ];
        state = AsyncData(newList);
        await _localRepo.putNote(syncedNote);
      }
      // Обновляем уведомление (отменяем если завершено, иначе планируем)
      await ref.read(notificationServiceProvider).scheduleNoteNotification(updatedNote!);
    }
  }

  Future<void> togglePin(String id) async {
    Note? updatedNote;
    final notes = <Note>[
      for (final n in state.value ?? <Note>[])
        if (n.id == id)
          (() {
            updatedNote = n.copyWith(
              isPinned: !n.isPinned,
              isNoteSynced: false,
            );
            return updatedNote!;
          })()
        else
          n,
    ];
    if (updatedNote != null) {
      state = AsyncData(notes);
      await _localRepo.putNote(updatedNote!);
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await FirestoreRepository(user.uid).upsertNote(updatedNote!);
        // После успешного обновления в Firestore выставляем isNoteSynced=true
        final syncedNote = updatedNote!.copyWith(isNoteSynced: true);
        final currentNotes = state.value ?? <Note>[];
        final newList = <Note>[
          for (final n in currentNotes)
            if (n.id == id) syncedNote else n,
        ];
        state = AsyncData(newList);
        await _localRepo.putNote(syncedNote);
      }
    }
  }

  Future<void> togglePinMultiple(Set<String> ids) async {
    final currentNotes = state.value ?? <Note>[];
    final anyUnpinned = currentNotes
        .where((n) => ids.contains(n.id))
        .any((n) => !n.isPinned);

    final updatedNotesList = <Note>[];
    for (final n in currentNotes) {
      if (ids.contains(n.id)) {
        final updated = n.copyWith(isPinned: anyUnpinned);
        updatedNotesList.add(updated);
        // Синхронизируем изменение в Firestore
        await _remoteRepo?.upsertNote(updated);
      } else {
        updatedNotesList.add(n);
      }
    }
    state = AsyncData(updatedNotesList);
    await _localRepo.putNotes(updatedNotesList);
  }

  Future<void> setColor(String id, int? colorIndex) async {
    Note? updatedNote;
    final notes = <Note>[
      for (final n in state.value ?? <Note>[])
        if (n.id == id)
          (() {
            updatedNote = n.copyWith(
              colorIndex: colorIndex,
              clearColor: colorIndex == null,
              isNoteSynced: false,
            );
            return updatedNote!;
          })()
        else
          n,
    ];
    if (updatedNote != null) {
      state = AsyncData(notes);
      await _localRepo.putNote(updatedNote!);
      final user = ref.read(authStateProvider).value;
      if (user != null) {
        await FirestoreRepository(user.uid).upsertNote(updatedNote!);
        // После успешного обновления в Firestore выставляем isNoteSynced=true
        final syncedNote = updatedNote!.copyWith(isNoteSynced: true);
        final currentNotes = state.value ?? <Note>[];
        final newList = <Note>[
          for (final n in currentNotes)
            if (n.id == id) syncedNote else n,
        ];
        state = AsyncData(newList);
        await _localRepo.putNote(syncedNote);
      }
    }
  }

  Future<void> updateCalendarEventMeta(
    String id, {
    required String calendarId,
    required String calendarEventId,
  }) async {
    final notes = <Note>[
      for (final n in state.value ?? <Note>[])
        if (n.id == id)
          n.copyWith(calendarId: calendarId, calendarEventId: calendarEventId)
        else
          n,
    ];

    state = AsyncData(notes);
    final noteToSave = notes.firstWhere((n) => n.id == id);
    await _localRepo.putNote(noteToSave);
  }
}
