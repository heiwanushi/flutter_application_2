import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/note_editor_provider.dart';
import '../../../../data/models/note.dart';

class EditorAppBar extends ConsumerWidget implements PreferredSizeWidget {
  final Note? note;
  final VoidCallback onBack;
  final VoidCallback onShowColorPicker;
  final VoidCallback onDelete;
  final VoidCallback onShowAI;
  final VoidCallback onTogglePreview;

  const EditorAppBar({
    super.key,
    required this.note,
    required this.onBack,
    required this.onShowColorPicker,
    required this.onDelete,
    required this.onShowAI,
    required this.onTogglePreview,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noteEditorProvider(note));
    final notifier = ref.read(noteEditorProvider(note).notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tt = theme.textTheme;

    return AppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      titleSpacing: 0,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: _EditorIconButton(
          icon: Icons.arrow_back_rounded,
          onTap: onBack,
        ),
      ),
      title: note == null
          ? Text(
              'Новая заметка',
              style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            )
          : null,
      actions: [
        _EditorIconButton(
          icon: Icons.undo_rounded,
          onTap: notifier.canUndo ? notifier.undo : null,
        ),
        const SizedBox(width: 8),
        _EditorIconButton(
          icon: Icons.redo_rounded,
          onTap: notifier.canRedo ? notifier.redo : null,
        ),
        const SizedBox(width: 8),
        _EditorIconButton(
          icon: Icons.palette_outlined,
          onTap: onShowColorPicker,
        ),
        const SizedBox(width: 8),
        if (note != null)
          _EditorIconButton(
            icon: Icons.delete_outline_rounded,
            onTap: onDelete,
            color: scheme.errorContainer,
            foregroundColor: scheme.onErrorContainer,
          ),
        if (note != null) const SizedBox(width: 8),
        _EditorIconButton(
          icon: state.isPreviewMode ? Icons.edit_note_rounded : Icons.visibility_outlined,
          onTap: onTogglePreview,
        ),
        const SizedBox(width: 8),
        _EditorIconButton(
          icon: Icons.auto_awesome_rounded,
          onTap: onShowAI,
        ),
        const SizedBox(width: 8),
        _EditorIconButton(
          icon: state.isPinned
              ? Icons.push_pin_rounded
              : Icons.push_pin_outlined,
          onTap: notifier.togglePin,
          color: state.isPinned
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest,
          foregroundColor: state.isPinned
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant,
        ),
        const SizedBox(width: 8),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class _EditorIconButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final Color? color;
  final Color? foregroundColor;

  const _EditorIconButton({
    required this.icon,
    required this.onTap,
    this.color,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Material(
      color: onTap == null
          ? scheme.surfaceContainerLow.withValues(alpha: 0.5)
          : (color ?? scheme.surfaceContainerLow),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          width: 42,
          height: 42,
          child: Icon(
            icon,
            size: 20,
            color: onTap == null
                ? scheme.onSurface.withValues(alpha: 0.26)
                : (foregroundColor ?? scheme.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}
