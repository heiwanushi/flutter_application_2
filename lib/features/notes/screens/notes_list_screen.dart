import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';
import 'search_screen.dart';

class NotesListScreen extends ConsumerWidget {
  const NotesListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final notesAsync = ref.watch(filteredNotesProvider);
    final viewMode = ref.watch(viewModeProvider);
    final sortMode = ref.watch(sortModeProvider);
    final sortAsc = ref.watch(sortAscProvider);
    final selectedTag = ref.watch(selectedTagProvider);
    final allTags = ref.watch(allTagsProvider);
    final tagCounts = ref.watch(tagCountsProvider);
    final isGrid = viewMode == ViewMode.grid;

    final selectedIds = ref.watch(selectedIdsProvider);
    final isSelectionMode = selectedIds.isNotEmpty;

    void openView(Note note) => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
        );

    void openSearch() => Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => const SearchScreen()),
        );

    void toggleSelect(String id) {
      final current = ref.read(selectedIdsProvider);
      ref.read(selectedIdsProvider.notifier).state =
          current.contains(id) ? ({...current}..remove(id)) : ({...current, id});
    }

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 250),
              child: isSelectionMode
                  ? _buildSelectionHeader(
                      context,
                      ref,
                      selectedIds,
                      scheme,
                      tt,
                    )
                  : _buildNormalHeader(
                      context,
                      ref,
                      openSearch,
                      sortMode,
                      sortAsc,
                      isGrid,
                      scheme,
                      tt,
                    ),
            ),
            if (allTags.isNotEmpty && !isSelectionMode)
              _buildTagsBar(ref, allTags, tagCounts, selectedTag, scheme),
            const Divider(height: 1, thickness: 0.5),
            Expanded(
              child: notesAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Ошибка: $e')),
                data: (notes) {
                  if (notes.isEmpty) {
                    return _EmptyPlaceholder(scheme: scheme, tt: tt);
                  }

                  return RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(notesProvider);
                      await ref.read(notesProvider.future);
                    },
                    child: ListView.builder(
                      padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                      cacheExtent: 1000,
                      itemCount:
                          isGrid ? (notes.length / 2).ceil() : notes.length,
                      itemBuilder: (context, i) {
                        if (!isGrid) {
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 12),
                            child: _createNoteCard(
                              notes[i],
                              selectedIds,
                              isSelectionMode,
                              toggleSelect,
                              openView,
                              ref,
                            ),
                          );
                        }

                        final leftIndex = i * 2;
                        final rightIndex = leftIndex + 1;

                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 12),
                                child: _createNoteCard(
                                  notes[leftIndex],
                                  selectedIds,
                                  isSelectionMode,
                                  toggleSelect,
                                  openView,
                                  ref,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: rightIndex < notes.length
                                  ? Padding(
                                      padding:
                                          const EdgeInsets.only(bottom: 12),
                                      child: _createNoteCard(
                                        notes[rightIndex],
                                        selectedIds,
                                        isSelectionMode,
                                        toggleSelect,
                                        openView,
                                        ref,
                                      ),
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        );
                      },
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

  Widget _createNoteCard(
    Note note,
    Set<String> selectedIds,
    bool isSelectionMode,
    Function toggleSelect,
    Function openView,
    WidgetRef ref,
  ) {
    return NoteCard(
      key: ValueKey(note.id),
      note: note,
      isSelected: selectedIds.contains(note.id),
      onTap: () => isSelectionMode ? toggleSelect(note.id) : openView(note),
      onLongPress: () => toggleSelect(note.id),
      onDelete: () => ref.read(notesProvider.notifier).delete(note.id),
      onTogglePin: () => ref.read(notesProvider.notifier).togglePin(note.id),
    );
  }

  Widget _buildNormalHeader(
    BuildContext context,
    WidgetRef ref,
    VoidCallback onSearch,
    SortMode sortMode,
    bool sortAsc,
    bool isGrid,
    ColorScheme scheme,
    TextTheme tt,
  ) {
    return Container(
      key: const ValueKey('normal'),
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Заметки',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
            ),
          ),
          _TonalBtn(icon: Icons.search_rounded, onTap: onSearch, scheme: scheme),
          const SizedBox(width: 4),
          _SortButton(sortMode: sortMode, scheme: scheme),
          const SizedBox(width: 4),
          _TonalBtn(
            icon: sortAsc
                ? Icons.arrow_upward_rounded
                : Icons.arrow_downward_rounded,
            onTap: () => ref.read(sortAscProvider.notifier).toggle(),
            scheme: scheme,
          ),
          const SizedBox(width: 4),
          _TonalBtn(
            icon: isGrid
                ? Icons.view_agenda_outlined
                : Icons.grid_view_rounded,
            onTap: () => ref.read(viewModeProvider.notifier).toggle(),
            scheme: scheme,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }

  Widget _buildSelectionHeader(
    BuildContext context,
    WidgetRef ref,
    Set<String> selectedIds,
    ColorScheme scheme,
    TextTheme tt,
  ) {
    return Container(
      key: const ValueKey('selection'),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconButton.filledTonal(
            icon: const Icon(Icons.close_rounded),
            onPressed: () => ref.read(selectedIdsProvider.notifier).state = {},
          ),
          const SizedBox(width: 16),
          Text(
            '${selectedIds.length}',
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
          const Spacer(),
          IconButton.filledTonal(
            style: IconButton.styleFrom(
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
            ),
            icon: const Icon(Icons.push_pin_outlined),
            onPressed: () {
              ref.read(notesProvider.notifier).togglePinMultiple(selectedIds);
              ref.read(selectedIdsProvider.notifier).state = {};
            },
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            style: IconButton.styleFrom(backgroundColor: scheme.error),
            icon: const Icon(Icons.delete_outline_rounded),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Удалить выбранные?'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: scheme.error,
                      ),
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Удалить'),
                    ),
                  ],
                ),
              );
              if (confirm == true) {
                ref.read(notesProvider.notifier).deleteMultiple(selectedIds);
                ref.read(selectedIdsProvider.notifier).state = {};
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTagsBar(
    WidgetRef ref,
    List<String> allTags,
    Map<String, int> tagCounts,
    String? selectedTag,
    ColorScheme scheme,
  ) {
    final totalNotes = ref.watch(notesProvider).value?.length ?? 0;

    return Container(
      height: 50,
      padding: const EdgeInsets.only(bottom: 12),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: allTags.length + 1,
        itemBuilder: (context, i) {
          if (i == 0) {
            return _TagChip(
              label: 'Все',
              count: totalNotes,
              selected: selectedTag == null,
              scheme: scheme,
              onTap: () => ref.read(selectedTagProvider.notifier).state = null,
            );
          }

          final tag = allTags[i - 1];
          return _TagChip(
            label: tag,
            count: tagCounts[tag] ?? 0,
            selected: selectedTag == tag,
            scheme: scheme,
            onTap: () => ref.read(selectedTagProvider.notifier).state =
                selectedTag == tag ? null : tag,
          );
        },
      ),
    );
  }
}

class _TonalBtn extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _TonalBtn({
    required this.icon,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      onPressed: onTap,
      icon: Icon(icon, size: 24),
      style: IconButton.styleFrom(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        fixedSize: const Size(48, 48),
      ),
    );
  }
}

class _SortButton extends ConsumerWidget {
  final SortMode sortMode;
  final ColorScheme scheme;

  const _SortButton({required this.sortMode, required this.scheme});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<SortMode>(
      offset: const Offset(0, 48),
      onSelected: (v) => ref.read(sortModeProvider.notifier).setMode(v),
      itemBuilder: (_) {
        return SortMode.values
            .map(
              (m) => PopupMenuItem(
                value: m,
                child: Row(
                  children: [
                    SizedBox(
                      width: 18,
                      child: sortMode == m
                          ? const Icon(Icons.check_rounded, size: 18)
                          : null,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      m == SortMode.updatedAt
                          ? 'По изменению'
                          : m == SortMode.createdAt
                          ? 'По созданию'
                          : 'По названию',
                    ),
                  ],
                ),
              ),
            )
            .toList();
      },
      icon: Icon(
        Icons.sort_rounded,
        size: 24,
        color: scheme.onSecondaryContainer,
      ),
      style: IconButton.styleFrom(
        backgroundColor: scheme.secondaryContainer,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        fixedSize: const Size(48, 48),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _TagChip({
    required this.label,
    required this.count,
    required this.selected,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    final backgroundColor = selected ? scheme.primaryContainer : scheme.surface;
    final foregroundColor =
        selected ? scheme.onPrimaryContainer : scheme.onSurface;
    final borderColor = selected ? scheme.primary : scheme.outlineVariant;
    final counterBackground = selected
        ? scheme.primary.withValues(alpha: 0.14)
        : scheme.surfaceContainerHigh;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: foregroundColor,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: counterBackground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$count',
                    style: TextStyle(
                      color: foregroundColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
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

class _EmptyPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  final TextTheme tt;

  const _EmptyPlaceholder({required this.scheme, required this.tt});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Container(
        height: MediaQuery.of(context).size.height * 0.7,
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.note_alt_outlined, size: 64, color: scheme.outlineVariant),
            const SizedBox(height: 16),
            Text(
              'Нет заметок',
              style: tt.bodyLarge?.copyWith(color: scheme.outline),
            ),
            const SizedBox(height: 8),
            Text(
              'Потяните вниз, чтобы обновить',
              style: tt.labelSmall?.copyWith(color: scheme.outlineVariant),
            ),
          ],
        ),
      ),
    );
  }
}
