import 'package:flutter/material.dart';

class SelectionHeader extends StatelessWidget {
  final Set<String> selectedIds;
  final ColorScheme scheme;
  final TextTheme tt;
  final VoidCallback onClose;
  final VoidCallback onTogglePin;
  final Future<void> Function() onDelete;

  const SelectionHeader({
    super.key,
    required this.selectedIds,
    required this.scheme,
    required this.tt,
    required this.onClose,
    required this.onTogglePin,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Container(
        constraints: const BoxConstraints(minHeight: 70),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.secondaryContainer,
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          children: [
            IconButton.filledTonal(
              onPressed: onClose,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.close_rounded),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '${selectedIds.length} выбрано',
                style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton.filledTonal(
              onPressed: onTogglePin,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              icon: const Icon(Icons.push_pin_outlined),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: onDelete,
              constraints: const BoxConstraints.tightFor(width: 44, height: 44),
              padding: EdgeInsets.zero,
              style: IconButton.styleFrom(
                backgroundColor: scheme.error,
                foregroundColor: scheme.onError,
              ),
              icon: const Icon(Icons.delete_outline_rounded),
            ),
          ],
        ),
      ),
    );
  }
}
