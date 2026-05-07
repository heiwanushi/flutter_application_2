import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/utils/note_colors.dart';
import '../../../data/models/note.dart';
import 'notes_provider.dart';

class NoteEditorState {
  final String title;
  final String content;
  final List<String> tags;
  final List<NoteContact> contacts;
  final List<String> imagePaths;
  final int? colorIndex;
  final bool isPinned;
  final DateTime? eventAt;
  final int reminderMinutes;
  final NoteRepeatMode repeatMode;
  final bool isCompleted;
  final String? originalContent;
  final bool isAIProcessing;
  final bool isPreviewMode;
  final bool isSaving;
  final bool canPop;
  final String? calendarId;
  final String? calendarEventId;

  NoteEditorState({
    this.title = '',
    this.content = '',
    this.tags = const [],
    this.contacts = const [],
    this.imagePaths = const [],
    this.colorIndex,
    this.isPinned = false,
    this.eventAt,
    this.reminderMinutes = 10,
    this.repeatMode = NoteRepeatMode.none,
    this.isCompleted = false,
    this.originalContent,
    this.isAIProcessing = false,
    this.isPreviewMode = false,
    this.isSaving = false,
    this.canPop = false,
    this.calendarId,
    this.calendarEventId,
  });

  NoteEditorState copyWith({
    String? title,
    String? content,
    List<String>? tags,
    List<NoteContact>? contacts,
    List<String>? imagePaths,
    int? colorIndex,
    bool? isPinned,
    DateTime? eventAt,
    int? reminderMinutes,
    NoteRepeatMode? repeatMode,
    bool? isCompleted,
    String? originalContent,
    bool? isAIProcessing,
    bool? isPreviewMode,
     bool? isSaving,
    bool? canPop,
    String? calendarId,
    String? calendarEventId,
    bool clearColor = false,
    bool clearEvent = false,
  }) {
    return NoteEditorState(
      title: title ?? this.title,
      content: content ?? this.content,
      tags: tags ?? this.tags,
      contacts: contacts ?? this.contacts,
      imagePaths: imagePaths ?? this.imagePaths,
      colorIndex: clearColor ? null : (colorIndex ?? this.colorIndex),
      isPinned: isPinned ?? this.isPinned,
      eventAt: clearEvent ? null : (eventAt ?? this.eventAt),
      reminderMinutes: clearEvent ? 10 : (reminderMinutes ?? this.reminderMinutes),
      repeatMode: clearEvent ? NoteRepeatMode.none : (repeatMode ?? this.repeatMode),
      isCompleted: isCompleted ?? this.isCompleted,
      originalContent: originalContent ?? this.originalContent,
      isAIProcessing: isAIProcessing ?? this.isAIProcessing,
      isPreviewMode: isPreviewMode ?? this.isPreviewMode,
      isSaving: isSaving ?? this.isSaving,
      canPop: canPop ?? this.canPop,
      calendarId: calendarId ?? this.calendarId,
      calendarEventId: calendarEventId ?? this.calendarEventId,
    );
  }

  bool hasChanges(Note? original) {
    if (original == null) {
      return title.trim().isNotEmpty ||
          content.trim().isNotEmpty ||
          imagePaths.isNotEmpty ||
          tags.isNotEmpty ||
          eventAt != null ||
          contacts.isNotEmpty;
    }

    return !(title.trim() == original.title &&
        content.trim() == original.content &&
        colorIndex == original.colorIndex &&
        isPinned == original.isPinned &&
        eventAt == original.eventAt &&
        reminderMinutes == (original.reminderMinutes ?? 10) &&
        repeatMode == original.repeatMode &&
        isCompleted == original.isCompleted &&
        originalContent == original.originalContent &&
        listEquals(tags, original.tags) &&
        listEquals(contacts, original.contacts) &&
        listEquals(imagePaths, original.imagePaths));
  }
}

final noteEditorProvider = StateNotifierProvider.autoDispose.family<NoteEditorNotifier, NoteEditorState, Note?>(
  (ref, initialNote) => NoteEditorNotifier(initialNote),
);

class NoteEditorNotifier extends StateNotifier<NoteEditorState> {
  final Note? _initialNote;
  final List<NoteEditorState> _history = [];
  int _historyIndex = -1;
  bool _ignoreHistory = false;
  bool _isDisposed = false;

  NoteEditorNotifier(this._initialNote) : super(NoteEditorState()) {
    if (_initialNote != null) {
      state = NoteEditorState(
        title: _initialNote.title,
        content: _initialNote.content,
        tags: List.from(_initialNote.tags),
        contacts: List.from(_initialNote.contacts),
        imagePaths: List.from(_initialNote.imagePaths),
        colorIndex: _initialNote.colorIndex,
        isPinned: _initialNote.isPinned,
        eventAt: _initialNote.eventAt,
        reminderMinutes: _initialNote.reminderMinutes ?? 10,
        repeatMode: _initialNote.repeatMode,
        isCompleted: _initialNote.isCompleted,
        originalContent: _initialNote.originalContent,
        isPreviewMode: true,
        calendarId: _initialNote.calendarId,
        calendarEventId: _initialNote.calendarEventId,
      );
    }
    _recordHistory();
  }

  @override
  void dispose() {
    _isDisposed = true;
    super.dispose();
  }

  @override
  set state(NoteEditorState value) {
    if (!_isDisposed) {
      super.state = value;
    }
  }

  void updateTitle(String title) {
    state = state.copyWith(title: title);
    _recordHistory();
  }

  void updateContent(String content) {
    state = state.copyWith(content: content);
    _recordHistory();
  }

  void addTag(String tag) {
    if (tag.isNotEmpty && !state.tags.contains(tag)) {
      state = state.copyWith(tags: [...state.tags, tag]);
      _recordHistory();
    }
  }

  void removeTag(String tag) {
    state = state.copyWith(tags: state.tags.where((t) => t != tag).toList());
    _recordHistory();
  }

  void updateColor(int? index) {
    final allCategoryNames = NoteColors.categoryNames.values.toSet();
    final newCategory = index != null ? NoteColors.categoryNames[index] : null;

    bool replaced = false;
    final updatedTags = state.tags.map((tag) {
      final parts = tag.split('/');
      if (allCategoryNames.contains(parts.first)) {
        replaced = true;
        if (newCategory == null) return null;
        return [newCategory, ...parts.sublist(1)].join('/');
      }
      return tag;
    }).whereType<String>().toSet().toList();

    if (!replaced && newCategory != null) {
      updatedTags.add(newCategory);
    }

    state = state.copyWith(
      colorIndex: index,
      clearColor: index == null,
      tags: updatedTags,
    );
    _recordHistory();
  }

  void togglePin() {
    state = state.copyWith(isPinned: !state.isPinned);
    _recordHistory();
  }

  void toggleCompleted() {
    state = state.copyWith(isCompleted: !state.isCompleted);
    _recordHistory();
  }

  void setEvent(DateTime? at, int reminder, NoteRepeatMode repeat) {
    state = state.copyWith(
      eventAt: at,
      reminderMinutes: reminder,
      repeatMode: repeat,
      clearEvent: at == null,
    );
    _recordHistory();
  }

  void addContact(NoteContact contact) {
    if (!state.contacts.contains(contact)) {
      state = state.copyWith(contacts: [...state.contacts, contact]);
      _recordHistory();
    }
  }

  void removeContact(NoteContact contact) {
    state = state.copyWith(contacts: state.contacts.where((c) => c != contact).toList());
    _recordHistory();
  }

  void setImages(List<String> paths) {
    state = state.copyWith(imagePaths: paths);
    _recordHistory();
  }

  void togglePreview() {
    state = state.copyWith(isPreviewMode: !state.isPreviewMode);
  }

  void setAIProcessing(bool processing) {
    state = state.copyWith(isAIProcessing: processing);
  }

  void setSaving(bool saving) {
    state = state.copyWith(isSaving: saving);
  }

  void applyStructuredData(String original, String title, String content, List<String> tags, List<NoteContact> contacts, int? color, DateTime? event, int? reminder) {
    _ignoreHistory = true;
    state = state.copyWith(
      originalContent: original,
      title: title,
      content: content,
      tags: {...tags, 'AI'}.toList(),
      contacts: contacts,
      colorIndex: color,
      eventAt: event,
      reminderMinutes: reminder,
    );
    _ignoreHistory = false;
    _recordHistory();
  }

  void setCanPop(bool canPop) {
    state = state.copyWith(canPop: canPop);
  }

  void updateCalendarMeta(String? calendarId, String? eventId) {
    state = state.copyWith(calendarId: calendarId, calendarEventId: eventId);
  }

  // History management
  void _recordHistory() {
    if (_ignoreHistory) return;
    
    // Remove future history if we're in the middle of undo/redo
    if (_historyIndex < _history.length - 1) {
      _history.removeRange(_historyIndex + 1, _history.length);
    }

    _history.add(state);
    if (_history.length > 50) _history.removeAt(0);
    _historyIndex = _history.length - 1;
  }

  bool get canUndo => _historyIndex > 0;
  bool get canRedo => _historyIndex < _history.length - 1;

  void undo() {
    if (canUndo) {
      _ignoreHistory = true;
      _historyIndex--;
      state = _history[_historyIndex];
      _ignoreHistory = false;
    }
  }

  void redo() {
    if (canRedo) {
      _ignoreHistory = true;
      _historyIndex++;
      state = _history[_historyIndex];
      _ignoreHistory = false;
    }
  }

  Future<Note?> save(WidgetRef ref) async {
    if (state.isSaving || !state.hasChanges(_initialNote)) return null;
    setSaving(true);

    final title = state.title.trim();
    final content = state.content.trim();
    final notifier = ref.read(notesProvider.notifier);
    
    Note? savedNote;
    try {
      if (_initialNote == null) {
        savedNote = await notifier.add(
          title: title,
          content: content,
          tags: state.tags,
          imagePaths: state.imagePaths,
          colorIndex: state.colorIndex,
          isPinned: state.isPinned,
          eventAt: state.eventAt,
          reminderMinutes: state.eventAt == null ? null : state.reminderMinutes,
          repeatMode: state.repeatMode,
          originalContent: state.originalContent,
          contacts: state.contacts,
        );
      } else {
        savedNote = await notifier.editNote(
          _initialNote.id,
          title: title,
          content: content,
          tags: state.tags,
          imagePaths: state.imagePaths,
          eventAt: state.eventAt,
          reminderMinutes: state.eventAt == null ? null : state.reminderMinutes,
          calendarEventId: state.calendarEventId,
          calendarId: state.calendarId,
          repeatMode: state.repeatMode,
          clearEvent: state.eventAt == null,
          originalContent: state.originalContent,
          contacts: state.contacts,
        );
        
        if (state.colorIndex != _initialNote.colorIndex) {
          await notifier.setColor(_initialNote.id, state.colorIndex);
        }
        if (state.isPinned != _initialNote.isPinned) {
          await notifier.togglePin(_initialNote.id);
        }
        if (state.isCompleted != _initialNote.isCompleted) {
          await notifier.toggleCompleted(_initialNote.id);
        }
      }
    } finally {
      setSaving(false);
    }
    return savedNote;
  }
}
