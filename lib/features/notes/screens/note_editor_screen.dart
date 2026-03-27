import 'dart:async';
import 'dart:io';


import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../core/services/calendar_service.dart';
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

  _NoteState(
    this.title,
    this.content,
    this.colorIndex,
    this.tags,
    this.imagePaths,
    this.eventAt,
    this.reminderMinutes,
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
    );

    if (_history.isNotEmpty &&
        _history[_historyIndex].title == newState.title &&
        _history[_historyIndex].content == newState.content &&
        _history[_historyIndex].colorIndex == newState.colorIndex &&
        _history[_historyIndex].eventAt == newState.eventAt &&
        _history[_historyIndex].reminderMinutes == newState.reminderMinutes &&
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
    _ignoreHistory = false;
  }

  Future<void> _save() async {
    if (!_hasChanges()) return;

    final title = _titleCtrl.text.trim();
    final content = _contentCtrl.text.trim();
    final notifier = ref.read(notesProvider.notifier);
    Note? savedNote;

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
      );
    } else {
      final oldNote = widget.note!;
      final imageChanged = !listEquals(_imagePaths, oldNote.imagePaths);
      final contentChanged =
          title != oldNote.title ||
          content != oldNote.content ||
          !listEquals(_tags, oldNote.tags) ||
          _eventAt != oldNote.eventAt ||
          _reminderMinutes != (oldNote.reminderMinutes ?? 10);

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
          clearEvent: _eventAt == null,
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

    await _syncCalendar(savedNote);
  }

  Future<void> _syncCalendar(Note? savedNote) async {
    if (savedNote == null) return;

    final calendarService = ref.read(calendarServiceProvider);
    final notifier = ref.read(notesProvider.notifier);
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
    setState(() => _eventAt = null);
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
      ref.read(notesProvider.notifier).delete(widget.note!.id);
      Navigator.of(context).pop();
    }
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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final noteBackground = _colorIndex != null
        ? NoteColors.bg(_colorIndex!, Theme.of(context).brightness)
        : scheme.surface;
    final pageColor = Color.alphaBlend(
      scheme.surface.withValues(alpha: 0.24),
      noteBackground,
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _save();
        if (mounted) navigator.pop();
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
                final navigator = Navigator.of(context);
                await _save();
                if (mounted) navigator.pop();
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
        body: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            decoration: BoxDecoration(
              color: scheme.surface.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(28),
              border: Border.all(
                color: scheme.outlineVariant.withValues(alpha: 0.35),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                EditorToolbar(
                  tags: _tags,
                  tagCtrl: _tagCtrl,
                  colorIndex: _colorIndex,
                  onAddTag: (val) {
                    _addTag(val);
                    _recordHistory(immediate: true);
                  },
                  onRemoveTag: (t) {
                    setState(() => _tags.remove(t));
                    _recordHistory(immediate: true);
                  },
                  onColorChanged: (idx) {
                    setState(() => _colorIndex = idx);
                    _recordHistory(immediate: true);
                  },
                  scheme: scheme,
                  tt: tt,
                ),
                const SizedBox(height: 18),
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
                const SizedBox(height: 8),
                EditorEventSection(
                  eventAt: _eventAt,
                  reminderMinutes: _reminderMinutes,
                  onPickDateTime: _pickEventDateTime,
                  onClear: _eventAt == null ? null : _clearEventDateTime,
                  onReminderChanged: (value) {
                    setState(() => _reminderMinutes = value);
                    _recordHistory(immediate: true);
                  },
                ),
                const SizedBox(height: 8),
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
