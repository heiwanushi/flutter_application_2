import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/note.dart';
import '../../../../core/utils/note_colors.dart';

class CompactNoteCard extends StatelessWidget {
  final Note note;
  final ColorScheme scheme;
  final bool isSelected;
  final bool isSelectionMode;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const CompactNoteCard({
    super.key,
    required this.note,
    required this.scheme,
    this.isSelected = false,
    this.isSelectionMode = false,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;
    final bgColor = note.colorIndex != null 
        ? NoteColors.bg(note.colorIndex!, brightness).withValues(alpha: 0.5)
        : scheme.surfaceContainerLow;
    
    final onBgColor = note.colorIndex != null
        ? (brightness == Brightness.dark ? Colors.white : Colors.black87)
        : scheme.onSurface;

    final subtitle = _buildSubtitle();

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Card(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: bgColor,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? scheme.primary : (note.colorIndex != null ? Colors.transparent : scheme.outlineVariant),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                if (isSelectionMode) ...[
                  Icon(
                    isSelected ? Icons.check_circle_rounded : Icons.circle_outlined,
                    color: isSelected ? scheme.primary : scheme.outline,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                ] else if (note.isAiProcessed) ...[
                  Icon(
                    Icons.auto_awesome_rounded,
                    size: 18,
                    color: onBgColor.withValues(alpha: 0.7),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title.isEmpty ? 'Без названия' : note.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: onBgColor,
                            ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 2),
                        subtitle,
                      ],
                    ],
                  ),
                ),
                if (note.eventAt != null)
                  Icon(
                    Icons.alarm_rounded,
                    size: 16,
                    color: onBgColor.withValues(alpha: 0.6),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget? _buildSubtitle() {
    final List<String> parts = [];
    
    if (note.eventAt != null) {
      final dateStr = DateFormat('dd.MM HH:mm').format(note.eventAt!);
      parts.add(dateStr);
    }

    if (note.contacts.isNotEmpty) {
      final contactsStr = note.contacts.map((c) => c.name).join(', ');
      parts.add(contactsStr);
    }

    if (parts.isEmpty) return null;

    return Builder(
      builder: (context) {
        final brightness = Theme.of(context).brightness;
        final onBgColor = note.colorIndex != null
            ? (brightness == Brightness.dark ? Colors.white70 : Colors.black54)
            : Theme.of(context).colorScheme.onSurfaceVariant;

        return Text(
          parts.join(' • '),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: onBgColor,
              ),
        );
      },
    );
  }
}
