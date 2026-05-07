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
import '../widgets/list/tag_ribbon.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
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
                totalNotes: totalNotes,
                scheme: scheme,
                tt: tt,
                onChangeSortMode: (value) =>
                    ref.read(sortModeProvider.notifier).setMode(value),
                onToggleSortDirection: () =>
                    ref.read(sortAscProvider.notifier).toggle(),
                onToggleView: () =>
                    ref.read(viewModeProvider.notifier).toggle(),
              ),
      ),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            topAreaChild,
            if (mainMode == MainScreenMode.feed && !isSelectionMode)
              const TagRibbon(),
            Expanded(
              child: notesAsync.when(
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
            if (selectedTag != null && !isSelectionMode && mainMode == MainScreenMode.feed)
              _BottomPathBar(
                selectedTag: selectedTag,
                scheme: scheme,
                tt: tt,
                onReset: () => ref.read(selectedTagProvider.notifier).state = null,
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


}

class _BottomPathBar extends ConsumerWidget {
  final String selectedTag;
  final ColorScheme scheme;
  final TextTheme tt;
  final VoidCallback onReset;

  const _BottomPathBar({
    required this.selectedTag,
    required this.scheme,
    required this.tt,
    required this.onReset,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final parts = selectedTag.split('/');
    
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        border: Border(
          top: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          Icon(Icons.folder_open_rounded, size: 16, color: scheme.primary),
          const SizedBox(width: 8),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              reverse: true,
              child: Row(
                children: [
                  for (var i = 0; i < parts.length; i++) ...[
                    if (i > 0)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Icon(Icons.chevron_right_rounded, 
                          size: 14, color: scheme.onSurfaceVariant.withValues(alpha: 0.5)),
                      ),
                    InkWell(
                      onTap: () {
                        final newPath = parts.sublist(0, i + 1).join('/');
                        ref.read(selectedTagProvider.notifier).state = newPath;
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Container(
                        constraints: const BoxConstraints(maxWidth: 120),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                        child: Text(
                          parts[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.labelMedium?.copyWith(
                            color: i == parts.length - 1 
                                ? scheme.primary 
                                : scheme.onSurfaceVariant,
                            fontWeight: i == parts.length - 1 
                                ? FontWeight.bold 
                                : FontWeight.normal,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: onReset,
            icon: const Icon(Icons.close_rounded, size: 18),
            style: IconButton.styleFrom(
              padding: EdgeInsets.zero,
              minimumSize: const Size(24, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ),
        ],
      ),
    );
  }
}


