import 'package:flutter/material.dart';

import '../../providers/notes_filters_provider.dart';
import 'notes_list_placeholders.dart';

class NotesHeader extends StatelessWidget {
  final SortMode sortMode;
  final bool sortAsc;
  final bool isGrid;
  final List<String> allTags;
  final Map<String, int> tagCounts;
  final String? selectedTag;
  final int totalNotes;
  final ColorScheme scheme;
  final TextTheme tt;
  final ValueChanged<SortMode> onChangeSortMode;
  final VoidCallback onToggleSortDirection;
  final VoidCallback onToggleView;
  final ValueChanged<String?> onSelectTag;

  const NotesHeader({
    super.key,
    required this.sortMode,
    required this.sortAsc,
    required this.isGrid,
    required this.allTags,
    required this.tagCounts,
    required this.selectedTag,
    required this.totalNotes,
    required this.scheme,
    required this.tt,
    required this.onChangeSortMode,
    required this.onToggleSortDirection,
    required this.onToggleView,
    required this.onSelectTag,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
      child: Row(
        children: [
          Expanded(
            child: SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  TagFilterChip(
                    label: '\u0412\u0441\u0435', // Все
                    count: totalNotes,
                    selected: selectedTag == null,
                    scheme: scheme,
                    compact: true,
                    onTap: () => onSelectTag(null),
                  ),
                  ...allTags.map(
                    (tag) => TagFilterChip(
                      label: tag,
                      count: tagCounts[tag] ?? 0,
                      selected: selectedTag == tag,
                      scheme: scheme,
                      compact: true,
                      onTap: () => onSelectTag(selectedTag == tag ? null : tag),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 8),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              SortMenuButton(
                sortMode: sortMode,
                sortAsc: sortAsc,
                scheme: scheme,
                onSelected: onChangeSortMode,
                onToggleDirection: onToggleSortDirection,
              ),
              const SizedBox(width: 4),
              CompactIconButton(
                tooltip: isGrid
                    ? '\u0421\u043f\u0438\u0441\u043e\u043a'
                    : '\u0421\u0435\u0442\u043a\u0430',
                icon: isGrid
                    ? Icons.grid_view_rounded
                    : Icons.view_agenda_rounded,
                backgroundColor: scheme.primary,
                iconColor: scheme.onPrimary,
                onTap: onToggleView,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SortMenuButton extends StatelessWidget {
  final SortMode sortMode;
  final bool sortAsc;
  final ColorScheme scheme;
  final ValueChanged<SortMode> onSelected;
  final VoidCallback onToggleDirection;

  const SortMenuButton({
    super.key,
    required this.sortMode,
    required this.sortAsc,
    required this.scheme,
    required this.onSelected,
    required this.onToggleDirection,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<SortAction>(
      tooltip: '\u0421\u043e\u0440\u0442\u0438\u0440\u043e\u0432\u043a\u0430',
      onSelected: (value) {
        switch (value) {
          case SortAction.updatedAt:
            onSelected(SortMode.updatedAt);
          case SortAction.createdAt:
            onSelected(SortMode.createdAt);
          case SortAction.title:
            onSelected(SortMode.title);
          case SortAction.toggleDirection:
            onToggleDirection();
        }
      },
      itemBuilder: (_) => [
        ...SortMode.values.map(
          (mode) => PopupMenuItem<SortAction>(
            value: _sortActionForMode(mode),
            child: Row(
              children: [
                SizedBox(
                  width: 18,
                  child: sortMode == mode
                      ? const Icon(Icons.check_rounded, size: 18)
                      : null,
                ),
                const SizedBox(width: 12),
                Text(_sortLabel(mode)),
              ],
            ),
          ),
        ),
        const PopupMenuDivider(),
        PopupMenuItem<SortAction>(
          value: SortAction.toggleDirection,
          child: Row(
            children: [
              Icon(
                sortAsc ? Icons.north_rounded : Icons.south_rounded,
                size: 18,
              ),
              const SizedBox(width: 12),
              Text(
                sortAsc
                    ? '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u0441\u0442\u0430\u0440\u044b\u0435'
                    : '\u0421\u043d\u0430\u0447\u0430\u043b\u0430 \u043d\u043e\u0432\u044b\u0435',
              ),
            ],
          ),
        ),
      ],
      icon: Icon(
        sortAsc ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
        color: scheme.onPrimary,
        size: 20,
      ),
      style: IconButton.styleFrom(
        backgroundColor: scheme.primary,
        fixedSize: const Size(40, 40),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }

  static SortAction _sortActionForMode(SortMode mode) {
    switch (mode) {
      case SortMode.updatedAt:
        return SortAction.updatedAt;
      case SortMode.createdAt:
        return SortAction.createdAt;
      case SortMode.title:
        return SortAction.title;
    }
  }

  static String _sortLabel(SortMode mode) {
    switch (mode) {
      case SortMode.updatedAt:
        return '\u041f\u043e \u0438\u0437\u043c\u0435\u043d\u0435\u043d\u0438\u044e';
      case SortMode.createdAt:
        return '\u041f\u043e \u0441\u043e\u0437\u0434\u0430\u043d\u0438\u044e';
      case SortMode.title:
        return '\u041f\u043e \u043d\u0430\u0437\u0432\u0430\u043d\u0438\u044e';
    }
  }
}

enum SortAction { updatedAt, createdAt, title, toggleDirection }

class CompactIconButton extends StatelessWidget {
  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;
  final Color? backgroundColor;
  final Color? iconColor;

  const CompactIconButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
    this.backgroundColor,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: backgroundColor ?? scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 20,
              color: iconColor ?? scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}
