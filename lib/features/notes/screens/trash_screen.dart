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
    final trashAsync = ref.watch(trashNotesProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Корзина'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.restore_from_trash_rounded),
            tooltip: 'Восстановить все',
            onPressed: () {
              final trashNotes = ref.read(trashNotesProvider).value ?? [];
              if (trashNotes.isEmpty) return;
              ref.read(notesProvider.notifier).restoreAll();
            },
          ),
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
      body: trashAsync.when(
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

          return MasonryGridView.count(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            itemCount: notes.length,
            itemBuilder: (_, i) => _TrashCard(note: notes[i]),
          );
        },
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

class _TrashCard extends ConsumerWidget {
  final Note note;

  const _TrashCard({required this.note});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: scheme.outlineVariant),
      ),
      child: InkWell(
        onTap: () => _showOptions(context, ref),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
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
