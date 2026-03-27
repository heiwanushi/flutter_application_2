import 'package:flutter/material.dart';

import '../../../../core/utils/note_colors.dart';

class EditorToolbar extends StatelessWidget {
  final List<String> tags;
  final TextEditingController tagCtrl;
  final int? colorIndex;
  final ValueChanged<String> onAddTag;
  final ValueChanged<String> onRemoveTag;
  final ValueChanged<int?> onColorChanged;
  final ColorScheme scheme;
  final TextTheme tt;

  const EditorToolbar({
    super.key,
    required this.tags,
    required this.tagCtrl,
    required this.colorIndex,
    required this.onAddTag,
    required this.onRemoveTag,
    required this.onColorChanged,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final brightness = Theme.of(context).brightness;

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: scheme.outlineVariant.withValues(alpha: 0.35),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Оформление',
            style: tt.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: NoteColors.count + 1,
              itemBuilder: (context, i) {
                final isSelected = i == 0
                    ? colorIndex == null
                    : colorIndex == i - 1;
                return Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(999),
                    onTap: () => onColorChanged(i == 0 ? null : i - 1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: i == 0
                            ? scheme.surfaceContainerHighest
                            : NoteColors.bg(i - 1, brightness),
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected
                              ? scheme.primary
                              : scheme.outlineVariant.withValues(alpha: 0.32),
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      child: isSelected
                          ? Icon(
                              i == 0
                                  ? Icons.format_color_reset_rounded
                                  : Icons.check_rounded,
                              size: 18,
                              color: scheme.primary,
                            )
                          : null,
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Теги',
            style: tt.labelLarge?.copyWith(
              color: scheme.onSurfaceVariant,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...tags.map(
                (t) => InputChip(
                  label: Text(t, style: const TextStyle(fontSize: 12)),
                  onDeleted: () => onRemoveTag(t),
                  backgroundColor: scheme.secondaryContainer.withValues(
                    alpha: 0.32,
                  ),
                ),
              ),
              SizedBox(
                width: 136,
                child: TextField(
                  controller: tagCtrl,
                  style: tt.bodySmall,
                  decoration: InputDecoration(
                    hintText: 'Добавить тег',
                    hintStyle: TextStyle(color: scheme.onSurfaceVariant),
                    filled: true,
                    fillColor: scheme.surfaceContainerLow,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: onAddTag,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
