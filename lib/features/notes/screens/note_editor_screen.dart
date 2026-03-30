import 'dart:async';
import 'dart:io';


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/calendar_service.dart';
import '../../../core/services/gemini_service.dart';
import '../../../core/utils/note_colors.dart';
import '../../../data/models/note.dart';

import '../providers/notes_provider.dart';
import '../widgets/editor/editor_event_section.dart';
import '../widgets/editor/editor_gallery.dart';
import '../widgets/editor/editor_toolbar.dart';

class _NoteState {
  final String title;
  final String content;
  final int? colorIndex;
  final List<String> tags;
  final List<String> imagePaths;
  final DateTime? eventAt;
  final int reminderMinutes;
  final NoteRepeatMode repeatMode;

  _NoteState(
    this.title,
    this.content,
    this.colorIndex,
    this.tags,
    this.imagePaths,
    this.eventAt,
    this.reminderMinutes,
    this.repeatMode,
  );
}

class NoteEditorScreen extends ConsumerStatefulWidget {
  final Note? note;

  const NoteEditorScreen({super.key, this.note});

  @override
  ConsumerState<NoteEditorScreen> createState() => _NoteEditorScreenState();
}

class _NoteEditorScreenState extends ConsumerState<NoteEditorScreen> {
  late TextEditingController _titleCtrl;
  late TextEditingController _contentCtrl;
  late TextEditingController _tagCtrl;
  late List<String> _tags;
  late List<String> _imagePaths;
  late int? _colorIndex;
  late bool _isPinned;
  DateTime? _eventAt;
  int _reminderMinutes = 10;
  NoteRepeatMode _repeatMode = NoteRepeatMode.none;
  String? _originalContent;
  bool _isAIProcessing = false;
  bool _isPreviewMode = false;
  bool _canPop = false;
  bool _isSaving = false;

  List<_NoteState> _history = [];
  int _historyIndex = -1;
  bool _ignoreHistory = false;
  Timer? _historyTimer;

  @override
  void initState() {
    super.initState();
    final n = widget.note;
    _titleCtrl = TextEditingController(text: n?.title ?? '');
    _contentCtrl = TextEditingController(text: n?.content ?? '');
    _tagCtrl = TextEditingController();
    _tags = List.from(n?.tags ?? []);
    _imagePaths = List.from(n?.imagePaths ?? []);
    _colorIndex = n?.colorIndex;
    _isPinned = n?.isPinned ?? false;
    _eventAt = n?.eventAt;
    _reminderMinutes = n?.reminderMinutes ?? 10;
    _repeatMode = n?.repeatMode ?? NoteRepeatMode.none;
    _originalContent = n?.originalContent;
    
    _isPreviewMode = n != null;

    _recordHistory(immediate: true);
    _titleCtrl.addListener(_onTextChanged);
    _contentCtrl.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _contentCtrl.dispose();
    _tagCtrl.dispose();
    _historyTimer?.cancel();
    super.dispose();
  }

  bool _hasChanges() {
    final n = widget.note;
    if (n == null) {
      return _titleCtrl.text.trim().isNotEmpty ||
          _contentCtrl.text.trim().isNotEmpty ||
          _imagePaths.isNotEmpty ||
          _tags.isNotEmpty ||
          _eventAt != null;
    }

    return !(_titleCtrl.text.trim() == n.title &&
        _contentCtrl.text.trim() == n.content &&
        _colorIndex == n.colorIndex &&
        _isPinned == n.isPinned &&
        _eventAt == n.eventAt &&
        _reminderMinutes == (n.reminderMinutes ?? 10) &&
        _repeatMode == n.repeatMode &&
        _originalContent == n.originalContent &&
        listEquals(_tags, n.tags) &&
        listEquals(_imagePaths, n.imagePaths));
  }

  void _onTextChanged() {
    if (_ignoreHistory) return;
    _historyTimer?.cancel();
    _historyTimer = Timer(
      const Duration(milliseconds: 500),
      () => _recordHistory(),
    );
  }

  void _recordHistory({bool immediate = false}) {
    final newState = _NoteState(
      _titleCtrl.text,
      _contentCtrl.text,
      _colorIndex,
      List.from(_tags),
      List.from(_imagePaths),
      _eventAt,
      _reminderMinutes,
      _repeatMode,
    );

    if (_history.isNotEmpty &&
        _history[_historyIndex].title == newState.title &&
        _history[_historyIndex].content == newState.content &&
        _history[_historyIndex].colorIndex == newState.colorIndex &&
        _history[_historyIndex].eventAt == newState.eventAt &&
        _history[_historyIndex].reminderMinutes == newState.reminderMinutes &&
        _history[_historyIndex].repeatMode == newState.repeatMode &&
        listEquals(_history[_historyIndex].tags, newState.tags)) {
      return;
    }

    if (_historyIndex < _history.length - 1) {
      _history = _history.sublist(0, _historyIndex + 1);
    }

    _history.add(newState);
    if (_history.length > 50) _history.removeAt(0);
    _historyIndex = _history.length - 1;
    if (mounted) setState(() {});
  }

  void _undo() {
    if (_historyIndex > 0) {
      setState(() {
        _historyIndex--;
        _restoreState(_history[_historyIndex]);
      });
    }
  }

  void _redo() {
    if (_historyIndex < _history.length - 1) {
      setState(() {
        _historyIndex++;
        _restoreState(_history[_historyIndex]);
      });
    }
  }

  void _restoreState(_NoteState s) {
    _ignoreHistory = true;
    _titleCtrl.text = s.title;
    _contentCtrl.text = s.content;
    _colorIndex = s.colorIndex;
    _tags = List.from(s.tags);
    _imagePaths = List.from(s.imagePaths);
    _eventAt = s.eventAt;
    _reminderMinutes = s.reminderMinutes;
    _repeatMode = s.repeatMode;
    _ignoreHistory = false;
  }

  Future<void> _save() async {
    if (_isSaving || !_hasChanges()) return;
    _isSaving = true;

    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final notifier = ref.read(notesProvider.notifier);
    final calendarService = ref.read(calendarServiceProvider);
    Note? savedNote;

    try {
      if (widget.note == null) {
        savedNote = await notifier.add(
          title: title,
          content: content,
          tags: _tags,
          imagePaths: _imagePaths,
          colorIndex: _colorIndex,
          isPinned: _isPinned,
          eventAt: _eventAt,
          reminderMinutes: _eventAt == null ? null : _reminderMinutes,
          repeatMode: _repeatMode,
          originalContent: _originalContent,
        );
      } else {
        final oldNote = widget.note!;
        final imageChanged = !listEquals(_imagePaths, oldNote.imagePaths);
        final contentChanged =
            title != oldNote.title ||
            content != oldNote.content ||
            !listEquals(_tags, oldNote.tags) ||
            _eventAt != oldNote.eventAt ||
            _reminderMinutes != (oldNote.reminderMinutes ?? 10) ||
            _repeatMode != oldNote.repeatMode ||
            _originalContent != oldNote.originalContent;

        if (imageChanged || contentChanged) {
          savedNote = await notifier.editNote(
            oldNote.id,
            title: title,
            content: content,
            tags: _tags,
            imagePaths: _imagePaths,
            eventAt: _eventAt,
            reminderMinutes: _eventAt == null ? null : _reminderMinutes,
            calendarEventId: oldNote.calendarEventId,
            calendarId: oldNote.calendarId,
            repeatMode: _repeatMode,
            clearEvent: _eventAt == null,
            originalContent: _originalContent,
          );
        } else {
          savedNote = oldNote;
        }

        if (_colorIndex != oldNote.colorIndex) {
          await notifier.setColor(oldNote.id, _colorIndex);
        }
        if (_isPinned != oldNote.isPinned) {
          await notifier.togglePin(oldNote.id);
        }
      }

      if (savedNote != null) {
        await _syncCalendar(savedNote, calendarService, notifier);
      }
    } finally {
      if (mounted) _isSaving = false;
    }
  }

  Future<void> _syncCalendar(Note savedNote, CalendarService calendarService, NotesNotifier notifier) async {
    final oldNote = widget.note;

    try {
      if (_eventAt == null) {
        if (oldNote?.calendarEventId != null) {
          await calendarService.deleteNoteEvent(oldNote!);
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
    final now = DateTime.now();
    final initial = _eventAt ?? now.add(const Duration(hours: 1));
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

    setState(() {
      _eventAt = DateTime(
        selectedDate.year,
        selectedDate.month,
        selectedDate.day,
        selectedTime.hour,
        selectedTime.minute,
      );
    });
    _recordHistory(immediate: true);
  }

  void _clearEventDateTime() {
    setState(() {
      _eventAt = null;
      _repeatMode = NoteRepeatMode.none;
    });
    _recordHistory(immediate: true);
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
      _ignoreHistory = true;
      _isSaving = true;
      ref.read(notesProvider.notifier).delete(widget.note!.id);
      setState(() => _canPop = true);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop();
      });
    }
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final scheme = Theme.of(context).colorScheme;
        final tt = Theme.of(context).textTheme;

        return StatefulBuilder(
          builder: (context, setDialogState) {
            return Dialog(
              backgroundColor: scheme.surface,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
              insetPadding: const EdgeInsets.all(16),
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Параметры заметки',
                      style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 24),
                    EditorToolbar(
                      tags: _tags,
                      tagCtrl: _tagCtrl,
                      colorIndex: _colorIndex,
                      onAddTag: (val) {
                        _addTag(val);
                        _recordHistory(immediate: true);
                        setDialogState(() {});
                        if (mounted) setState(() {});
                      },
                      onRemoveTag: (t) {
                        _tags.remove(t);
                        _recordHistory(immediate: true);
                        setDialogState(() {});
                        if (mounted) setState(() {});
                      },
                      onColorChanged: (idx) {
                        _colorIndex = idx;
                        _recordHistory(immediate: true);
                        setDialogState(() {});
                        if (mounted) setState(() {});
                      },
                      scheme: scheme,
                      tt: tt,
                    ),
                    const SizedBox(height: 16),
                    EditorEventSection(
                      eventAt: _eventAt,
                      reminderMinutes: _reminderMinutes,
                      repeatMode: _repeatMode,
                      onPickDateTime: () async {
                        await _pickEventDateTime();
                        setDialogState(() {});
                        if (mounted) setState(() {});
                      },
                      onClear: _eventAt == null
                          ? null
                          : () {
                              _clearEventDateTime();
                              setDialogState(() {});
                              if (mounted) setState(() {});
                            },
                      onReminderChanged: (value) {
                        _reminderMinutes = value;
                        _recordHistory(immediate: true);
                        setDialogState(() {});
                        if (mounted) setState(() {});
                      },
                      onRepeatChanged: (value) {
                        _repeatMode = value;
                        _recordHistory(immediate: true);
                        setDialogState(() {});
                        if (mounted) setState(() {});
                      },
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerRight,
                      child: FilledButton.tonal(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Готово'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _aiProcessText(Future<String?> Function() action) async {
    if (_contentCtrl.text.trim().isEmpty) return;

    setState(() => _isAIProcessing = true);

    try {
      final result = await action();
      if (!mounted) return;

      if (result != null) {
        if (_originalContent == null) {
          _originalContent = _contentCtrl.text;
        }

        _ignoreHistory = true;
        _contentCtrl.text = result;
        _ignoreHistory = false;
        _recordHistory(immediate: true);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Готово ✨')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка AI: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isAIProcessing = false);
      }
    }
  }

  void _showOriginalDialog() {
    if (_originalContent == null) return;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оригинал заметки'),
        content: SingleChildScrollView(
          child: Text(_originalContent!),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Закрыть'),
          ),
          FilledButton.tonal(
            onPressed: () {
              setState(() {
                _ignoreHistory = true;
                _contentCtrl.text = _originalContent!;
                _ignoreHistory = false;
                _recordHistory(immediate: true);
              });
              Navigator.pop(ctx);
            },
            child: const Text('Восстановить'),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final dir = await getApplicationDocumentsDirectory();
    final picked = await picker.pickMultiImage(imageQuality: 80);
    if (picked.isEmpty) return;

    final newPaths = <String>[];
    for (final image in picked) {
      final fileName =
          '${DateTime.now().microsecondsSinceEpoch}_${newPaths.length}${p.extension(image.path)}';
      final dest = File(p.join(dir.path, fileName));
      await File(image.path).copy(dest.path);
      newPaths.add(dest.path);
    }

    setState(() => _imagePaths.addAll(newPaths));
    _recordHistory(immediate: true);
  }

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
      _tagCtrl.clear();
    }
  }

  Future<void> _structurizeWithAI() async {
    final rawText = _contentCtrl.text;
    if (rawText.trim().isEmpty) return;

    setState(() => _isAIProcessing = true);

    try {
      final gemini = ref.read(geminiServiceProvider);
      final result = await gemini.structureNote(rawText);

      if (!mounted) return;
      setState(() => _isAIProcessing = false);

      if (result != null) {
        if (_originalContent == null) {
          _originalContent = rawText;
        }

        _ignoreHistory = true;
        _titleCtrl.text = result.title;
        _contentCtrl.text = result.content;
        _tags = result.tags;
        if (result.colorIndex != null) _colorIndex = result.colorIndex;
        if (result.eventAt != null) _eventAt = result.eventAt;
        if (result.reminderMinutes != null) {
          const allowed = [5, 10, 15, 30, 60, 120, 180, 1440];
          int closest = allowed[0];
          int minDiff = 999999;
          for (var option in allowed) {
            int diff = (option - result.reminderMinutes!).abs();
            if (diff < minDiff) {
              minDiff = diff;
              closest = option;
            }
          }
          _reminderMinutes = closest;
        }
        _ignoreHistory = false;
        _recordHistory(immediate: true);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Успешно структурировано с ИИ ✨')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _isAIProcessing = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.toString()),
          duration: const Duration(seconds: 5),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final tt = theme.textTheme;
    final bool isAIEdited = _originalContent != null;

    final noteBackground = _colorIndex != null
        ? NoteColors.bg(_colorIndex!, theme.brightness)
        : scheme.surface;
    final pageColor = Color.alphaBlend(
      scheme.surface.withValues(alpha: 0.24),
      noteBackground,
    );

    return PopScope(
      canPop: _canPop,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _save();
        if (mounted) {
          setState(() => _canPop = true);
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) Navigator.of(context).pop();
          });
        }
      },
      child: Scaffold(
        backgroundColor: pageColor,
        appBar: AppBar(
          backgroundColor: pageColor,
          leadingWidth: 56,
          titleSpacing: 0,
          leading: Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _EditorIconButton(
              icon: Icons.arrow_back_rounded,
              onTap: () async {
                await _save();
                if (mounted) {
                  setState(() => _canPop = true);
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    if (mounted) Navigator.of(context).pop();
                  });
                }
              },
            ),
          ),
          title: widget.note == null
              ? Text(
                  'Новая заметка',
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                )
              : null,
          actions: [
            _EditorIconButton(
              icon: Icons.undo_rounded,
              onTap: _historyIndex > 0 ? _undo : null,
            ),
            const SizedBox(width: 8),
            _EditorIconButton(
              icon: Icons.redo_rounded,
              onTap: _historyIndex < _history.length - 1 ? _redo : null,
            ),
            const SizedBox(width: 8),
            _EditorIconButton(
              icon: Icons.tune_rounded,
              onTap: _showSettingsDialog,
            ),
            const SizedBox(width: 8),
            if (widget.note != null)
              _EditorIconButton(
                icon: Icons.delete_outline_rounded,
                onTap: _delete,
                color: scheme.errorContainer,
                foregroundColor: scheme.onErrorContainer,
              ),
            if (widget.note != null) const SizedBox(width: 8),
            _EditorIconButton(
              icon: _isPinned
                  ? Icons.push_pin_rounded
                  : Icons.push_pin_outlined,
              onTap: () {
                setState(() => _isPinned = !_isPinned);
                _recordHistory(immediate: true);
              },
              color: _isPinned
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              foregroundColor: _isPinned
                  ? scheme.onPrimaryContainer
                  : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 12),
          ],
        ),
        floatingActionButton: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            FloatingActionButton.extended(
              heroTag: 'mode_toggle',
              onPressed: () => setState(() => _isPreviewMode = !_isPreviewMode),
              backgroundColor: scheme.secondaryContainer,
              foregroundColor: scheme.onSecondaryContainer,
              icon: Icon(_isPreviewMode ? Icons.edit_rounded : Icons.visibility_rounded),
              label: Text(_isPreviewMode ? 'Редактировать' : 'Просмотр'),
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
                  onPressed: _isAIProcessing ? null : () {
                    if (controller.isOpen) {
                      controller.close();
                    } else {
                      controller.open();
                    }
                  },
                  icon: _isAIProcessing
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.auto_awesome_rounded),
                  label: Text(_isAIProcessing ? 'Анализ...' : 'AI Инструменты ✨'),
                  backgroundColor: scheme.tertiaryContainer,
                  foregroundColor: scheme.onTertiaryContainer,
                );
              },
              menuChildren: [
                _buildMenuItem(
                  icon: Icons.auto_awesome_rounded,
                  title: 'Сборка ИИ',
                  subtitle: 'Анализ текста, подбор тегов и цвета',
                  onPressed: _structurizeWithAI,
                  scheme: scheme,
                  tt: tt,
                ),
                _buildMenuItem(
                  icon: Icons.auto_fix_high_rounded,
                  title: 'Улучшить текст',
                  subtitle: 'Профессиональная правка стиля и ясности',
                  onPressed: () => _aiProcessText(() => ref.read(geminiServiceProvider).improveText(_contentCtrl.text)),
                  scheme: scheme,
                  tt: tt,
                ),
                _buildMenuItem(
                  icon: Icons.spellcheck_rounded,
                  title: 'Грамматика',
                  subtitle: 'Исправление ошибок и знаков препинания',
                  onPressed: () => _aiProcessText(() => ref.read(geminiServiceProvider).checkGrammar(_contentCtrl.text)),
                  scheme: scheme,
                  tt: tt,
                ),
                _buildMenuItem(
                  icon: Icons.summarize_rounded,
                  title: 'Сжать до главного',
                  subtitle: 'Создание краткой выжимки сути из всего текста',
                  onPressed: () => _aiProcessText(() => ref.read(geminiServiceProvider).summarize(_contentCtrl.text)),
                  scheme: scheme,
                  tt: tt,
                ),
                if (_originalContent != null)
                  _buildMenuItem(
                    icon: Icons.history_rounded,
                    title: 'Оригинал',
                    subtitle: 'Просмотр или восстановление первой версии',
                    onPressed: _showOriginalDialog,
                    scheme: scheme,
                    tt: tt,
                  ),
              ],
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 120),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isAIEdited)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: scheme.primaryContainer.withValues(alpha: 0.5), // Единое мягкое облачко
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                              const SizedBox(width: 10),
                              Text(
                                'ОБРАБОТАНО ИИ',
                                style: TextStyle(
                                  color: scheme.primary,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 0.8,
                                  fontSize: 13,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'ИИ может совершать ошибки. Проверяйте важную информацию.',
                            style: tt.bodySmall?.copyWith(
                              color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
                              fontSize: 11,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                EditorGallery(
                  imagePaths: _imagePaths,
                  onPickImage: _pickImage,
                  onRemoveImage: (index) {
                    setState(() => _imagePaths.removeAt(index));
                    _recordHistory(immediate: true);
                  },
                  scheme: scheme,
                  tt: tt,
                ),
                TextField(
                  controller: _titleCtrl,
                  style: tt.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                    height: 1.12,
                  ),
                  maxLines: null,
                  decoration: InputDecoration(
                    hintText: 'Название',
                    hintStyle: TextStyle(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                    ),
                    border: InputBorder.none,
                  ),
                ),
                if (_tags.isNotEmpty || _eventAt != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 8, bottom: 4),
                    child: Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        if (_eventAt != null)
                          Chip(
                            avatar: Icon(Icons.event, size: 16, color: scheme.primary),
                            label: Text(DateFormat('dd.MM.yy HH:mm').format(_eventAt!)),
                            backgroundColor: scheme.primaryContainer,
                            labelStyle: TextStyle(color: scheme.onPrimaryContainer, fontSize: 12, fontWeight: FontWeight.bold),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            side: BorderSide.none,
                          ),
                        ..._tags.map((t) => Chip(
                              label: Text('#$t'),
                              backgroundColor: scheme.surfaceContainerHighest,
                              labelStyle: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                              side: BorderSide.none,
                            )),
                      ],
                    ),
                  ),
                const SizedBox(height: 8),
                if (_isPreviewMode)
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
                      hintStyle: TextStyle(
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.7),
                      ),
                      border: InputBorder.none,
                    ),
                  ),
              ],
            ),
        ),
        if (_isAIProcessing)
          Container(
            color: Colors.black.withValues(alpha: 0.3),
            child: const Center(
              child: CircularProgressIndicator(),
            ),
          ),
          ],
        ), // Stack
      ), // Scaffold
    ); // PopScope
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
