import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  final String heroTagPrefix;

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
    this.heroTagPrefix = 'note-',
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tt = theme.textTheme;

    final bool hasCustomColor = note.colorIndex != null;
    final Color cardColor = hasCustomColor
        ? NoteColors.bg(note.colorIndex!, theme.brightness)
        : scheme.surfaceContainerLow;

    final String title = note.title.trim();
    final String content = note.content.trim();

    return Hero(
      tag: '$heroTagPrefix${note.id}',
      child: Card(
        elevation: 0,
        color: cardColor,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: isSelected
              ? BorderSide(color: scheme.primary, width: 2)
              : hasCustomColor
                  ? BorderSide.none
                  : BorderSide(color: scheme.outlineVariant, width: 1),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Stack(
            children: [
              SizedBox(
                height: fixedHeight,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (note.imagePaths.isNotEmpty)
                      _NoteImage(
                        imagePath: note.imagePaths.first,
                        compact: compact,
                      ),
                    
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (title.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 8),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Expanded(
                                    child: Text.rich(
                                      TextSpan(
                                        children: [
                                          if (note.isAiProcessed)
                                            WidgetSpan(
                                              alignment: PlaceholderAlignment.middle,
                                              child: Padding(
                                                padding: const EdgeInsets.only(right: 6),
                                                child: Icon(
                                                  Icons.auto_awesome,
                                                  size: 16,
                                                  color: scheme.primary,
                                                ),
                                              ),
                                            ),
                                          TextSpan(text: title),
                                        ],
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: tt.titleMedium?.copyWith(
                                        fontWeight: FontWeight.w700,
                                        color: scheme.onSurface,
                                        height: 1.2,
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
                            )
                          else if (note.imagePaths.length > 1) ...[
                             Align(
                               alignment: Alignment.centerRight,
                               child: _ImageCountBadge(
                                 count: note.imagePaths.length,
                                 scheme: scheme,
                               ),
                             ),
                             const SizedBox(height: 8),
                          ],
                          
                          if (content.isNotEmpty)
                            Text(
                              content,
                              maxLines: compact
                                  ? (note.imagePaths.isNotEmpty ? 5 : 10)
                                  : (note.imagePaths.isNotEmpty ? 12 : 25),
                              overflow: TextOverflow.ellipsis,
                              style: tt.bodyMedium?.copyWith(
                                color: scheme.onSurfaceVariant,
                                height: 1.5,
                              ),
                            ),
                          
                          if (note.isAiProcessed || note.tags.any((t) => t != 'AI') || note.contacts.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [
                                if (note.eventAt != null)
                                  _EventTagChip(
                                    eventAt: note.eventAt!,
                                    isCompleted: note.isCompleted,
                                    scheme: scheme,
                                  ),
                                ...note.tags
                                    .where((tag) => tag != 'AI')
                                    .take(compact ? 2 : 4)
                                    .map((tag) => _TagChip(label: tag, scheme: scheme)),
                                ...note.contacts
                                    .take(compact ? 1 : 3)
                                    .map((c) => _ContactChip(contact: c, scheme: scheme)),
                              ],
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              if (isSelected) ...[
                Positioned.fill(
                  child: IgnorePointer(
                    child: ColoredBox(
                      color: scheme.primary.withValues(alpha: 0.12),
                    ),
                  ),
                ),
                Positioned(
                  top: 10,
                  right: 10,
                  child: Icon(
                    Icons.check_circle,
                    color: scheme.primary,
                    size: 28,
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

    return AspectRatio(
      aspectRatio: compact ? 16 / 9 : 4 / 3,
      child: imagePath.startsWith('http')
            ? CachedNetworkImage(
                imageUrl: imagePath,
                fit: BoxFit.cover,
                fadeInDuration: const Duration(milliseconds: 250),
                fadeOutDuration: const Duration(milliseconds: 250),
                memCacheWidth: 600,
                placeholder: (context, url) => ColoredBox(
                  color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
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
              fontWeight: FontWeight.w500,
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
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

class _ContactChip extends StatelessWidget {
  final NoteContact contact;
  final ColorScheme scheme;

  const _ContactChip({required this.contact, required this.scheme});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.person_rounded,
            size: 12,
            color: scheme.tertiary,
          ),
          const SizedBox(width: 6),
          Text(
            contact.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: scheme.onTertiaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _EventTagChip extends StatelessWidget {
  final DateTime eventAt;
  final bool isCompleted;
  final ColorScheme scheme;

  const _EventTagChip({
    required this.eventAt,
    required this.isCompleted,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.primaryContainer.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.event_note_rounded,
            size: 12,
            color: scheme.primary,
          ),
          const SizedBox(width: 6),
          Text(
            DateFormat('dd.MM.yy HH:mm').format(eventAt),
            style: TextStyle(
              color: scheme.onPrimaryContainer,
              fontSize: 12,
              fontWeight: FontWeight.w700,
              decoration: isCompleted ? TextDecoration.lineThrough : null,
              decorationColor: scheme.onPrimaryContainer,
              decorationThickness: 2,
            ),
          ),
        ],
      ),
    );
  }
}

