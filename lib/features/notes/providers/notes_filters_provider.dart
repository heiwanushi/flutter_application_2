import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings_service.dart';
import '../../../data/models/note.dart';
import 'notes_provider.dart';

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
  for (final n in notes) {
    tags.addAll(n.tags);
  }
  return tags.toList()..sort();
});

final tagCountsProvider = Provider<Map<String, int>>((ref) {
  final notes = ref.watch(notesProvider).value ?? <Note>[];
  final counts = <String, int>{};

  for (final note in notes) {
    for (final tag in note.tags) {
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }

  return counts;
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

final reminderNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  return ref.watch(notesProvider).whenData((notes) {
    final reminders = notes.where((note) => note.eventAt != null).toList();
    reminders.sort((a, b) => a.eventAt!.compareTo(b.eventAt!));
    return reminders;
  });
});
