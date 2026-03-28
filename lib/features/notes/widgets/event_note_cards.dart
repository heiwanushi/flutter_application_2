import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../data/models/note.dart';

class TodayEventCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onToggleCompleted;

  const TodayEventCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // Используем Filled Card (залитая карточка) для важных элементов в M3.
    // Убираем градиент, так как Material 3 предпочитает сплошные цвета (primaryContainer).
    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      clipBehavior: Clip.antiAlias, // Обеспечивает обрезку эффекта нажатия (ripple) по углам
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: note.isCompleted ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _TimeBadge(
                        label: DateFormat('HH:mm').format(note.eventAt!),
                        backgroundColor: scheme.onPrimaryContainer.withValues(alpha: 0.12),
                        foregroundColor: scheme.onPrimaryContainer,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        note.title.isNotEmpty ? note.title : 'Без названия',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleLarge?.copyWith(
                          color: scheme.onPrimaryContainer,
                          fontWeight: FontWeight.w600,
                          decoration: note.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.content.isNotEmpty ? note.content : 'Пустая заметка',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                        ),
                      ),
                    ],
                  ),
                ),
                if (onToggleCompleted != null)
                  Checkbox(
                    value: note.isCompleted,
                    onChanged: (_) => onToggleCompleted!(),
                    activeColor: scheme.onPrimaryContainer,
                    checkColor: scheme.primaryContainer,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class UpcomingEventCard extends StatelessWidget {
  final Note note;
  final VoidCallback onTap;
  final VoidCallback? onToggleCompleted;

  const UpcomingEventCard({
    super.key,
    required this.note,
    required this.onTap,
    this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    // В M3 для элементов списков идеально подходит Outlined Card (карточка с контуром)
    return Card.outlined(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: note.isCompleted ? 0.5 : 1.0,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Плашка с датой переделана под стандартный вид secondaryContainer
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: scheme.secondaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        DateFormat('dd').format(note.eventAt!),
                        style: tt.titleMedium?.copyWith(
                          color: scheme.onSecondaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        DateFormat('MMM', 'ru').format(note.eventAt!),
                        style: tt.labelSmall?.copyWith(
                          color: scheme.onSecondaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        note.title.isNotEmpty ? note.title : 'Без названия',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          decoration: note.isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        DateFormat('EEEE, HH:mm', 'ru').format(note.eventAt!),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.labelMedium?.copyWith(
                          color: scheme.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        note.content.isNotEmpty ? note.content : 'Пустая заметка',
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: tt.bodyMedium?.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                if (onToggleCompleted != null) ...[
                  const SizedBox(width: 8),
                  Checkbox(
                    value: note.isCompleted,
                    onChanged: (_) => onToggleCompleted!(),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TimeBadge extends StatelessWidget {
  final String label;
  final Color backgroundColor;
  final Color foregroundColor;

  const _TimeBadge({
    required this.label,
    required this.backgroundColor,
    required this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    // В M3 небольшие элементы интерфейса (чипы, бейджи) обычно имеют скругление 8
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: foregroundColor,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}