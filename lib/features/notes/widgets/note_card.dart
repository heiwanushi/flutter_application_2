import 'dart:io';
import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import '../../../core/utils/note_colors.dart';
import '../../../data/models/note.dart';

// Действия для меню
enum NoteAction { pin, delete }

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final bool isSelected;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    required this.onDelete,
    required this.onTogglePin,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;

    // Цвет фона
    final Color bg = note.colorIndex != null 
        ? NoteColors.bg(note.colorIndex!, brightness) 
        : (note.isPinned ? scheme.secondaryContainer : scheme.surfaceContainerLow);

    // Цвет рамки
    final borderColor = isSelected
        ? scheme.primary
        : (note.isPinned 
            ? scheme.secondary.withValues(alpha: 0.4) 
            : scheme.outlineVariant.withValues(alpha: 0.4));

    return Hero(
      tag: 'note-${note.id}',
      child: RepaintBoundary(
        child: Material(
          color: Colors.transparent,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            height: 300, // ФИКСИРОВАННАЯ ВЫСОТА 300 ПИКСЕЛЕЙ
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: borderColor, 
                width: isSelected ? 3.0 : 1.5,
              ),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: InkWell(
                onTap: onTap,
                onLongPress: onLongPress,
                splashColor: scheme.primary.withValues(alpha: 0.1),
                child: Stack(
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // --- ИЗОБРАЖЕНИЕ ---
                        if (note.imagePaths.isNotEmpty)
                          Stack(
                            children: [
                              note.imagePaths.first.startsWith('http')
                                  ? CachedNetworkImage(
                                      imageUrl: note.imagePaths.first,
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      placeholder: (ctx, url) => Container(
                                        height: 150,
                                        color: Colors.black12,
                                        child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
                                      ),
                                      errorWidget: (ctx, url, error) => const SizedBox.shrink(),
                                    )
                                  : Image.file(
                                      File(note.imagePaths.first),
                                      height: 150,
                                      width: double.infinity,
                                      fit: BoxFit.cover,
                                      cacheWidth: 400,
                                      errorBuilder: (ctx, err, stack) => const SizedBox.shrink(),
                                    ),
                              // Метка количества фото
                              if (note.imagePaths.length > 1)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black54,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.photo_library, color: Colors.white, size: 14),
                                        const SizedBox(width: 4),
                                        Text(
                                          '${note.imagePaths.length}',
                                          style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              // Метка "Не синхронизировано" для всей заметки
                              if (!note.isNoteSynced)
                                Positioned(
                                  bottom: 8,
                                  left: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.orange.shade700.withOpacity(0.85),
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.sync_problem, color: Colors.white, size: 14),
                                        SizedBox(width: 4),
                                        Text('Не синхронизировано', style: TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        // --- КОНТЕНТ ---
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    if (note.isPinned)
                                      Padding(
                                        padding: const EdgeInsets.only(right: 6),
                                        child: Icon(Icons.push_pin_rounded, size: 14, color: scheme.secondary),
                                      ),
                                    Expanded(
                                      child: Text(
                                        note.title.isNotEmpty ? note.title : 'Без названия',
                                        maxLines: 2, // До 2-х строк для заголовка
                                        overflow: TextOverflow.ellipsis,
                                        style: tt.titleSmall?.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: note.title.isNotEmpty ? scheme.onSurface : scheme.onSurfaceVariant.withValues(alpha: 0.5),
                                        ),
                                      ),
                                    ),
                                    if (!isSelected)
                                      _MoreMenu(
                                        isPinned: note.isPinned, 
                                        onTogglePin: onTogglePin, 
                                        onDelete: onDelete,
                                      ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                // ТЕКСТ ЗАМЕТКИ
                                Expanded(
                                  child: Text(
                                    note.content.isNotEmpty ? note.content : 'Пустая заметка',
                                    // Максимум строк, чтобы заполнить карточку 300px
                                    maxLines: note.imagePaths.isNotEmpty ? 4 : 9, 
                                    overflow: TextOverflow.ellipsis,
                                    style: tt.bodyMedium?.copyWith(
                                      color: scheme.onSurfaceVariant,
                                      height: 1.4,
                                    ),
                                  ),
                                ),
                                // ТЕГИ
                                if (note.tags.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Wrap(
                                    spacing: 4,
                                    runSpacing: 4,
                                    children: note.tags.take(3).map((t) => _Pill(t, scheme)).toList(),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    // ИНДИКАТОР ВЫБОРА
                    if (isSelected)
                      Positioned(
                        top: 12,
                        left: 12,
                        child: Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: scheme.primary,
                            shape: BoxShape.circle,
                            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 4)],
                          ),
                          child: const Icon(Icons.check_rounded, color: Colors.white, size: 20),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final ColorScheme scheme;
  const _Pill(this.label, this.scheme);

  @override
  Widget build(BuildContext context) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer.withValues(alpha: 0.5), 
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          label, 
          style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
        ),
      );
}

class _MoreMenu extends StatelessWidget {
  final bool isPinned;
  final VoidCallback onTogglePin;
  final VoidCallback onDelete;

  const _MoreMenu({
    required this.isPinned, 
    required this.onTogglePin, 
    required this.onDelete,
  });

  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.delete_outline_rounded, color: Colors.red),
        title: const Text('Удалить?'),
        content: const Text('Заметка исчезнет навсегда.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton.tonal(
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm == true) onDelete();
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<NoteAction>(
      icon: const Icon(Icons.more_vert, size: 18),
      padding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      onSelected: (action) {
        if (action == NoteAction.pin) onTogglePin();
        else if (action == NoteAction.delete) _confirmDelete(context);
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: NoteAction.pin,
          child: Row(children: [
            Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin_rounded, size: 20),
            const SizedBox(width: 12),
            Text(isPinned ? 'Открепить' : 'Закрепить'),
          ]),
        ),
        PopupMenuItem(
          value: NoteAction.delete,
          child: const Row(children: [
            Icon(Icons.delete_outline_rounded, size: 20, color: Colors.red),
            SizedBox(width: 12),
            Text('Удалить', style: TextStyle(color: Colors.red)),
          ]),
        ),
      ],
    );
  }
}