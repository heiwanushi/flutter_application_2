import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../../core/services/calendar_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/utils/note_colors.dart';
import '../../../data/models/note.dart';

import '../providers/notes_provider.dart';
import '../providers/notes_filters_provider.dart';
import '../providers/note_editor_provider.dart';
import '../providers/contacts_provider.dart';
import '../widgets/editor/editor_gallery.dart';
import '../widgets/editor/editor_app_bar.dart';
import '../widgets/editor/editor_meta_chips.dart';
import '../widgets/editor/ai_assembly_result_dialog.dart';

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note;
  final String? initialImagePath;
  final String? initialText;

  const NoteEditorScreen({super.key, this.note, this.initialImagePath, this.initialText});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _tagCtrl;
  bool _ignoreSync = false;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _contentCtrl = TextEditingController(text: n?.content ?? widget.initialText ?? '');
    _tagCtrl = TextEditingController();

    _titleCtrl.addListener(_onTitleChanged);
    _contentCtrl.addListener(_onContentChanged);

    if (widget.initialImagePath != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(noteEditorProvider(widget.note).notifier).setImages([widget.initialImagePath!]);
      });
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    super.dispose();
  }

  void _onTitleChanged() {
    if (_ignoreSync) return;
    ref.read(noteEditorProvider(widget.note).notifier).updateTitle(_titleCtrl.text);
  }

  void _onContentChanged() {
    if (_ignoreSync) return;
    ref.read(noteEditorProvider(widget.note).notifier).updateContent(_contentCtrl.text);
  }

  void _syncControllers(NoteEditorState state) {
    _ignoreSync = true;
    if (_titleCtrl.text != state.title) {
      _titleCtrl.text = state.title;
    }
    if (_contentCtrl.text != state.content) {
      _contentCtrl.text = state.content;
    }
    _ignoreSync = false;
  }

  Future<void> _save() async {
    final notifier = ref.read(noteEditorProvider(widget.note).notifier);
    final calendarService = ref.read(calendarServiceProvider);
    final savedNote = await notifier.save(ref);

    if (savedNote != null) {
      await _syncCalendar(savedNote, calendarService, ref.read(notesProvider.notifier));
    }
  }

  Future<void> _syncCalendar(Note savedNote, CalendarService calendarService, NotesNotifier notifier) async {
    final state = ref.read(noteEditorProvider(widget.note));
    try {
      if (state.eventAt == null) {
        if (widget.note?.calendarEventId != null) {
          await calendarService.deleteNoteEvent(widget.note!);
        }
        return;
      }

      final syncResult = await calendarService.upsertNoteEvent(savedNote);
      
      // Обновляем состояние редактора, чтобы при следующем сохранении (без закрытия) не создавался дубликат
      ref.read(noteEditorProvider(widget.note).notifier).updateCalendarMeta(
        syncResult.calendarId, 
        syncResult.eventId,
      );

      await notifier.updateCalendarEventMeta(
        savedNote.id,
        calendarId: syncResult.calendarId,
        calendarEventId: syncResult.eventId,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _pickEventDateTime() async {
    final state = ref.read(noteEditorProvider(widget.note));
    final notifier = ref.read(noteEditorProvider(widget.note).notifier);
    final now = DateTime.now();
    final initial = state.eventAt ?? now.add(const Duration(hours: 1));
    
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 3650)),
    );
    if (selectedDate == null || !mounted) return;

    final selectedTime = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(initial),
    );
    if (selectedTime == null) return;

    final newEventAt = DateTime(
      selectedDate.year,
      selectedDate.month,
      selectedDate.day,
      selectedTime.hour,
      selectedTime.minute,
    );
    notifier.setEvent(newEventAt, state.reminderMinutes, state.repeatMode);
  }

  Future<void> _delete() async {
    final scheme = Theme.of(context).colorScheme;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Удалить заметку?'),
        content: const Text('Это действие нельзя отменить.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: scheme.error),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      ref.read(notesProvider.notifier).delete(widget.note!.id);
      Navigator.of(context).pop();
    }
  }

  void _showColorDialog() {
    final notifier = ref.read(noteEditorProvider(widget.note).notifier);
    final state = ref.read(noteEditorProvider(widget.note));
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Цвет заметки'),
        content: SizedBox(
          width: double.maxFinite,
          child: GridView.builder(
            shrinkWrap: true,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 2.5,
            ),
            itemCount: NoteColors.count,
            itemBuilder: (ctx, i) {
              final color = NoteColors.bg(i, Theme.of(context).brightness);
              final isSelected = state.colorIndex == i;
              return InkWell(
                onTap: () {
                  notifier.updateColor(i);
                  Navigator.pop(ctx);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(12),
                    border: isSelected ? Border.all(color: scheme.primary, width: 2) : null,
                  ),
                  alignment: Alignment.center,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    NoteColors.categoryNames[i] ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      color: Theme.of(context).brightness == Brightness.dark ? Colors.white : Colors.black87,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              notifier.updateColor(null);
              Navigator.pop(ctx);
            },
            child: const Text('Сбросить цвет'),
          ),
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  void _showAddTagDialog() {
    final notifier = ref.read(noteEditorProvider(widget.note).notifier);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Добавить тег'),
        content: TextField(
          controller: _tagCtrl,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Название тега'),
          onSubmitted: (val) {
            if (val.trim().isNotEmpty) {
              notifier.addTag(val.trim());
              _tagCtrl.clear();
            }
            Navigator.pop(ctx);
          },
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              if (_tagCtrl.text.trim().isNotEmpty) {
                notifier.addTag(_tagCtrl.text.trim());
                _tagCtrl.clear();
              }
              Navigator.pop(ctx);
            },
            child: const Text('Добавить'),
          ),
        ],
      ),
    );
  }

  Future<void> _addContact() async {
    final notifier = ref.read(noteEditorProvider(widget.note).notifier);
    final status = await Permission.contacts.request();
    if (status.isGranted) {
      if (!mounted) return;
      final contactId = await fc.FlutterContacts.native.showPicker();
      if (contactId != null) {
        final fullContact = await fc.FlutterContacts.get(
          contactId,
          properties: {fc.ContactProperty.name, fc.ContactProperty.phone},
        );
        if (fullContact != null) {
          final noteContact = NoteContact(
            name: fullContact.displayName ?? 'Без имени',
            phoneNumber: fullContact.phones.isNotEmpty ? fullContact.phones.first.number : '',
          );
          notifier.addContact(noteContact);
        }
      }
    }
  }

  Future<void> _aiProcessText(Future<String?> Function() action) async {
    final notifier = ref.read(noteEditorProvider(widget.note).notifier);
    if (_contentCtrl.text.trim().isEmpty) return;

    notifier.setAIProcessing(true);
    try {
      final result = await action();
      if (!mounted) return;

      if (result != null) {
        notifier.updateContent(result);
        _syncControllers(ref.read(noteEditorProvider(widget.note)));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Готово ✨')));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка AI: $e')));
    } finally {
      notifier.setAIProcessing(false);
    }
  }

  void _showOriginalDialog() {
    final state = ref.read(noteEditorProvider(widget.note));
    if (state.originalContent == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оригинал заметки'),
        content: SingleChildScrollView(child: Text(state.originalContent!)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
          FilledButton.tonal(
            onPressed: () {
              ref.read(noteEditorProvider(widget.note).notifier).updateContent(state.originalContent!);
              _syncControllers(ref.read(noteEditorProvider(widget.note)));
              Navigator.pop(ctx);
            },
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final state = ref.read(noteEditorProvider(widget.note));
    final notifier = ref.read(noteEditorProvider(widget.note).notifier);
    final picker = ImagePicker();
    final dir = await getApplicationDocumentsDirectory();
    final picked = await picker.pickMultiImage(imageQuality: 80, maxWidth: 2048, maxHeight: 2048);
    if (picked.isEmpty) return;

    final newPaths = List<String>.from(state.imagePaths);
    for (final image in picked) {
      final fileName = '${DateTime.now().microsecondsSinceEpoch}_${newPaths.length}${p.extension(image.path)}';
      final dest = File(p.join(dir.path, fileName));
      await File(image.path).copy(dest.path);
      // Удаляем оригинал после копирования
      try {
        await File(image.path).delete();
      } catch (_) {}
      newPaths.add(dest.path);
    }
    notifier.setImages(newPaths);
  }

  Future<void> _structurizeWithAI() async {
    final rawText = _contentCtrl.text;
    if (rawText.trim().isEmpty) return;
    final notifier = ref.read(noteEditorProvider(widget.note).notifier);

    notifier.setAIProcessing(true);
    try {
      final gemini = ref.read(geminiServiceProvider);
      final userContacts = await ref.read(allSystemContactsProvider.future).catchError((_) => <NoteContact>[]);
      final existingFolders = ref.read(allTagsProvider);
      final result = await gemini.structureNote(
        rawText,
        userContacts: userContacts,
        existingFolders: existingFolders,
      );

      if (!mounted) return;
      notifier.setAIProcessing(false);

      if (result != null) {
        notifier.applyStructuredData(
          rawText,
          result.title,
          result.content,
          result.tags,
          result.contacts,
          result.colorIndex,
          result.eventAt,
          result.reminderMinutes ?? 10,
        );
        _syncControllers(ref.read(noteEditorProvider(widget.note)));
        
        if (mounted) {
          showDialog(
            context: context,
            builder: (ctx) => AIAssemblyResultDialog(
              contacts: result.contacts,
              eventAt: result.eventAt,
              tags: result.tags,
            ),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      notifier.setAIProcessing(false);
      showDialog(
        context: context,
        builder: (ctx) => AIAssemblyResultDialog(error: e.toString()),
      );
    }
  }

  void _showAiToolsDialog() {
    final state = ref.read(noteEditorProvider(widget.note));
    final gemini = ref.read(geminiServiceProvider);
    final scheme = Theme.of(context).colorScheme;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: scheme.primary),
            const SizedBox(width: 12),
            const Text('AI Инструменты'),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _AiToolTile(
              icon: Icons.auto_awesome_rounded,
              title: 'Сборка ИИ',
              subtitle: 'Умный анализ, теги и цвет',
              onTap: () {
                Navigator.pop(ctx);
                _structurizeWithAI();
              },
            ),
            _AiToolTile(
              icon: Icons.auto_fix_high_rounded,
              title: 'Улучшить стиль',
              subtitle: 'Сделать текст профессиональнее',
              onTap: () {
                Navigator.pop(ctx);
                _aiProcessText(() => gemini.improveText(_contentCtrl.text));
              },
            ),
            _AiToolTile(
              icon: Icons.spellcheck_rounded,
              title: 'Грамматика',
              subtitle: 'Исправить ошибки и пунктуацию',
              onTap: () {
                Navigator.pop(ctx);
                _aiProcessText(() => gemini.checkGrammar(_contentCtrl.text));
              },
            ),
            _AiToolTile(
              icon: Icons.summarize_rounded,
              title: 'Выжимка',
              subtitle: 'Сократить до самого главного',
              onTap: () {
                Navigator.pop(ctx);
                _aiProcessText(() => gemini.summarize(_contentCtrl.text));
              },
            ),
            if (state.originalContent != null)
              _AiToolTile(
                icon: Icons.history_rounded,
                title: 'Оригинал',
                subtitle: 'Вернуться к первой версии',
                onTap: () {
                  Navigator.pop(ctx);
                  _showOriginalDialog();
                },
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Закрыть')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(noteEditorProvider(widget.note));
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tt = theme.textTheme;
    final noteBackground = state.colorIndex != null ? NoteColors.bg(state.colorIndex!, theme.brightness) : scheme.surface;
    final pageColor = Color.alphaBlend(scheme.surface.withValues(alpha: 0.24), noteBackground);

    return PopScope(
      canPop: state.canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _save();
        if (context.mounted) {
          ref.read(noteEditorProvider(widget.note).notifier).setCanPop(true);
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: pageColor,
        appBar: EditorAppBar(
          note: widget.note,
          onBack: () async {
            await _save();
            if (context.mounted) Navigator.of(context).pop();
          },
          onShowColorPicker: _showColorDialog,
          onDelete: _delete,
          onShowAI: _showAiToolsDialog,
          onTogglePreview: () => ref.read(noteEditorProvider(widget.note).notifier).togglePreview(),
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.tags.contains('AI')) _AILabel(scheme: scheme, tt: tt),
                  EditorGallery(
                    imagePaths: state.imagePaths,
                    onPickImage: _pickImage,
                    onRemoveImage: (idx) {
                      final newPaths = List<String>.from(state.imagePaths)..removeAt(idx);
                      ref.read(noteEditorProvider(widget.note).notifier).setImages(newPaths);
                    },
                    scheme: scheme,
                    tt: tt,
                  ),
                  TextField(
                    controller: _titleCtrl,
                    style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w800, height: 1.12),
                    maxLines: null,
                    decoration: InputDecoration(
                      hintText: 'Название',
                      hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                      border: InputBorder.none,
                    ),
                  ),
                  EditorMetaChips(
                    eventAt: state.eventAt,
                    isCompleted: state.isCompleted,
                    tags: state.tags,
                    contacts: state.contacts,
                    scheme: scheme,
                    onAddContact: _addContact,
                    onAddTag: _showAddTagDialog,
                    onPickEvent: _pickEventDateTime,
                    onToggleCompleted: () => ref.read(noteEditorProvider(widget.note).notifier).toggleCompleted(),
                  ),
                  const SizedBox(height: 8),
                  if (state.isPreviewMode)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: MarkdownBody(
                        data: _contentCtrl.text,
                        styleSheet: MarkdownStyleSheet.fromTheme(theme).copyWith(
                          p: tt.bodyLarge?.copyWith(height: 1.6),
                          listBullet: tt.bodyLarge?.copyWith(height: 1.6),
                          h1: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                          h2: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                          h3: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                    )
                  else
                    TextField(
                      controller: _contentCtrl,
                      maxLines: null,
                      style: tt.bodyLarge?.copyWith(height: 1.6),
                      decoration: InputDecoration(
                        hintText: 'Начните писать заметку...',
                        hintStyle: TextStyle(color: scheme.onSurfaceVariant.withValues(alpha: 0.7)),
                        border: InputBorder.none,
                      ),
                    ),
                ],
              ),
            ),
            if (state.isAIProcessing)
              Container(
                color: Colors.black.withValues(alpha: 0.3),
                child: const Center(child: CircularProgressIndicator()),
              ),
          ],
        ),
      ),
    );
  }
}

class _AILabel extends StatelessWidget {
  final ColorScheme scheme;
  final TextTheme tt;
  const _AILabel({required this.scheme, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                const SizedBox(width: 10),
                Text('ОБРАБОТАНО ИИ', style: TextStyle(color: scheme.primary, fontWeight: FontWeight.w800, letterSpacing: 0.8, fontSize: 13)),
              ],
            ),
            const SizedBox(height: 10),
            Text('ИИ может совершать ошибки. Проверяйте важную информацию.', style: tt.bodySmall?.copyWith(color: scheme.onPrimaryContainer.withValues(alpha: 0.8), fontSize: 11, height: 1.3)),
          ],
        ),
      ),
    );
  }
}

class _AiToolTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AiToolTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      leading: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.primaryContainer.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.primary, size: 24),
      ),
      title: Text(title, style: tt.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle, style: tt.bodySmall),
      onTap: onTap,
    );
  }
}


