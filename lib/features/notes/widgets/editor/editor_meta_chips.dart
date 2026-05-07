import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../data/models/note.dart';

class EditorMetaChips extends StatelessWidget {
  final DateTime? eventAt;
  final bool isCompleted;
  final List<String> tags;
  final List<NoteContact> contacts;
  final ColorScheme scheme;
  final VoidCallback onAddContact;
  final VoidCallback onAddTag;
  final VoidCallback onPickEvent;
  final VoidCallback onToggleCompleted;

  const EditorMetaChips({
    super.key,
    required this.eventAt,
    required this.isCompleted,
    required this.tags,
    required this.contacts,
    required this.scheme,
    required this.onAddContact,
    required this.onAddTag,
    required this.onPickEvent,
    required this.onToggleCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // Event Chip
          if (eventAt != null)
            Material(
              color: isCompleted 
                  ? scheme.primaryContainer 
                  : scheme.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: onPickEvent,
                borderRadius: BorderRadius.circular(12),
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 10, top: 4, bottom: 4),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        onPressed: onToggleCompleted,
                        icon: Icon(
                          isCompleted ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                          size: 20,
                          color: isCompleted ? scheme.primary : scheme.onSurfaceVariant.withValues(alpha: 0.6),
                        ),
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        DateFormat('dd.MM.yy HH:mm').format(eventAt!),
                        style: TextStyle(
                          color: isCompleted ? scheme.onPrimaryContainer : scheme.onSurfaceVariant,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          decoration: isCompleted ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            )
          else
            // Button to set event if none exists
            _MetaActionButton(
              icon: Icons.add_alarm_rounded,
              label: 'Событие',
              onTap: onPickEvent,
              scheme: scheme,
            ),

          // Tag Chips
          ...tags.where((t) => t != 'AI').map((t) => Chip(
                label: Text('#$t'),
                backgroundColor: scheme.surfaceContainerHighest,
                labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide.none,
              )),
          
          // Button to add tag
          _MetaActionButton(
            icon: Icons.add_rounded,
            label: 'Тег',
            onTap: onAddTag,
            scheme: scheme,
          ),

          // Contact Chips
          ...contacts.map((c) {
            final hasPhone = c.phoneNumber.trim().isNotEmpty;
            final chip = Chip(
              avatar: Icon(
                hasPhone ? Icons.phone_rounded : Icons.person_outline_rounded,
                size: 14,
                color: hasPhone ? scheme.tertiary : scheme.onSurfaceVariant,
              ),
              label: Text(c.name),
              backgroundColor: hasPhone
                  ? scheme.tertiaryContainer.withValues(alpha: 0.4)
                  : scheme.surfaceContainerHighest,
              labelStyle: TextStyle(
                color: hasPhone ? scheme.onTertiaryContainer : scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              side: BorderSide.none,
            );

            if (!hasPhone) return chip;

            return GestureDetector(
              onTap: () {
                final url = Uri.parse('tel:${c.phoneNumber}');
                launchUrl(url);
              },
              child: chip,
            );
          }),

          // Button to add contact
          _MetaActionButton(
            icon: Icons.person_add_alt_1_rounded,
            label: 'Контакт',
            onTap: onAddContact,
            scheme: scheme,
          ),
        ],
      ),
    );
  }
}

class _MetaActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final ColorScheme scheme;

  const _MetaActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: scheme.primary),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(
                color: scheme.onSurfaceVariant,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

