import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../data/models/note.dart';
import '../providers/notes_filters_provider.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
import '../widgets/list/notes_header.dart';
import '../widgets/list/notes_list_placeholders.dart';
import '../widgets/list/selection_header.dart';
import '../widgets/list/folder_card.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final Set<String> _expandedFolders = {};

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final notesAsync = ref.watch(filteredNotesProvider);
    final allNotesAsync = ref.watch(notesProvider);
    final mainMode = ref.watch(mainScreenModeProvider);
    final viewMode = ref.watch(viewModeProvider);
    final sortMode = ref.watch(sortModeProvider);
    final sortAsc = ref.watch(sortAscProvider);
    final selectedTag = ref.watch(selectedTagProvider);
    final allTags = ref.watch(allTagsProvider);
    final tagCounts = ref.watch(tagCountsProvider);
    final isGrid = viewMode == ViewMode.grid;

    final selectedIds = ref.watch(selectedIdsProvider);
    final isSelectionMode = selectedIds.isNotEmpty;
    final totalNotes = allNotesAsync.value?.length ?? 0;
    void openView(Note note) => Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );

    void toggleSelect(String id) {
      final current = ref.read(selectedIdsProvider);
      ref.read(selectedIdsProvider.notifier).state = current.contains(id)
          ? ({...current}..remove(id))
          : ({...current, id});
    }

    final topAreaChild = SizedBox(
      height: isSelectionMode ? 96 : 72,
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.04),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: isSelectionMode
            ? SelectionHeader(
                key: const ValueKey('selection-header'),
                selectedIds: selectedIds,
                scheme: scheme,
                tt: tt,
                onClose: () =>
                    ref.read(selectedIdsProvider.notifier).state = {},
                onTogglePin: () {
                  ref
                      .read(notesProvider.notifier)
                      .togglePinMultiple(selectedIds);
                  ref.read(selectedIdsProvider.notifier).state = {};
                },
                onDelete: () async {
                  final confirm = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text(
                        '\u0423\u0434\u0430\u043b\u0438\u0442\u044c \u0432\u044b\u0431\u0440\u0430\u043d\u043d\u044b\u0435 \u0437\u0430\u043c\u0435\u0442\u043a\u0438?',
                      ),
                      content: Text(
                        '\u0411\u0443\u0434\u0435\u0442 \u0443\u0434\u0430\u043b\u0435\u043d\u043e: ${selectedIds.length}',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text(
                            '\u041e\u0442\u043c\u0435\u043d\u0430',
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: scheme.error,
                            foregroundColor: scheme.onError,
                          ),
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text(
                            '\u0423\u0434\u0430\u043b\u0438\u0442\u044c',
                          ),
                        ),
                      ],
                    ),
                  );
                  if (confirm == true) {
                    await ref
                        .read(notesProvider.notifier)
                        .deleteMultiple(selectedIds);
                    ref.read(selectedIdsProvider.notifier).state = {};
                  }
                },
              )
            : NotesHeader(
                key: const ValueKey('notes-header'),
                sortMode: sortMode,
                sortAsc: sortAsc,
                mainMode: mainMode,
                isGrid: isGrid,
                selectedTag: selectedTag,
                totalNotes: totalNotes,
                scheme: scheme,
                tt: tt,
                onChangeSortMode: (value) =>
                    ref.read(sortModeProvider.notifier).setMode(value),
                onToggleSortDirection: () =>
                    ref.read(sortAscProvider.notifier).toggle(),
                onToggleMainMode: () =>
                    ref.read(mainScreenModeProvider.notifier).toggle(),
                onToggleView: () =>
                    ref.read(viewModeProvider.notifier).toggle(),
                onSelectTag: (tag) =>
                    ref.read(selectedTagProvider.notifier).state = tag,
              ),
      ),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            topAreaChild,
            Expanded(
              child: mainMode == MainScreenMode.folders
                  ? allNotesAsync.when(
                      loading: () => const Center(child: CircularProgressIndicator()),
                      error: (e, _) => Center(child: Text('Ошибка: $e')),
                      data: (allNotesData) {
                        return RefreshIndicator(
                          onRefresh: () =>
                              ref.read(notesProvider.notifier).refreshSync(),
                          child: _buildFoldersView(
                            context,
                            allTags: allTags,
                            tagCounts: tagCounts,
                            scheme: scheme,
                            allNotes: allNotesData,
                            isGrid: isGrid,
                            selectedIds: selectedIds,
                            isSelectionMode: isSelectionMode,
                            toggleSelect: toggleSelect,
                            openView: openView,
                          ),
                        );
                      },
                    )
                  : notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
                data: (notes) {
                  if (notes.isEmpty) {
                    return RefreshIndicator(
                      onRefresh: () =>
                          ref.read(notesProvider.notifier).refreshSync(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          EmptyPlaceholder(
                            scheme: scheme,
                            tt: tt,
                            hasTagFilter: selectedTag != null,
                          ),
                        ],
                      ),
                    );
                  }

                  final pinnedNotes = notes
                      .where((note) => note.isPinned)
                      .toList(growable: false);
                  final regularNotes = notes
                      .where((note) => !note.isPinned)
                      .toList(growable: false);

                  return RefreshIndicator(
                    onRefresh: () =>
                        ref.read(notesProvider.notifier).refreshSync(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                      children: [
                        if (pinnedNotes.isNotEmpty) ...[
                          SectionHeader(
                            title: 'Закрепленные',
                            count: pinnedNotes.length,
                            scheme: scheme,
                            tt: tt,
                          ),
                          ..._buildNoteSection(
                            context: context,
                            notes: pinnedNotes,
                            isGrid: isGrid,
                            selectedIds: selectedIds,
                            isSelectionMode: isSelectionMode,
                            toggleSelect: toggleSelect,
                            openView: openView,
                          ),
                          const SizedBox(height: 8),
                        ],
                        SectionHeader(
                          title: pinnedNotes.isNotEmpty
                              ? 'Остальные'
                              : 'Все заметки',
                          count: regularNotes.length,
                          scheme: scheme,
                          tt: tt,
                        ),
                        ..._buildNoteSection(
                          context: context,
                          notes: regularNotes,
                          isGrid: isGrid,
                          selectedIds: selectedIds,
                          isSelectionMode: isSelectionMode,
                          toggleSelect: toggleSelect,
                          openView: openView,
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildNoteSection({
    required BuildContext context,
    required List<Note> notes,
    required bool isGrid,
    required Set<String> selectedIds,
    required bool isSelectionMode,
    required void Function(String id) toggleSelect,
    required void Function(Note note) openView,
  }) {
    if (notes.isEmpty) return const [];

    if (!isGrid) {
      return notes
          .map(
            (note) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _createNoteCard(
                note: note,
                selectedIds: selectedIds,
                isSelectionMode: isSelectionMode,
                toggleSelect: toggleSelect,
                openView: openView,
              ),
            ),
          )
          .toList();
    }

    final width = MediaQuery.sizeOf(context).width;
    final crossAxisCount = width >= 960
        ? 4
        : width >= 680
        ? 3
        : 2;

    return [
      MasonryGridView.count(
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        itemCount: notes.length,
        itemBuilder: (context, index) => _createNoteCard(
          note: notes[index],
          selectedIds: selectedIds,
          isSelectionMode: isSelectionMode,
          toggleSelect: toggleSelect,
          openView: openView,
          compact: true,
        ),
      ),
    ];
  }

  Widget _createNoteCard({
    required Note note,
    required Set<String> selectedIds,
    required bool isSelectionMode,
    required void Function(String id) toggleSelect,
    required void Function(Note note) openView,
    bool compact = false,
  }) {
    return NoteCard(
      key: ValueKey('${compact ? 'grid' : 'list'}-${note.id}'),
      note: note,
      isSelected: selectedIds.contains(note.id),
      compact: compact,
      onTap: () => isSelectionMode ? toggleSelect(note.id) : openView(note),
      onLongPress: () => toggleSelect(note.id),
      onDelete: () => ref.read(notesProvider.notifier).delete(note.id),
      onTogglePin: () => ref.read(notesProvider.notifier).togglePin(note.id),
    );
  }

  Widget _buildFoldersView(
    BuildContext context, {
    required List<String> allTags,
    required Map<String, int> tagCounts,
    required ColorScheme scheme,
    required List<Note> allNotes,
    required bool isGrid,
    required Set<String> selectedIds,
    required bool isSelectionMode,
    required void Function(String id) toggleSelect,
    required void Function(Note note) openView,
  }) {
    if (allTags.isEmpty) {
      return ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(
            height: MediaQuery.sizeOf(context).height * 0.6,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.folder_off_rounded, size: 64, color: scheme.surfaceContainerHighest),
                const SizedBox(height: 16),
                Text(
                  'Нет папок',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                ),
              ],
            ),
          )
        ],
      );
    }

    Widget buildFolderCard(String tag) {
      final count = tagCounts[tag] ?? 0;
      final folderNotes = allNotes
          .where((n) => n.tags.contains(tag) && !n.isDeleted)
          .toList(growable: false);

      folderNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      
      final isExpanded = _expandedFolders.contains(tag);

      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FolderExpansionCard(
            tag: tag,
            count: count,
            scheme: scheme,
            isExpanded: isExpanded,
            onTap: () {
              setState(() {
                if (isExpanded) {
                  _expandedFolders.remove(tag);
                } else {
                  _expandedFolders.add(tag);
                }
              });
            },
          ),
          if (isExpanded)
            Padding(
              padding: EdgeInsets.only(bottom: isGrid ? 12 : 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: _buildNoteSection(
                  context: context,
                  notes: folderNotes,
                  isGrid: isGrid,
                  selectedIds: selectedIds,
                  isSelectionMode: isSelectionMode,
                  toggleSelect: toggleSelect,
                  openView: openView,
                ),
              ),
            ),
        ],
      );
    }

    return ListView.builder(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      itemCount: allTags.length,
      itemBuilder: (context, index) => buildFolderCard(allTags[index]),
    );
  }
}


