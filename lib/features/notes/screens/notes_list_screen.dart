import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';

import '../../../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
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
            ? _SelectionHeader(
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
            : _NotesHeader(
                key: const ValueKey('notes-header'),
                sortMode: sortMode,
                sortAsc: sortAsc,
                isGrid: isGrid,
                allTags: allTags,
                tagCounts: tagCounts,
                selectedTag: selectedTag,
                totalNotes: totalNotes,
                scheme: scheme,
                tt: tt,
                onChangeSortMode: (value) =>
                    ref.read(sortModeProvider.notifier).setMode(value),
                onToggleSortDirection: () =>
                    ref.read(sortAscProvider.notifier).toggle(),
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
              child: notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
                data: (notes) {
                  if (notes.isEmpty) {
                    return _EmptyPlaceholder(
                      scheme: scheme,
                      tt: tt,
                      hasTagFilter: selectedTag != null,
                    );
                  }

                  final pinnedNotes = notes
                      .where((note) => note.isPinned)
                      .toList(growable: false);
                  final regularNotes = notes
                      .where((note) => !note.isPinned)
                      .toList(growable: false);

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notesProvider);
                      await ref.read(notesProvider.future);
                    },
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 112),
                      children: [
                        if (pinnedNotes.isNotEmpty) ...[
                          _SectionHeader(
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
                        _SectionHeader(
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
}

class _NotesHeader extends StatelessWidget {
  final SortMode sortMode;
  final bool sortAsc;
  final bool isGrid;
  final List<String> allTags;
  final Map<String, int> tagCounts;
  final String? selectedTag;
  final int totalNotes;
  final ColorScheme scheme;
  final TextTheme tt;
  final ValueChanged<SortMode> onChangeSortMode;
  final VoidCallback onToggleSortDirection;
  final VoidCallback onToggleView;
  final ValueChanged<String?> onSelectTag;

  const _NotesHeader({
    super.key,
    required this.sortMode,
    required this.sortAsc,
    required this.isGrid,
    required this.allTags,
    required this.tagCounts,
    required this.selectedTag,
    required this.totalNotes,
    required this.scheme,
    required this.tt,
    required this.onChangeSortMode,
    required this.onToggleSortDirection,
    required this.onToggleView,
    required this.onSelectTag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _TagFilterChip(
                    label: '\u0412\u0441\u0435',
                    count: totalNotes,
                    selected: selectedTag == null,
                    scheme: scheme,
                    compact: true,
                    onTap: () => onSelectTag(null),
                  ),
                  ...allTags.map(
                    (tag) => _TagFilterChip(
                      label: tag,
                      count: tagCounts[tag] ?? 0,
                      selected: selectedTag == tag,
                      scheme: scheme,
                      compact: true,
                      onTap: () => onSelectTag(selectedTag == tag ? null : tag),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.primaryContainer,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _SortMenuButton(
                  sortMode: sortMode,
                  sortAsc: sortAsc,
                  scheme: scheme,
                  onSelected: onChangeSortMode,
                  onToggleDirection: onToggleSortDirection,
                ),
                const SizedBox(width: 4),
                _CompactIconButton(
                  tooltip: isGrid
                      ? '\u0421\u043f\u0438\u0441\u043e\u043a'
                      : '\u0421\u0435\u0442\u043a\u0430',
                  icon: isGrid
                      ? Icons.grid_view_rounded
                      : Icons.view_agenda_rounded,
                  backgroundColor: scheme.primaryContainer,
                  iconColor: scheme.onPrimaryContainer,
                  onTap: onToggleView,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SortMenuButton extends StatelessWidget {
  final SortMode sortMode;
  final bool sortAsc;
  final ColorScheme scheme;
  final ValueChanged<SortMode> onSelected;
  final VoidCallback onToggleDirection;

  const _SortMenuButton({
    required this.sortMode,
    required this.sortAsc,
    required this.scheme,
    required this.onSelected,
    required this.onToggleDirection,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_SortAction>(
      tooltip: '\u0421\u043e\u0440\u0442\u0438\u0440\u043e\u0432\u043a\u0430',
      onSelected: (value) {
        switch (value) {
          case _SortAction.updatedAt:
            onSelected(SortMode.updatedAt);
          case _SortAction.createdAt:
            onSelected(SortMode.createdAt);
          case _SortAction.title:
            onSelected(SortMode.title);
          case _SortAction.toggleDirection:
            onToggleDirection();
        }
      },
      itemBuilder: (_) => [
        ...SortMode.values.map(
          (mode) => PopupMenuItem<_SortAction>(
            value: _sortActionForMode(mode),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: sortMode == mode
                      ? const Icon(Icons.check_rounded, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(_sortLabel(mode)),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<_SortAction>(
          value: _SortAction.toggleDirection,
          child: Row(
            children: [
              Icon(
                sortAsc ? Icons.north_rounded : Icons.south_rounded,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                sortAsc
                    ? '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0441\u0442\u0430\u0440\u044b\u0435'
                    : '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435',
              ),
            ],
          ),
        ),
      ],
      icon: Icon(
        sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        color: scheme.onPrimaryContainer,
        size: 18,
      ),
      style: IconButton.styleFrom(
        backgroundColor: scheme.primaryContainer,
        fixedSize: const Size(40, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static _SortAction _sortActionForMode(SortMode mode) {
    switch (mode) {
      case SortMode.updatedAt:
        return _SortAction.updatedAt;
      case SortMode.createdAt:
        return _SortAction.createdAt;
      case SortMode.title:
        return _SortAction.title;
    }
  }

  static String _sortLabel(SortMode mode) {
    switch (mode) {
      case SortMode.updatedAt:
        return '\u041f\u043e \u0438\u0437\u043c\u0435\u043d\u0435\u043d\u0438\u044e';
      case SortMode.createdAt:
        return '\u041f\u043e \u0441\u043e\u0437\u0434\u0430\u043d\u0438\u044e';
      case SortMode.title:
        return '\u041f\u043e \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u044e';
    }
  }
}

enum _SortAction { updatedAt, createdAt, title, toggleDirection }

class _SelectionHeader extends StatelessWidget {
  final Set<String> selectedIds;
  final ColorScheme scheme;
  final TextTheme tt;
  final VoidCallback onClose;
  final VoidCallback onTogglePin;
  final Future<void> Function() onDelete;

  const _SelectionHeader({
    super.key,
    required this.selectedIds,
    required this.scheme,
    required this.tt,
    required this.onClose,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: onClose,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${selectedIds.length} выбрано',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton.filledTonal(
              onPressed: onTogglePin,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.push_pin_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onDelete,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const _CompactIconButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final ColorScheme scheme;
  final TextTheme tt;

  const _SectionHeader({
    required this.title,
    required this.count,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 4, 0, 12),
      child: Row(
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: tt.labelMedium?.copyWith(
                color: scheme.onSurfaceVariant,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TagFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final bool compact;

  const _TagFilterChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.scheme,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: compact
            ? const VisualDensity(horizontal: -2, vertical: -1)
            : null,
        materialTapTargetSize: compact
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        labelPadding: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 12 : 14,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 1 : 2,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  final TextTheme tt;
  final bool hasTagFilter;

  const _EmptyPlaceholder({
    required this.scheme,
    required this.tt,
    required this.hasTagFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.66,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasTagFilter
                      ? Icons.search_off_rounded
                      : Icons.note_alt_outlined,
                  size: 56,
                  color: scheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  hasTagFilter
                      ? 'Нет заметок с этим тегом'
                      : 'Пока нет заметок',
                  textAlign: TextAlign.center,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  hasTagFilter
                      ? 'Выберите другой тег или снимите фильтр.'
                      : 'Создайте первую заметку или потяните вниз, чтобы обновить список.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
