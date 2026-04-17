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
import '../providers/note_editor_provider.dart';
import '../providers/contacts_provider.dart';
import '../widgets/editor/editor_event_section.dart';
import '../widgets/editor/editor_gallery.dart';
import '../widgets/editor/editor_toolbar.dart';
import '../widgets/editor/editor_app_bar.dart';
import '../widgets/editor/editor_ai_menu.dart';
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

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return _EditorSettingsDialog(note: widget.note, tagCtrl: _tagCtrl, onPickEvent: _pickEventDateTime);
      },
    );
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
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    final newPaths = List<String>.from(state.imagePaths);
    for (final image in picked) {
      final fileName = '${DateTime.now().microsecondsSinceEpoch}_${newPaths.length}${p.extension(image.path)}';
      final dest = File(p.join(dir.path, fileName));
      await File(image.path).copy(dest.path);
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
      final result = await gemini.structureNote(rawText, userContacts: userContacts);

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
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) Navigator.of(context).pop();
          });
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
          onShowSettings: _showSettingsDialog,
          onDelete: _delete,
        ),
        floatingActionButton: EditorAiMenu(
          note: widget.note,
          contentCtrl: _contentCtrl,
          onStructurize: _structurizeWithAI,
          onProcessText: _aiProcessText,
          onShowOriginal: _showOriginalDialog,
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (state.originalContent != null) _AILabel(scheme: scheme, tt: tt),
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

class _EditorSettingsDialog extends ConsumerWidget {
  final Note? note;
  final TextEditingController tagCtrl;
  final VoidCallback onPickEvent;

  const _EditorSettingsDialog({required this.note, required this.tagCtrl, required this.onPickEvent});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(noteEditorProvider(note));
    final notifier = ref.read(noteEditorProvider(note).notifier);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Dialog(
      backgroundColor: scheme.surface,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      insetPadding: const EdgeInsets.all(16),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Параметры заметки', style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
            const SizedBox(height: 24),
            EditorToolbar(
              tags: state.tags,
              tagCtrl: tagCtrl,
              colorIndex: state.colorIndex,
              onAddTag: notifier.addTag,
              onRemoveTag: notifier.removeTag,
              onColorChanged: notifier.updateColor,
              contacts: state.contacts,
              onAddContact: () async {
                final status = await Permission.contacts.request();
                if (status.isGranted) {
                  if (!context.mounted) return;
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
              },
              onRemoveContact: notifier.removeContact,
              scheme: scheme,
              tt: tt,
            ),
            const SizedBox(height: 16),
            EditorEventSection(
              eventAt: state.eventAt,
              reminderMinutes: state.reminderMinutes,
              repeatMode: state.repeatMode,
              isCompleted: state.isCompleted,
              onPickDateTime: onPickEvent,
              onClear: state.eventAt == null ? null : () => notifier.setEvent(null, 10, NoteRepeatMode.none),
              onReminderChanged: (val) => notifier.setEvent(state.eventAt, val, state.repeatMode),
              onRepeatChanged: (val) => notifier.setEvent(state.eventAt, state.reminderMinutes, val),
            ),
            const SizedBox(height: 16),
            Align(alignment: Alignment.centerRight, child: FilledButton.tonal(onPressed: () => Navigator.of(context).pop(), child: const Text('Готово'))),
          ],
        ),
      ),
    );
  }
}
