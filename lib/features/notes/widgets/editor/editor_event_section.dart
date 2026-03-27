import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class EditorEventSection extends StatelessWidget {
  final DateTime? eventAt;
  final int reminderMinutes;
  final VoidCallback onPickDateTime;
  final VoidCallback? onClear;
  final ValueChanged<int> onReminderChanged;

  const EditorEventSection({
    super.key,
    required this.eventAt,
    required this.reminderMinutes,
    required this.onPickDateTime,
    required this.onClear,
    required this.onReminderChanged,
  });

  static const _reminderOptions = <int>[5, 10, 15, 30, 60, 120, 180, 1440];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final formattedDate = eventAt == null
        ? 'Дата и время не выбраны'
        : DateFormat('dd.MM.yyyy, HH:mm').format(eventAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Событие и напоминание',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Убрать событие',
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onPickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: eventAt == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (eventAt != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: reminderMinutes,
              decoration: InputDecoration(
                labelText: 'Напомнить',
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
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text(_reminderLabel(minutes)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onReminderChanged(value);
              },
            ),
          ],
        ],
      ),
    );
  }

  String _reminderLabel(int minutes) {
    if (minutes < 60) return 'За $minutes мин';
    if (minutes < 1440) return 'За ${minutes ~/ 60} ч';
    return 'За ${minutes ~/ 1440} д';
  }
}
