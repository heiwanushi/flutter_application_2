import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/settings_service.dart';
import '../../../data/models/note.dart';
import 'notes_provider.dart';

// --- Провайдеры настроек (ViewMode, SortMode и т.д.) ---

enum ViewMode { grid, list }

enum MainScreenMode { feed, folders }

enum SortMode { updatedAt, createdAt, title }

final mainScreenModeProvider = NotifierProvider<MainScreenModeNotifier, MainScreenMode>(
  MainScreenModeNotifier.new,
);

class MainScreenModeNotifier extends Notifier<MainScreenMode> {
  @override
  MainScreenMode build() => MainScreenMode.feed;
  void toggle() {
    state = state == MainScreenMode.feed ? MainScreenMode.folders : MainScreenMode.feed;
    ref.read(settingsServiceProvider).saveMainMode(state.index);
  }

  void setInitial(MainScreenMode mode) => state = mode;
}

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
final currentFolderProvider = StateProvider<String?>((_) => null);

final allTagsProvider = Provider<List<String>>((ref) {
  final notes = ref.watch(notesProvider).value ?? <Note>[];
  final tags = <String>{};
  for (final n in notes) {
    for (final tag in n.tags) {
      if (tag != 'AI') tags.add(tag);
    }
  }
  return tags.toList()..sort();
});

final tagCountsProvider = Provider<Map<String, int>>((ref) {
  final notes = ref.watch(notesProvider).value ?? <Note>[];
  final counts = <String, int>{};

  for (final note in notes) {
    for (final tag in note.tags) {
      if (tag == 'AI') continue;
      counts[tag] = (counts[tag] ?? 0) + 1;
    }
  }

  return counts;
});

class TagNode {
  final String name;
  final String fullPath;
  final List<TagNode> children;
  final int count;

  TagNode({
    required this.name,
    required this.fullPath,
    this.children = const [],
    this.count = 0,
  });
}

final tagTreeProvider = Provider<List<TagNode>>((ref) {
  final allTags = ref.watch(allTagsProvider);
  final tagCounts = ref.watch(tagCountsProvider);

  final root = <String, dynamic>{};

  for (final tag in allTags) {
    final parts = tag.split('/');
    var current = root;
    var path = '';
    for (var i = 0; i < parts.length; i++) {
      final part = parts[i];
      path = path.isEmpty ? part : '$path/$part';
      if (!current.containsKey(part)) {
        current[part] = <String, dynamic>{'__count': 0, '__path': path};
      }
      current = current[part] as Map<String, dynamic>;
      if (i == parts.length - 1) {
        current['__count'] = tagCounts[tag] ?? 0;
      }
    }
  }

  int calculateCumulativeCount(Map<String, dynamic> map) {
    int count = map['__count'] as int? ?? 0;
    final keys = map.keys.where((k) => k != '__count' && k != '__path').toList();
    for (final key in keys) {
      count += calculateCumulativeCount(map[key] as Map<String, dynamic>);
    }
    return count;
  }

  List<TagNode> buildNodes(Map<String, dynamic> map) {
    final nodes = <TagNode>[];
    final keys = map.keys.where((k) => k != '__count' && k != '__path').toList()..sort();
    
    for (final key in keys) {
      final data = map[key] as Map<String, dynamic>;
      nodes.add(TagNode(
        name: key,
        fullPath: data['__path'] as String,
        count: calculateCumulativeCount(data),
        children: buildNodes(data),
      ));
    }
    return nodes;
  }

  return buildNodes(root);
});

class FilterParams {
  final List<Note> notes;
  final String query;
  final String? tag;
  final SortMode sort;
  final bool asc;

  FilterParams({
    required this.notes,
    required this.query,
    this.tag,
    required this.sort,
    required this.asc,
  });
}

List<Note> _filterNotesTask(FilterParams params) {
  var result = params.notes.where((n) {
    if (n.isDeleted) return false;
    final matchQuery = params.query.isEmpty ||
        n.title.toLowerCase().contains(params.query) ||
        n.content.toLowerCase().contains(params.query) ||
        n.tags.any((t) => t.toLowerCase().contains(params.query));
    final matchTag = params.tag == null || n.tags.contains(params.tag);
    return matchQuery && matchTag;
  }).toList();

  result.sort((a, b) {
    if (a.isPinned != b.isPinned) return a.isPinned ? -1 : 1;
    final cmp = switch (params.sort) {
      SortMode.updatedAt => a.updatedAt.compareTo(b.updatedAt),
      SortMode.createdAt => a.createdAt.compareTo(b.createdAt),
      SortMode.title => a.title.compareTo(b.title),
    };
    return params.asc ? cmp : -cmp;
  });
  return result;
}

final filteredNotesProvider = FutureProvider<List<Note>>((ref) async {
  final notesAsync = ref.watch(notesProvider);
  final query = ref.watch(searchQueryProvider).toLowerCase();
  final tag = ref.watch(selectedTagProvider);
  final sort = ref.watch(sortModeProvider);
  final asc = ref.watch(sortAscProvider);

  final notes = notesAsync.value ?? [];
  if (notes.isEmpty) return [];

  return compute(
    _filterNotesTask,
    FilterParams(
      notes: notes,
      query: query,
      tag: tag,
      sort: sort,
      asc: asc,
    ),
  );
});

final reminderNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  return ref.watch(notesProvider).whenData((notes) {
    final reminders = notes
        .where((note) =>
            note.eventAt != null && !note.isCompleted && !note.isDeleted)
        .toList();
    reminders.sort((a, b) => a.eventAt!.compareTo(b.eventAt!));
    return reminders;
  });
});

final trashNotesProvider = Provider<AsyncValue<List<Note>>>((ref) {
  return ref.watch(notesProvider).whenData((notes) {
    final trash = notes.where((n) => n.isDeleted).toList();
    trash.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return trash;
  });
});

final archivedEventsProvider = Provider<AsyncValue<List<Note>>>((ref) {
  return ref.watch(notesProvider).whenData((notes) {
    final archived = notes
        .where((n) => n.eventAt != null && n.isCompleted && !n.isDeleted)
        .toList();
    archived.sort((a, b) => b.eventAt!.compareTo(a.eventAt!));
    return archived;
  });
});
