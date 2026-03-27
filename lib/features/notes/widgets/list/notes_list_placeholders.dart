import 'package:flutter/material.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final int count;
  final ColorScheme scheme;
  final TextTheme tt;

  const SectionHeader({
    super.key,
    required this.title,
    required this.count,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 8),
      child: Text(
        count > 0 ? '$title ($count)' : title,
        style: tt.titleMedium?.copyWith(
          color: scheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

class TagFilterChip extends StatelessWidget {
  final String label;
  final int count;
  final bool selected;
  final ColorScheme scheme;
  final VoidCallback onTap;
  final bool compact;

  const TagFilterChip({
    super.key,
    required this.label,
    required this.count,
    required this.selected,
    required this.scheme,
    required this.onTap,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: selected,
        onSelected: (_) => onTap(),
        showCheckmark: false,
        visualDensity: compact
            ? const VisualDensity(horizontal: -2, vertical: -1)
            : null,
        materialTapTargetSize: compact
            ? MaterialTapTargetSize.shrinkWrap
            : MaterialTapTargetSize.padded,
        labelPadding: EdgeInsets.zero,
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 8 : 10,
        ),
        side: BorderSide.none,
        backgroundColor: scheme.surfaceContainerLow,
        selectedColor: scheme.secondaryContainer,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: TextStyle(
                color: selected
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
                fontWeight: FontWeight.w600,
                fontSize: compact ? 12 : 14,
              ),
            ),
            const SizedBox(width: 6),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 6 : 8,
                vertical: compact ? 1 : 2,
              ),
              decoration: BoxDecoration(
                color: selected
                    ? scheme.primary.withValues(alpha: 0.12)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$count',
                style: TextStyle(
                  color: selected
                      ? scheme.onSecondaryContainer
                      : scheme.onSurfaceVariant,
                  fontSize: compact ? 11 : 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyPlaceholder extends StatelessWidget {
  final ColorScheme scheme;
  final TextTheme tt;
  final bool hasTagFilter;

  const EmptyPlaceholder({
    super.key,
    required this.scheme,
    required this.tt,
    required this.hasTagFilter,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.66,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  hasTagFilter
                      ? Icons.search_off_rounded
                      : Icons.note_alt_outlined,
                  size: 56,
                  color: scheme.outline,
                ),
                const SizedBox(height: 16),
                Text(
                  hasTagFilter
                      ? 'Нет заметок с этим тегом'
                      : 'Пока нет заметок',
                  textAlign: TextAlign.center,
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  hasTagFilter
                      ? 'Выберите другой тег или снимите фильтр.'
                      : 'Создайте первую заметку или потяните вниз, чтобы обновить список.',
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
