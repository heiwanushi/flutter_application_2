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
import '../widgets/list/compact_note_card.dart';
import 'note_editor_screen.dart';

class NotesListScreen extends ConsumerStatefulWidget {
  const NotesListScreen({super.key});

  @override
  ConsumerState<NotesListScreen> createState() => _NotesListScreenState();
}

class _NotesListScreenState extends ConsumerState<NotesListScreen> {
  final Set<String> _expandedFolders = {};
  
  List<String> get _currentPath {
    final currentFolder = ref.read(currentFolderProvider);
    if (currentFolder == null) return [];
    return currentFolder.split('/');
  }
  
  void _navigateToFolder(String? folderPath) {
    setState(() {
      ref.read(currentFolderProvider.notifier).state = folderPath;
      // При переходе в папку сворачиваем все остальные
      if (folderPath != null) {
        _expandedFolders.clear();
        // Разворачиваем все родительские папки для текущего пути
        final parts = folderPath.split('/');
        for (int i = 0; i < parts.length; i++) {
          final path = parts.sublist(0, i + 1).join('/');
          _expandedFolders.add(path);
        }
      } else {
        // Возврат в корень - сворачиваем всё
        _expandedFolders.clear();
      }
    });
  }

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
    final tagTree = ref.watch(tagTreeProvider);
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
                onCollapseAll: () => setState(() => _expandedFolders.clear()),
              ),
      ),
    );

    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            topAreaChild,
            // Лента навигации по папкам
            if (mainMode == MainScreenMode.folders && _currentPath.isNotEmpty)
              _buildBreadcrumbs(scheme, tt),
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
                            tagTree: tagTree,
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
    required List<TagNode> tagTree,
    required Map<String, int> tagCounts,
    required ColorScheme scheme,
    required List<Note> allNotes,
    required bool isGrid,
    required Set<String> selectedIds,
    required bool isSelectionMode,
    required void Function(String id) toggleSelect,
    required void Function(Note note) openView,
  }) {
    final currentFolder = ref.watch(currentFolderProvider);
    
    // Получаем только корневые узлы или узлы текущей папки
    List<TagNode> nodesToShow;
    if (currentFolder == null) {
      // Показываем корневые папки
      nodesToShow = tagTree;
    } else {
      // Находим текущую папку в дереве
      final currentNode = _findNode(tagTree, currentFolder);
      if (currentNode != null && currentNode.children.isNotEmpty) {
        // Показываем вложенные папки
        nodesToShow = currentNode.children;
      } else {
        nodesToShow = [];
      }
    }
    
    // Заметки в текущей папке
    final currentNotes = currentFolder == null
        ? <Note>[] // В корне показываем только папки
        : allNotes
            .where((n) => n.tags.contains(currentFolder) && !n.isDeleted)
            .toList(growable: false);
    currentNotes.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    
    if (nodesToShow.isEmpty && currentNotes.isEmpty) {
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
                  currentFolder == null ? 'Нет папок' : 'Папка пуста',
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

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        // Показываем вложенные папки
        ...nodesToShow.map((node) {
          final tag = node.fullPath;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: FolderCard(
              tag: node.name,
              fullPath: node.fullPath,
              count: node.count,
              scheme: scheme,
              onTap: () => _navigateToFolder(node.fullPath),
            ),
          );
        }),
        // Показываем заметки в текущей папке
        if (currentNotes.isNotEmpty) ...[
          const SizedBox(height: 16),
          ...currentNotes.map((note) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: CompactNoteCard(
              note: note,
              scheme: scheme,
              isSelected: selectedIds.contains(note.id),
              isSelectionMode: isSelectionMode,
              onTap: isSelectionMode ? () => toggleSelect(note.id) : () => openView(note),
              onLongPress: () => toggleSelect(note.id),
            ),
          )),
        ],
      ],
    );
  }

  TagNode? _findNode(List<TagNode> nodes, String fullPath) {
    for (final node in nodes) {
      if (node.fullPath == fullPath) {
        return node;
      }
      final found = _findNode(node.children, fullPath);
      if (found != null) {
        return found;
      }
    }
    return null;
  }

  Widget _buildBreadcrumbs(ColorScheme scheme, TextTheme tt) {
    final path = _currentPath;
    
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(
          bottom: BorderSide(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
      child: Row(
        children: [
          // Кнопка "назад" или "в корень"
          IconButton(
            icon: const Icon(Icons.arrow_back_rounded, size: 20),
            onPressed: () => _navigateToFolder(null),
            tooltip: 'В корень',
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
          ),
          const SizedBox(width: 8),
          // Лента папок
          Expanded(
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: path.length,
              separatorBuilder: (_, __) => Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              itemBuilder: (context, index) {
                final isLast = index == path.length - 1;
                final folderPath = path.sublist(0, index + 1).join('/');
                final folderName = path[index];
                
                return GestureDetector(
                  onTap: isLast ? null : () => _navigateToFolder(folderPath),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        folderName,
                        style: tt.bodyMedium?.copyWith(
                          color: isLast 
                              ? scheme.primary 
                              : scheme.onSurfaceVariant,
                          fontWeight: isLast ? FontWeight.w600 : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}


