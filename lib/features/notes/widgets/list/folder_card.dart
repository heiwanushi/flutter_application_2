import 'package:flutter/material.dart';
import '../../../../core/utils/note_colors.dart';

class FolderCard extends StatelessWidget {
  final String tag;
  final String fullPath;
  final int count;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const FolderCard({
    super.key,
    required this.tag,
    required this.fullPath,
    required this.count,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorIdx = NoteColors.fromCategoryName(tag);
    final brightness = Theme.of(context).brightness;
    final baseColor = colorIdx != null 
        ? NoteColors.bg(colorIdx, brightness).withValues(alpha: 0.7)
        : scheme.surfaceContainerLow;
    
    final onBaseColor = colorIdx != null
        ? (brightness == Brightness.dark ? Colors.white : Colors.black87)
        : scheme.onSurface;

    return Card(
      elevation: 0,
      margin: EdgeInsets.zero,
      color: baseColor,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: colorIdx != null ? Colors.transparent : scheme.outlineVariant,
          width: 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.folder_rounded,
                size: 24,
                color: colorIdx != null ? onBaseColor : scheme.primary,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  tag,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: onBaseColor,
                      ),
                ),
              ),
              const SizedBox(width: 8),
              if (count > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: colorIdx != null ? scheme.surface.withValues(alpha: 0.3) : scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '$count',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          color: colorIdx != null ? onBaseColor : scheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                size: 24,
                color: colorIdx != null ? onBaseColor : scheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class FolderExpansionCard extends StatelessWidget {
  final String tag;
  final String fullPath;
  final int count;
  final ColorScheme scheme;
  final bool isExpanded;
  final int level;
  final VoidCallback onTap;

  const FolderExpansionCard({
    super.key,
    required this.tag,
    required this.fullPath,
    required this.count,
    required this.scheme,
    this.isExpanded = false,
    this.level = 0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colorIdx = level == 0 ? NoteColors.fromCategoryName(tag) : null;
    final brightness = Theme.of(context).brightness;
    final baseColor = colorIdx != null 
        ? NoteColors.bg(colorIdx, brightness).withValues(alpha: 0.7)
        : scheme.surfaceContainerLow;
    
    final onBaseColor = colorIdx != null
        ? (brightness == Brightness.dark ? Colors.white : Colors.black87)
        : scheme.onSurface;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: baseColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isExpanded ? scheme.primary : (colorIdx != null ? Colors.transparent : scheme.outlineVariant),
            width: isExpanded ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                Icon(
                  isExpanded ? Icons.folder_open_rounded : Icons.folder_rounded,
                  size: 20,
                  color: isExpanded ? scheme.primary : (colorIdx != null ? onBaseColor : scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    tag,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: onBaseColor,
                        ),
                  ),
                ),
                const SizedBox(width: 8),
                if (count > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: isExpanded ? scheme.primary : (colorIdx != null ? scheme.surface.withValues(alpha: 0.3) : scheme.secondaryContainer),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '$count',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: isExpanded ? scheme.onPrimary : onBaseColor,
                            fontWeight: FontWeight.bold,
                          ),
                    ),
                  ),
                const SizedBox(width: 8),
                Icon(
                  isExpanded ? Icons.expand_less_rounded : Icons.expand_more_rounded,
                  size: 20,
                  color: colorIdx != null ? onBaseColor : scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


