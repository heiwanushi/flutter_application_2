import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import '../../../data/models/note.dart';
import '../../../data/repositories/notes_repository.dart';
import '../../../data/repositories/firestore_repository.dart';
import '../../../core/services/settings_service.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/sync_service.dart'; // Импорт

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
      try {
        final cloudNotes = await FirestoreRepository(user.uid).fetchNotes();
        // Все заметки из облака считаются синхронизированными
        final syncedCloudNotes = cloudNotes
            .map((n) => n.copyWith(isNoteSynced: true))
            .toList();
        final cloudIds = syncedCloudNotes.map((n) => n.id).toSet();
        final toSync = localNotes
            .where((n) => !cloudIds.contains(n.id))
            .toList();
        final syncedNotes = <Note>[];
        for (final note in toSync) {
          // Синхронизируем с загрузкой картинок
          await _performFullCloudSync(user.uid, note);
          // После синхронизации получаем актуальную версию заметки из облака
          final synced = await FirestoreRepository(
            user.uid,
          ).fetchNoteById(note.id);
          if (synced != null) {
            syncedNotes.add(synced.copyWith(isNoteSynced: true));
          }
        }
        final allNotes = [...syncedCloudNotes, ...syncedNotes];
        await _localRepo.saveAll(allNotes);
        return allNotes;
      } catch (e) {
        return localNotes;
      }
    } else {
      return localNotes;
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
    await _localRepo.saveAll(notes);

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
      final localImages = note.imagePaths.where((img) => !img.startsWith('http')).toList();
      final remoteImages = note.imagePaths.where((img) => img.startsWith('http')).toList();
      final uploadedUrls = await syncService.uploadImages(localImages);
      // Собираем итоговый список: уже существующие ссылки + новые загруженные
      // Если картинка не загрузилась (пустая строка), оставляем локальный путь
      final filteredUrls = [
        ...remoteImages,
        for (int i = 0; i < uploadedUrls.length; i++)
          uploadedUrls[i].isNotEmpty ? uploadedUrls[i] : localImages[i],
      ];
      final syncedNote = note.copyWith(imagePaths: filteredUrls, isNoteSynced: true);

      // 2. Обновляем заметку в Firestore (теперь там ссылки https://...)
      await remoteFirestore.upsertNote(syncedNote);

      // 3. Обновляем локальное состояние, чтобы UI использовал облачные ссылки (для кеша)
      final currentNotes = state.value ?? <Note>[];
      final newList = <Note>[
        for (final n in currentNotes)
          if (n.id == syncedNote.id) syncedNote else n,
      ];
      state = AsyncData(newList);
      await _localRepo.saveAll(newList);
    } catch (e) {
      print('Ошибка фоновой синхронизации: $e');
    }
  }

  Future<void> add({
    required String title,
    required String content,
    required List<String> tags,
    List<String> imagePaths = const [],
    int? colorIndex,
    bool isPinned = false,
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
    );
    final notes = <Note>[...(state.value ?? <Note>[]), note];
    await _persist(notes, noteToSync: note);
  }

  Future<void> editNote(
    String id, {
    required String title,
    required String content,
    required List<String> tags,
    required List<String> imagePaths,
  }) async {
    Note? updatedNote;
    final currentNotes = state.value ?? <Note>[];
    final oldNote = currentNotes.where((n) => n.id == id).isNotEmpty
      ? currentNotes.firstWhere((n) => n.id == id)
      : null;
    // Если были удалены картинки, удаляем их из Supabase
    if (oldNote != null) {
      final removedImages = oldNote.imagePaths.where((img) => !imagePaths.contains(img)).toList();
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
            );
            return updatedNote!;
          })()
        else
          n,
    ];
    if (updatedNote != null) await _persist(notes, noteToSync: updatedNote);
  }

  Future<void> delete(String id) async {
    final currentNotes = state.value ?? <Note>[];
    final noteToDelete = currentNotes.where((n) => n.id == id).isNotEmpty
        ? currentNotes.firstWhere((n) => n.id == id)
        : null;
    // Удаляем картинки из Supabase
    final user = ref.read(authStateProvider).value;
    if (noteToDelete != null && user != null) {
      final syncService = SyncService(user.uid);
      await syncService.deleteImagesByUrls(noteToDelete.imagePaths);
    }
    final notes = <Note>[
      for (final n in currentNotes)
        if (n.id != id) n,
    ];
    await _persist(notes, deletedId: id);
  }

  Future<void> deleteMultiple(Set<String> ids) async {
    final currentNotes = state.value ?? <Note>[];
    final user = ref.read(authStateProvider).value;
    if (user != null) {
      final syncService = SyncService(user.uid);
      // Собираем все картинки для удаления
      final imagesToDelete = <String>[];
      for (final n in currentNotes) {
        if (ids.contains(n.id)) {
          imagesToDelete.addAll(n.imagePaths);
        }
      }
      await syncService.deleteImagesByUrls(imagesToDelete);
    }
    final notes = <Note>[
      for (final n in currentNotes)
        if (!ids.contains(n.id)) n,
    ];
    await _persist(notes, deletedIds: ids);
  }

  Future<void> togglePin(String id) async {
    Note? updatedNote;
    final notes = <Note>[
      for (final n in state.value ?? <Note>[])
        if (n.id == id)
          (() {
            updatedNote = n.copyWith(isPinned: !n.isPinned, isNoteSynced: false);
            return updatedNote!;
          })()
        else
          n,
    ];
    if (updatedNote != null) {
      state = AsyncData(notes);
      await _localRepo.saveAll(notes);
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
        await _localRepo.saveAll(newList);
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
    await _localRepo.saveAll(updatedNotesList);
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
      await _localRepo.saveAll(notes);
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
        await _localRepo.saveAll(newList);
      }
    }
  }
}

// --- Провайдеры настроек (ViewMode, SortMode и т.д.) ---

enum ViewMode { grid, list }

enum SortMode { updatedAt, createdAt, title }

final viewModeProvider = NotifierProvider<ViewModeNotifier, ViewMode>(
  ViewModeNotifier.new,
);

class ViewModeNotifier extends Notifier<ViewMode> {
  @override
  ViewMode build() => ViewMode.grid;
  void toggle() {
    state = state == ViewMode.grid ? ViewMode.list : ViewMode.grid;
    ref.read(settingsServiceProvider).saveViewMode(state.index);
  }

  void setInitial(ViewMode mode) => state = mode;
}

final sortModeProvider = NotifierProvider<SortModeNotifier, SortMode>(
  SortModeNotifier.new,
);

class SortModeNotifier extends Notifier<SortMode> {
  @override
  SortMode build() => SortMode.updatedAt;
  void setMode(SortMode mode) {
    state = mode;
    ref.read(settingsServiceProvider).saveSortMode(state.index);
  }

  void setInitial(SortMode mode) => state = mode;
}

final sortAscProvider = NotifierProvider<SortAscNotifier, bool>(
  SortAscNotifier.new,
);

class SortAscNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() {
    state = !state;
    ref.read(settingsServiceProvider).saveSortAsc(state);
  }

  void setInitial(bool val) => state = val;
}

final searchQueryProvider = StateProvider((_) => '');
final selectedTagProvider = StateProvider<String?>((_) => null);

final allTagsProvider = Provider<List<String>>((ref) {
  final notes = ref.watch(notesProvider).value ?? <Note>[];
  final tags = <String>{};
  for (final n in notes) tags.addAll(n.tags);
  return tags.toList()..sort();
});

final filteredNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final tag = ref.watch(selectedTagProvider);
  final sort = ref.watch(sortModeProvider);
  final asc = ref.watch(sortAscProvider);

  return ref.watch(notesProvider).whenData((notes) {
    var result = notes.where((n) {
      final matchQuery =
          query.isEmpty ||
          n.title.toLowerCase().contains(query) ||
          n.content.toLowerCase().contains(query) ||
          n.tags.any((t) => t.toLowerCase().contains(query));
      final matchTag = tag == null || n.tags.contains(tag);
      return matchQuery && matchTag;
    }).toList();

    result.sort((a, b) {
      if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
      final cmp = switch (sort) {
        SortMode.updatedAt => a.updatedAt.compareTo(b.updatedAt),
        SortMode.createdAt => a.createdAt.compareTo(b.createdAt),
        SortMode.title => a.title.compareTo(b.title),
      };
      return asc ? cmp : -cmp;
    });
    return result;
  });
});
