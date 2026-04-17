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

  const EditorMetaChips({
    super.key,
    required this.eventAt,
    required this.isCompleted,
    required this.tags,
    required this.contacts,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty && eventAt == null && contacts.isEmpty) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          if (eventAt != null)
            Chip(
              avatar: Icon(Icons.event, size: 16, color: scheme.primary),
              label: Text(
                DateFormat('dd.MM.yy HH:mm').format(eventAt!),
                style: TextStyle(
                  decoration: isCompleted ? TextDecoration.lineThrough : null,
                  decorationColor: scheme.onPrimaryContainer,
                  decorationThickness: 2,
                ),
              ),
              backgroundColor: scheme.primaryContainer,
              labelStyle: TextStyle(
                color: scheme.onPrimaryContainer,
                fontSize: 12,
                fontWeight: FontWeight.bold,
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide.none,
            ),
          ...tags.map((t) => Chip(
                label: Text('#$t'),
                backgroundColor: scheme.surfaceContainerHighest,
                labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                side: BorderSide.none,
              )),
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
        ],
      ),
    );
  }
}
