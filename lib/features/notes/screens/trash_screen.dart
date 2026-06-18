import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:intl/intl.dart';

import '../../../data/models/note.dart';
import '../providers/notes_filters_provider.dart';
import '../providers/notes_provider.dart';

class TrashScreen extends ConsumerWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final trashAsync = ref.watch(trashNotesProvider);
    final selectedIds = ref.watch(selectedIdsProvider);
    final isSelectionMode = selectedIds.isNotEmpty;

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: isSelectionMode
          ? null
          : AppBar(
              title: const Text('Корзина'),
              centerTitle: true,
              backgroundColor: scheme.surface,
              scrolledUnderElevation: 0,
              actions: [
                IconButton(
                  icon: const Icon(Icons.delete_sweep_rounded),
                  tooltip: 'Очистить корзину',
                  onPressed: () {
                    final trashNotes = ref.read(trashNotesProvider).value ?? [];
                    if (trashNotes.isEmpty) return;
                    _showEmptyTrashConfirm(context, ref);
                  },
                ),
              ],
            ),
      body: SafeArea(
        child: trashAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.delete_outline_rounded, size: 64, color: scheme.surfaceContainerHighest),
                  const SizedBox(height: 16),
                  Text(
                    'Корзина пуста',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          final width = MediaQuery.sizeOf(context).width;
          final crossAxisCount = width >= 960 ? 4 : width >= 680 ? 3 : 2;

          final visibleIds = notes.map((note) => note.id).toSet();
          final allVisibleSelected = visibleIds.isNotEmpty && visibleIds.every(selectedIds.contains);

          return Column(
            children: [
              if (isSelectionMode)
                _TrashSelectionHeader(
                  selectedIds: selectedIds,
                  scheme: scheme,
                  tt: tt,
                  onClose: () => ref.read(selectedIdsProvider.notifier).state = {},
                  onSelectAll: () {
                    ref.read(selectedIdsProvider.notifier).state = allVisibleSelected
                        ? selectedIds.difference(visibleIds)
                        : {...selectedIds, ...visibleIds};
                  },
                  onRestore: () {
                    for (final id in selectedIds) {
                      ref.read(notesProvider.notifier).restore(id);
                    }
                    ref.read(selectedIdsProvider.notifier).state = {};
                  },
                  onDeleteForever: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text('Удалить выбранные заметки навсегда?'),
                        content: Text('Будет удалено: ${selectedIds.length}'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: const Text('Отмена'),
                          ),
                          FilledButton(
                            style: FilledButton.styleFrom(
                              backgroundColor: scheme.error,
                              foregroundColor: scheme.onError,
                            ),
                            onPressed: () => Navigator.pop(ctx, true),
                            child: const Text('Удалить'),
                          ),
                        ],
                      ),
                    );
                    if (confirm == true) {
                      for (final id in selectedIds) {
                        await ref.read(notesProvider.notifier).permanentlyDelete(id);
                      }
                      ref.read(selectedIdsProvider.notifier).state = {};
                    }
                  },
                ),
              Expanded(
                child: MasonryGridView.count(
                  padding: EdgeInsets.fromLTRB(
                    16,
                    16,
                    16,
                    16 + MediaQuery.of(context).padding.bottom,
                  ),
                  crossAxisCount: crossAxisCount,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  itemCount: notes.length,
                  itemBuilder: (_, i) => _TrashCard(
                    note: notes[i],
                    isSelected: selectedIds.contains(notes[i].id),
                    isSelectionMode: isSelectionMode,
                    onToggleSelect: () {
                      final current = ref.read(selectedIdsProvider);
                      ref.read(selectedIdsProvider.notifier).state = current.contains(notes[i].id)
                          ? ({...current}..remove(notes[i].id))
                          : ({...current, notes[i].id});
                    },
                  ),
                ),
              ),
            ],
          );
        },
        ),
      ),
    );
  }

  void _showEmptyTrashConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded, color: Colors.red),
        title: const Text('Очистить корзину?'),
        content: const Text('Все заметки в корзине будут удалены навсегда. Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () {
              ref.read(notesProvider.notifier).emptyTrash();
              Navigator.pop(ctx);
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}

class _TrashSelectionHeader extends StatelessWidget {
  final Set<String> selectedIds;
  final ColorScheme scheme;
  final TextTheme tt;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onRestore;
  final VoidCallback onDeleteForever;

  const _TrashSelectionHeader({
    required this.selectedIds,
    required this.scheme,
    required this.tt,
    required this.onClose,
    required this.onSelectAll,
    required this.onRestore,
    required this.onDeleteForever,
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
              onPressed: onSelectAll,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: 'Выбрать все',
              icon: const Icon(Icons.select_all_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: onRestore,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              tooltip: 'Восстановить',
              icon: const Icon(Icons.restore_from_trash_rounded),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onDeleteForever,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              tooltip: 'Удалить навсегда',
              icon: const Icon(Icons.delete_forever_rounded),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrashCard extends ConsumerWidget {
  final Note note;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onToggleSelect;

  const _TrashCard({
    required this.note,
    required this.isSelected,
    required this.isSelectionMode,
    required this.onToggleSelect,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      color: isSelected ? scheme.secondaryContainer.withValues(alpha: 0.35) : null,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isSelected ? scheme.primary : scheme.outlineVariant,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: () => isSelectionMode ? onToggleSelect() : _showOptions(context, ref),
        onLongPress: () => isSelectionMode ? null : onToggleSelect(),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (note.title.isNotEmpty) ...[
                    Text(
                      note.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                  ],
                  if (note.content.isNotEmpty) ...[
                    Text(
                      note.content,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                    const SizedBox(height: 12),
                  ],
                  Text(
                    'Удалено: ${DateFormat('dd.MM.yyyy', 'ru').format(note.updatedAt)}',
                    style: tt.labelSmall?.copyWith(color: scheme.outline),
                  ),
                ],
              ),
              if (isSelectionMode)
                Positioned(
                  top: 0,
                  right: 0,
                  child: Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                    color: isSelected ? scheme.primary : scheme.outline,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _showOptions(BuildContext context, WidgetRef ref) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.restore_from_trash_rounded),
              title: const Text('Восстановить'),
              onTap: () {
                ref.read(notesProvider.notifier).restore(note.id);
                Navigator.pop(ctx);
              },
            ),
            ListTile(
              leading: Icon(Icons.delete_forever_rounded, color: Theme.of(context).colorScheme.error),
              title: Text('Удалить навсегда', style: TextStyle(color: Theme.of(context).colorScheme.error)),
              onTap: () {
                ref.read(notesProvider.notifier).permanentlyDelete(note.id);
                Navigator.pop(ctx);
              },
            ),
          ],
        ),
      ),
    );
  }
}
