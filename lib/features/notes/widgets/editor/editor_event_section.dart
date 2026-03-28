import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/note.dart';

class EditorEventSection extends StatelessWidget {
  final DateTime? eventAt;
  final int reminderMinutes;
  final NoteRepeatMode repeatMode;
  final VoidCallback onPickDateTime;
  final VoidCallback? onClear;
  final ValueChanged<int> onReminderChanged;
  final ValueChanged<NoteRepeatMode> onRepeatChanged;

  const EditorEventSection({
    super.key,
    required this.eventAt,
    required this.reminderMinutes,
    required this.repeatMode,
    required this.onPickDateTime,
    required this.onClear,
    required this.onReminderChanged,
    required this.onRepeatChanged,
  });

  static const _reminderOptions = <int>[5, 10, 15, 30, 60, 120, 180, 1440];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.calendar_today_rounded,
                  size: 20,
                  color: scheme.primary,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Напоминание',
                style: textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const Spacer(),
              if (eventAt != null && onClear != null)
                IconButton(
                  onPressed: onClear,
                  icon: const Icon(Icons.close_rounded),
                  style: IconButton.styleFrom(
                    backgroundColor: scheme.errorContainer.withValues(alpha: 0.5),
                    foregroundColor: scheme.error,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          InkWell(
            onTap: onPickDateTime,
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.access_time_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    eventAt != null
                        ? DateFormat('dd.MM.yyyy HH:mm').format(eventAt!)
                        : 'Выберите дату и время',
                    style: textTheme.bodyMedium?.copyWith(
                      color: eventAt != null ? scheme.onSurface : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (eventAt != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              value: _reminderOptions.contains(reminderMinutes) ? reminderMinutes : 10,
              decoration: InputDecoration(
                labelText: 'Напомнить за',
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                isDense: true,
              ),
              items: _reminderOptions
                  .map(
                    (mins) => DropdownMenuItem(
                      value: mins,
                      child: Text(mins < 60 ? '$mins мин' : '${mins ~/ 60} ч'),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onReminderChanged(value);
              },
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<NoteRepeatMode>(
              value: repeatMode,
              decoration: InputDecoration(
                labelText: 'Повтор',
                filled: true,
                fillColor: scheme.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.45),
                  ),
                ),
                isDense: true,
              ),
              items: NoteRepeatMode.values
                  .map(
                    (mode) => DropdownMenuItem(
                      value: mode,
                      child: Text(mode.label),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onRepeatChanged(value);
              },
            ),
          ],
        ],
      ),
    );
  }
}
