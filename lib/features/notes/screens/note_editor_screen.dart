import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../../core/services/calendar_service.dart';
import '../../../core/utils/note_colors.dart';
import '../../../data/models/note.dart';
import '../providers/notes_provider.dart';

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
      // Отдельно синхронизируем только если изменились картинки или основной контент
      final imagedChanged = !listEquals(_imagePaths, oldNote.imagePaths);
      final contentChanged =
          title != oldNote.title ||
          content != oldNote.content ||
          !listEquals(_tags, oldNote.tags) ||
          _eventAt != oldNote.eventAt ||
          _reminderMinutes != (oldNote.reminderMinutes ?? 10);

      if (imagedChanged || contentChanged) {
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
      // setColor и togglePin обновляют локально, БЕЗ синхронизации картинок
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

  void _openImageViewer(int index) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            _ImageViewerScreen(paths: _imagePaths, initialIndex: index),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final bg = _colorIndex != null
        ? NoteColors.bg(_colorIndex!, Theme.of(context).brightness)
        : scheme.surface;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final navigator = Navigator.of(context);
        await _save();
        if (mounted) navigator.pop();
      },
      child: Scaffold(
        backgroundColor: bg,
        appBar: AppBar(
          backgroundColor: bg,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: () async {
              final navigator = Navigator.of(context);
              await _save();
              if (mounted) navigator.pop();
            },
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.undo_rounded),
              onPressed: _historyIndex > 0 ? _undo : null,
              color: _historyIndex > 0
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.2),
            ),
            IconButton(
              icon: const Icon(Icons.redo_rounded),
              onPressed: _historyIndex < _history.length - 1 ? _redo : null,
              color: _historyIndex < _history.length - 1
                  ? scheme.onSurface
                  : scheme.onSurface.withValues(alpha: 0.2),
            ),
            const SizedBox(width: 8),
            if (widget.note != null)
              _Btn(
                color: scheme.errorContainer,
                onTap: _delete,
                child: Icon(
                  Icons.delete_outline_rounded,
                  size: 22,
                  color: scheme.onErrorContainer,
                ),
              ),
            const SizedBox(width: 8),
            _Btn(
              color: scheme.secondaryContainer,
              onTap: _pickImage,
              child: Icon(
                Icons.add_photo_alternate_outlined,
                size: 22,
                color: scheme.onSecondaryContainer,
              ),
            ),
            const SizedBox(width: 8),
            _Btn(
              color: _isPinned
                  ? scheme.primaryContainer
                  : scheme.surfaceContainerHighest,
              onTap: () {
                setState(() => _isPinned = !_isPinned);
                _recordHistory(immediate: true);
              },
              child: Icon(
                _isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
                size: 22,
                color: _isPinned
                    ? scheme.onPrimaryContainer
                    : scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(width: 12),
          ],
        ),
        body: Column(
          children: [
            _buildToolBar(scheme, tt, bg),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_imagePaths.isNotEmpty) _buildImageGallery(),
                    TextField(
                      controller: _titleCtrl,
                      style: tt.headlineSmall?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      maxLines: null,
                      decoration: const InputDecoration(
                        hintText: 'Название',
                        border: InputBorder.none,
                      ),
                    ),
                    _EventSection(
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
                      decoration: const InputDecoration(
                        hintText: 'Заметка...',
                        border: InputBorder.none,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolBar(ColorScheme scheme, TextTheme tt, Color bg) {
    return Container(
      color: bg,
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: [
          SizedBox(
            height: 40,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: NoteColors.count + 1,
              itemBuilder: (context, i) {
                final isSelected = i == 0
                    ? _colorIndex == null
                    : _colorIndex == i - 1;
                return GestureDetector(
                  onTap: () {
                    setState(() => _colorIndex = i == 0 ? null : i - 1);
                    _recordHistory(immediate: true);
                  },
                  child: Container(
                    width: 36,
                    margin: const EdgeInsets.only(right: 10),
                    decoration: BoxDecoration(
                      color: i == 0
                          ? scheme.surfaceContainerHighest
                          : NoteColors.bg(i - 1, Theme.of(context).brightness),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: isSelected
                            ? scheme.primary
                            : scheme.outlineVariant.withValues(alpha: 0.3),
                        width: isSelected ? 2.5 : 1,
                      ),
                    ),
                    child: isSelected
                        ? Icon(
                            i == 0
                                ? Icons.format_color_reset_rounded
                                : Icons.check,
                            size: 18,
                            color: scheme.primary,
                          )
                        : null,
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                ..._tags.map(
                  (t) => Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: InputChip(
                      label: Text(t, style: const TextStyle(fontSize: 12)),
                      onDeleted: () {
                        setState(() => _tags.remove(t));
                        _recordHistory(immediate: true);
                      },
                      backgroundColor: scheme.secondaryContainer.withValues(
                        alpha: 0.3,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),
                ),
                SizedBox(
                  width: 80,
                  child: TextField(
                    controller: _tagCtrl,
                    style: tt.bodySmall,
                    decoration: const InputDecoration(
                      hintText: '+ Тег',
                      border: InputBorder.none,
                    ),
                    onSubmitted: (val) {
                      _addTag(val);
                      _recordHistory(immediate: true);
                    },
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 24, thickness: 0.5),
        ],
      ),
    );
  }

  Widget _buildImageGallery() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16, top: 8),
      child: SizedBox(
        height: 180,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          itemCount: _imagePaths.length,
          separatorBuilder: (context, index) => const SizedBox(width: 12),
          itemBuilder: (ctx, i) => _ImageThumb(
            path: _imagePaths[i],
            onRemove: () {
              setState(() => _imagePaths.removeAt(i));
              _recordHistory(immediate: true);
            },
            onTap: () => _openImageViewer(i),
          ),
        ),
      ),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (picked == null) return;
    final dir = await getApplicationDocumentsDirectory();
    final fileName =
        '${DateTime.now().millisecondsSinceEpoch}${p.extension(picked.path)}';
    final dest = File(p.join(dir.path, fileName));
    await File(picked.path).copy(dest.path);
    setState(() => _imagePaths.add(dest.path));
    _recordHistory(immediate: true);
  }

  void _addTag(String value) {
    final tag = value.trim();
    if (tag.isNotEmpty && !_tags.contains(tag)) {
      setState(() => _tags.add(tag));
      _tagCtrl.clear();
    }
  }
}

class _EventSection extends StatelessWidget {
  final DateTime? eventAt;
  final int reminderMinutes;
  final VoidCallback onPickDateTime;
  final VoidCallback? onClear;
  final ValueChanged<int> onReminderChanged;

  const _EventSection({
    required this.eventAt,
    required this.reminderMinutes,
    required this.onPickDateTime,
    required this.onClear,
    required this.onReminderChanged,
  });

  static const _reminderOptions = <int>[5, 10, 15, 30, 60, 180, 1440];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final formattedDate = eventAt == null
        ? 'Не выбрано'
        : DateFormat('dd.MM.yyyy, HH:mm').format(eventAt!);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.event_outlined, size: 18, color: scheme.primary),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Событие и напоминание',
                  style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              if (onClear != null)
                IconButton(
                  onPressed: onClear,
                  tooltip: 'Убрать событие',
                  icon: const Icon(Icons.close_rounded, size: 18),
                ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPickDateTime,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                color: scheme.surface,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: scheme.outlineVariant.withValues(alpha: 0.45),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.schedule_rounded, color: scheme.onSurfaceVariant),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      formattedDate,
                      style: tt.bodyMedium?.copyWith(
                        fontWeight: eventAt == null
                            ? FontWeight.w400
                            : FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (eventAt != null) ...[
            const SizedBox(height: 12),
            DropdownButtonFormField<int>(
              initialValue: reminderMinutes,
              decoration: const InputDecoration(
                labelText: 'Напомнить',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              items: _reminderOptions
                  .map(
                    (minutes) => DropdownMenuItem(
                      value: minutes,
                      child: Text(_reminderLabel(minutes)),
                    ),
                  )
                  .toList(),
              onChanged: (value) {
                if (value != null) onReminderChanged(value);
              },
            ),
          ],
        ],
      ),
    );
  }

  String _reminderLabel(int minutes) {
    if (minutes < 60) return 'За $minutes мин';
    if (minutes < 1440) return 'За ${minutes ~/ 60} ч';
    return 'За ${minutes ~/ 1440} д';
  }
}

class _ImageThumb extends StatelessWidget {
  final String path;
  final VoidCallback onRemove;
  final VoidCallback onTap;
  const _ImageThumb({
    required this.path,
    required this.onRemove,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    Widget imageWidget;
    if (path.startsWith('http')) {
      imageWidget = CachedNetworkImage(
        imageUrl: path,
        height: 180,
        fit: BoxFit.cover,
        placeholder: (ctx, url) => Container(
          height: 180,
          color: Colors.black12,
          child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        errorWidget: (ctx, url, error) => const SizedBox.shrink(),
      );
    } else {
      imageWidget = Image.file(
        File(path),
        height: 180,
        fit: BoxFit.cover,
        cacheHeight: 400,
      );
    }
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            imageWidget,
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black45,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, size: 16, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ImageViewerScreen extends StatefulWidget {
  final List<String> paths;
  final int initialIndex;
  const _ImageViewerScreen({required this.paths, required this.initialIndex});

  @override
  State<_ImageViewerScreen> createState() => _ImageViewerScreenState();
}

class _ImageViewerScreenState extends State<_ImageViewerScreen> {
  late PageController _pageCtrl;
  late int _current;

  @override
  void initState() {
    super.initState();
    _current = widget.initialIndex;
    _pageCtrl = PageController(initialPage: widget.initialIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Text('${_current + 1} / ${widget.paths.length}'),
      ),
      body: PageView.builder(
        controller: _pageCtrl,
        itemCount: widget.paths.length,
        onPageChanged: (v) => setState(() => _current = v),
        itemBuilder: (ctx, i) {
          final path = widget.paths[i];
          Widget imageWidget;
          if (path.startsWith('http')) {
            imageWidget = CachedNetworkImage(
              imageUrl: path,
              placeholder: (ctx, url) => const Center(
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
              errorWidget: (ctx, url, error) => const Icon(
                Icons.broken_image,
                color: Colors.white38,
                size: 64,
              ),
            );
          } else {
            imageWidget = Image.file(File(path));
          }
          return InteractiveViewer(child: Center(child: imageWidget));
        },
      ),
    );
  }
}

class _Btn extends StatelessWidget {
  final Color color;
  final VoidCallback onTap;
  final Widget child;
  const _Btn({required this.color, required this.onTap, required this.child});
  @override
  Widget build(BuildContext context) => Material(
    color: color,
    borderRadius: BorderRadius.circular(12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: child,
      ),
    ),
  );
}
