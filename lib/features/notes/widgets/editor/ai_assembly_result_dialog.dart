import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../data/models/note.dart';

class AIAssemblyResultDialog extends StatelessWidget {
  final List<NoteContact> contacts;
  final DateTime? eventAt;
  final List<String> tags;
  final String? error;

  const AIAssemblyResultDialog({
    super.key,
    this.contacts = const [],
    this.eventAt,
    this.tags = const [],
    this.error,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isError = error != null;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: scheme.surfaceContainerHigh,
      contentPadding: const EdgeInsets.only(top: 16, left: 24, right: 24, bottom: 8),
      title: Column(
        children: [
          CircleAvatar(
            radius: 32,
            backgroundColor: isError 
                ? scheme.errorContainer 
                : scheme.primaryContainer,
            child: Icon(
              isError ? Icons.error_outline : Icons.check_circle_outline,
              size: 40,
              color: isError ? scheme.error : scheme.primary,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            isError ? 'Упс! Проблема' : 'ИИ Сборка завершена ✨',
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: scheme.onSurface,
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          children: [
            if (isError)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  error!,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              Text(
                'Нейросеть проанализировала заметку и структурировала информацию:',
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              _buildResultItem(
                context,
                Icons.event_note,
                'Событие',
                eventAt != null
                    ? DateFormat('d MMMM, HH:mm', 'ru').format(eventAt!)
                    : 'Не обнаружено',
                eventAt != null ? scheme.secondary : null,
              ),
              const SizedBox(height: 12),
              _buildResultItem(
                context,
                Icons.people_outline,
                'Контакты',
                contacts.isNotEmpty
                    ? contacts.map((c) => c.name).join(', ')
                    : 'Не обнаружены',
                contacts.isNotEmpty ? scheme.tertiary : null,
              ),
              const SizedBox(height: 12),
              _buildResultItem(
                context,
                Icons.label_outline,
                'Теги',
                tags.isNotEmpty ? tags.join(', ') : 'Без тегов',
                tags.isNotEmpty ? scheme.primary : null,
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
      actionsAlignment: MainAxisAlignment.center,
      actions: [
        FilledButton(
          onPressed: () => Navigator.of(context).pop(),
          style: FilledButton.styleFrom(
            minimumSize: const Size(180, 52),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          ),
          child: const Text('Понятно'),
        ),
      ],
    );
  }

  Widget _buildResultItem(
    BuildContext context,
    IconData icon,
    String label,
    String value,
    Color? accentColor,
  ) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final isActive = accentColor != null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isActive 
            ? accentColor.withValues(alpha: 0.08) 
            : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: isActive ? Border.all(color: accentColor.withValues(alpha: 0.2)) : null,
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 20,
            color: isActive ? accentColor : scheme.onSurfaceVariant.withValues(alpha: 0.5),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                  ),
                ),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: isActive ? FontWeight.w600 : FontWeight.normal,
                    color: isActive ? scheme.onSurface : scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Icon(
              Icons.check,
              size: 16,
              color: accentColor,
            ),
        ],
      ),
    );
  }
}
