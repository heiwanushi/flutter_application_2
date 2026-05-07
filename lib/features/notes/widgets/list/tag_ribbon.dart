import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/notes_filters_provider.dart';
import '../../../../core/utils/note_colors.dart';

class TagRibbon extends ConsumerWidget {
  const TagRibbon({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTag = ref.watch(selectedTagProvider);
    final tagTree = ref.watch(tagTreeProvider);
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;

    if (tagTree.isEmpty && selectedTag == null) {
      return const SizedBox.shrink();
    }

    // Determine which nodes to show in the ribbon
    List<TagNode> nodesToShow;
    if (selectedTag == null) {
      nodesToShow = tagTree;
    } else {
      final activeNode = findTagNode(tagTree, selectedTag);
      nodesToShow = activeNode?.children ?? [];
    }

    return Container(
      height: 72, // Компактная высота
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          if (selectedTag != null) ...[
            _RibbonActionChip(
              icon: Icons.home_rounded,
              onPressed: () =>
                  ref.read(selectedTagProvider.notifier).state = null,
              scheme: scheme,
            ),
            const SizedBox(width: 8),
            _RibbonActionChip(
              icon: Icons.arrow_back_rounded,
              onPressed: () {
                if (!selectedTag.contains('/')) {
                  ref.read(selectedTagProvider.notifier).state = null;
                } else {
                  final parts = selectedTag.split('/');
                  parts.removeLast();
                  ref.read(selectedTagProvider.notifier).state = parts.join(
                    '/',
                  );
                }
              },
              scheme: scheme,
            ),
            const SizedBox(width: 8),
            Container(
              width: 1,
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
              color: scheme.outlineVariant,
            ),
            const SizedBox(width: 8),
          ],

          ...nodesToShow.map((node) {
            final isSelected = selectedTag == node.fullPath;
            final colorIdx = node.fullPath.contains('/')
                ? null
                : NoteColors.fromCategoryName(node.name);

            final bgColor = colorIdx != null
                ? NoteColors.bg(
                    colorIdx,
                    brightness,
                  ).withValues(alpha: isSelected ? 1.0 : 0.6)
                : (isSelected
                      ? scheme.primaryContainer
                      : scheme.surfaceContainerHigh);

            final fgColor = colorIdx != null
                ? (brightness == Brightness.dark
                      ? Colors.white
                      : Colors.black87)
                : (isSelected
                      ? scheme.onPrimaryContainer
                      : scheme.onSurfaceVariant);

            return Padding(
              padding: const EdgeInsets.only(right: 8, top: 9, bottom: 9),
              child: Material(
                color: bgColor,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: isSelected
                      ? BorderSide(color: scheme.primary, width: 2)
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: () => ref.read(selectedTagProvider.notifier).state =
                      node.fullPath,
                  child: Container(
                    width: 110,
                    height: 46,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    alignment: Alignment.center,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Flexible(
                          child: Text(
                            node.name,
                            maxLines: 2,
                            textAlign: TextAlign.center,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              height: 1.1,
                              fontSize: 12,
                              color: fgColor,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                        if (node.count > 0) ...[
                          const SizedBox(width: 6),
                          Text(
                            '${node.count}',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: fgColor.withValues(alpha: 0.5),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            );
          }),

          if (nodesToShow.isEmpty && selectedTag != null)
            Center(
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  'Конец ветки',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.4),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _RibbonActionChip extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final ColorScheme scheme;

  const _RibbonActionChip({
    required this.icon,
    required this.onPressed,
    required this.scheme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: Material(
        color: scheme.primaryContainer.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(12),
          child: SizedBox(
            width: 44,
            height: 44,
            child: Icon(icon, size: 20, color: scheme.primary),
          ),
        ),
      ),
    );
  }
}
