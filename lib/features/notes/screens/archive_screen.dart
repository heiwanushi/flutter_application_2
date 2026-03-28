import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/notes_filters_provider.dart';
import '../providers/notes_provider.dart';
import '../widgets/event_note_cards.dart';

class ArchiveScreen extends ConsumerWidget {
  const ArchiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final archiveAsync = ref.watch(archivedEventsProvider);

    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: const Text('Архив событий'),
        centerTitle: true,
        backgroundColor: scheme.surface,
        scrolledUnderElevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Очистить архив',
            onPressed: () {
              final archivedNotes = ref.read(archivedEventsProvider).value ?? [];
              if (archivedNotes.isEmpty) return;
              _showClearArchiveConfirm(context, ref);
            },
          ),
        ],
      ),
      body: archiveAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Ошибка: $e')),
        data: (notes) {
          if (notes.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inventory_2_outlined, size: 64, color: scheme.surfaceContainerHighest),
                  const SizedBox(height: 16),
                  Text(
                    'Архив пуст',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            );
          }

          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
            itemCount: notes.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder: (_, i) {
              final note = notes[i];
              return UpcomingEventCard(
                note: note,
                onTap: () {},
                onToggleCompleted: () => ref.read(notesProvider.notifier).toggleCompleted(note.id),
              );
            },
          );
        },
      ),
    );
  }

  void _showClearArchiveConfirm(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.warning_rounded, color: Colors.orange),
        title: const Text('Очистить архив?'),
        content: const Text('Все выполненные события будут удалены навсегда. Вы уверены?'),
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
              ref.read(notesProvider.notifier).clearArchive();
              Navigator.pop(ctx);
            },
            child: const Text('Очистить'),
          ),
        ],
      ),
    );
  }
}
