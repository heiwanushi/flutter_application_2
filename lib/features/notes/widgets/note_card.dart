import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../../core/utils/note_colors.dart';
import '../../../data/models/note.dart';

class NoteCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;
  final VoidCallback onDelete;
  final VoidCallback onTogglePin;
  final bool isSelected;
  final bool compact;
  final double? fixedHeight;

  const NoteCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onLongPress,
    required this.onDelete,
    required this.onTogglePin,
    this.isSelected = false,
    this.compact = false,
    this.fixedHeight,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tt = theme.textTheme;

    // В Pixel OS (Google Keep) цветные заметки имеют сплошной цвет без обводки.
    // Обычные заметки используют surfaceContainerLow и тонкую обводку.
    final bool hasCustomColor = note.colorIndex != null;
    final Color cardColor = hasCustomColor
        ? NoteColors.bg(note.colorIndex!, theme.brightness)
        : scheme.surfaceContainerLow;

    final String title = note.title.trim().isEmpty ? 'Без названия' : note.title;
    final String content = note.content.trim().isEmpty ? 'Пустая заметка' : note.content.trim();

    return Hero(
      tag: 'note-${note.id}',
      child: Card(
        // Нативный M3: Отключаем тени, используем цвета для иерархии
        elevation: 0,
        color: cardColor,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16), // Классический радиус Pixel OS
          side: isSelected
              ? BorderSide(color: scheme.primary, width: 2) // Акцент при выделении
              : hasCustomColor
                  ? BorderSide.none // Нет рамки, если есть цвет
                  : BorderSide(color: scheme.outlineVariant, width: 1), // Стандартная рамка
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          // Сплэш эффект (ripple) будет автоматически цвета onSurface (или primary при выделении)
          child: Stack(
            children: [
              SizedBox(
                height: fixedHeight,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Картинка
                      if (note.imagePaths.isNotEmpty) ...[
                        _NoteImage(
                          imagePath: note.imagePaths.first,
                          compact: compact,
                        ),
                        const SizedBox(height: 12),
                      ],
                      
                      // Заголовок и бейдж картинок
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: tt.titleMedium?.copyWith(
                                // Material 3 использует вес w500 (Medium) для заголовков карточек
                                fontWeight: FontWeight.w500,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          if (note.imagePaths.length > 1) ...[
                            const SizedBox(width: 8),
                            _ImageCountBadge(
                              count: note.imagePaths.length,
                              scheme: scheme,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 8),
                      
                      // Текст заметки
                      Text(
                        content,
                        maxLines: compact
                            ? (note.imagePaths.isNotEmpty ? 2 : 4)
                            : (note.imagePaths.isNotEmpty ? 3 : 6),
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                          height: 1.4, // Комфортный межстрочный интервал (как в Keep)
                        ),
                      ),
                      
                      // Теги
                      if (note.tags.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: note.tags
                              .take(compact ? 2 : 3)
                              .map((tag) => _TagChip(label: tag, scheme: scheme))
                              .toList(),
                        ),
                      ],
                    ],
                  ),
                ),
              ),

              // Идеальное нативное выделение (как в Google Photos / Keep на Android 15)
              if (isSelected) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      // Легкая тонировка поверх всей карточки
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  top: 12,
                  right: 12,
                  child: Icon(
                    Icons.check_circle, // Нативная залитая галочка Material
                    color: scheme.primary,
                    size: 24,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NoteImage extends StatelessWidget {
  final String imagePath;
  final bool compact;

  const _NoteImage({required this.imagePath, required this.compact});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ClipRRect(
      borderRadius: BorderRadius.circular(12), // Внутренняя картинка чуть меньше внешнего радиуса
      child: AspectRatio(
        aspectRatio: compact ? 16 / 9 : 16 / 10,
        child: imagePath.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: imagePath,
                fit: BoxFit.cover,
                placeholder: (context, url) => ColoredBox(
                  color: scheme.surfaceContainerHighest,
                  child: Center(
                    child: CircularProgressIndicator(color: scheme.primary),
                  ),
                ),
                errorWidget: (context, url, error) => _ImageFallback(scheme: scheme),
              )
            : Image.file(
                File(imagePath),
                fit: BoxFit.cover,
                cacheWidth: 640,
                errorBuilder: (context, error, stackTrace) =>
                    _ImageFallback(scheme: scheme),
              ),
      ),
    );
  }
}

class _ImageFallback extends StatelessWidget {
  final ColorScheme scheme;

  const _ImageFallback({required this.scheme});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: scheme.surfaceContainerHighest,
      child: Center(
        child: Icon(Icons.broken_image_outlined, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _ImageCountBadge extends StatelessWidget {
  final int count;
  final ColorScheme scheme;

  const _ImageCountBadge({required this.count, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.photo_library_outlined,
            size: 14,
            color: scheme.onSecondaryContainer,
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: TextStyle(
              color: scheme.onSecondaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w500, // Убрали жирность
            ),
          ),
        ],
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final ColorScheme scheme;

  const _TagChip({required this.label, required this.scheme});

  @override
  Widget build(BuildContext context) {
    // В Android 15 чипы имеют скругление 8 dp и цвет secondaryContainer
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label, // Хештег '#' убрали, так как в Android теги пишутся без него (в чипах)
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(
          color: scheme.onSecondaryContainer,
          fontSize: 12,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}