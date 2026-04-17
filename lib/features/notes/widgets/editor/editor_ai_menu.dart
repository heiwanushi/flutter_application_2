import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/note_editor_provider.dart';
import '../../../../core/services/gemini_service.dart';
import '../../../../data/models/note.dart';

class EditorAiMenu extends ConsumerWidget {
  final Note? note;
  final TextEditingController contentCtrl;
  final VoidCallback onStructurize;
  final Function(Future<String?> Function()) onProcessText;
  final VoidCallback onShowOriginal;

  const EditorAiMenu({
    super.key,
    required this.note,
    required this.contentCtrl,
    required this.onStructurize,
    required this.onProcessText,
    required this.onShowOriginal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noteEditorProvider(note));
    final notifier = ref.read(noteEditorProvider(note).notifier);
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tt = theme.textTheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.extended(
          heroTag: 'mode_toggle',
          onPressed: notifier.togglePreview,
          backgroundColor: scheme.secondaryContainer,
          foregroundColor: scheme.onSecondaryContainer,
          icon: Icon(state.isPreviewMode ? Icons.edit_rounded : Icons.visibility_rounded),
          label: Text(state.isPreviewMode ? 'Редактировать' : 'Просмотр'),
        ),
        const SizedBox(height: 12),
        MenuAnchor(
          style: MenuStyle(
            shape: WidgetStatePropertyAll(
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            ),
            elevation: const WidgetStatePropertyAll(6),
            backgroundColor: WidgetStatePropertyAll(scheme.surfaceContainerLow),
          ),
          builder: (context, controller, child) {
            return FloatingActionButton.extended(
              heroTag: 'ai_tools',
              onPressed: state.isAIProcessing ? null : () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: state.isAIProcessing
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Icon(Icons.auto_awesome_rounded),
              label: Text(state.isAIProcessing ? 'Анализ...' : 'AI Инструменты ✨'),
              backgroundColor: scheme.tertiaryContainer,
              foregroundColor: scheme.onTertiaryContainer,
            );
          },
          menuChildren: [
            _buildMenuItem(
              icon: Icons.auto_awesome_rounded,
              title: 'Сборка ИИ',
              subtitle: 'Анализ текста, подбор тегов и цвета',
              onPressed: onStructurize,
              scheme: scheme,
              tt: tt,
            ),
            _buildMenuItem(
              icon: Icons.auto_fix_high_rounded,
              title: 'Улучшить текст',
              subtitle: 'Профессиональная правка стиля и ясности',
              onPressed: () => onProcessText(() => ref.read(geminiServiceProvider).improveText(contentCtrl.text)),
              scheme: scheme,
              tt: tt,
            ),
            _buildMenuItem(
              icon: Icons.spellcheck_rounded,
              title: 'Грамматика',
              subtitle: 'Исправление ошибок и знаков препинания',
              onPressed: () => onProcessText(() => ref.read(geminiServiceProvider).checkGrammar(contentCtrl.text)),
              scheme: scheme,
              tt: tt,
            ),
            _buildMenuItem(
              icon: Icons.summarize_rounded,
              title: 'Сжать до главного',
              subtitle: 'Создание краткой выжимки сути из всего текста',
              onPressed: () => onProcessText(() => ref.read(geminiServiceProvider).summarize(contentCtrl.text)),
              scheme: scheme,
              tt: tt,
            ),
            if (state.originalContent != null)
              _buildMenuItem(
                icon: Icons.history_rounded,
                title: 'Оригинал',
                subtitle: 'Просмотр или восстановление первой версии',
                onPressed: onShowOriginal,
                scheme: scheme,
                tt: tt,
              ),
          ],
        ),
      ],
    );
  }

  Widget _buildMenuItem({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onPressed,
    required ColorScheme scheme,
    required TextTheme tt,
  }) {
    return MenuItemButton(
      leadingIcon: Icon(icon, color: scheme.primary, size: 28),
      onPressed: onPressed,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 10),
        child: SizedBox(
          width: 260,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                title,
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: tt.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontSize: 14,
                  height: 1.3,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
