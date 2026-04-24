import 'dart:async';
import 'dart:developer' as dev;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/gemini_service.dart';
import '../../notes/providers/notes_provider.dart';
import '../../notes/providers/contacts_provider.dart';
import '../../notes/providers/notes_filters_provider.dart';

enum AiBatchStatus { idle, processing, completed, error }

class AiBatchState {
  final AiBatchStatus status;
  final int total;
  final int processed;
  final int overallTotal;
  final int overallProcessed;
  final String? error;

  AiBatchState({
    this.status = AiBatchStatus.idle,
    this.total = 0,
    this.processed = 0,
    this.overallTotal = 0,
    this.overallProcessed = 0,
    this.error,
  });

  AiBatchState copyWith({
    AiBatchStatus? status,
    int? total,
    int? processed,
    int? overallTotal,
    int? overallProcessed,
    String? error,
  }) {
    return AiBatchState(
      status: status ?? this.status,
      total: total ?? this.total,
      processed: processed ?? this.processed,
      overallTotal: overallTotal ?? this.overallTotal,
      overallProcessed: overallProcessed ?? this.overallProcessed,
      error: error,
    );
  }
}

final aiBatchProvider = StateNotifierProvider<AiBatchNotifier, AiBatchState>((ref) {
  final notifier = AiBatchNotifier(ref);
  // Обновляем статистику при изменении списка заметок
  ref.listen(notesProvider, (prev, next) {
    notifier.refreshOverallStats();
  }, fireImmediately: true);
  return notifier;
});

class AiBatchNotifier extends StateNotifier<AiBatchState> {
  final Ref _ref;
  bool _isStopped = false;

  AiBatchNotifier(this._ref) : super(AiBatchState()) {
    // Начальный расчет статистики
    Future.microtask(() => refreshOverallStats());
  }

  void refreshOverallStats() {
    final allNotes = _ref.read(notesProvider).value ?? [];
    final activeNotes = allNotes.where((n) => !n.isDeleted && n.content.trim().isNotEmpty).toList();
    final processedNotes = activeNotes.where((n) => n.tags.contains('AI')).length;
    
    state = state.copyWith(
      overallTotal: activeNotes.length,
      overallProcessed: processedNotes,
    );
  }

  void stop() {
    _isStopped = true;
    state = state.copyWith(status: AiBatchStatus.idle);
  }

  void reset() {
    _isStopped = false;
    state = AiBatchState();
  }

  Future<void> startProcessing() async {
    if (state.status == AiBatchStatus.processing) return;
    
    _isStopped = false;
    final allNotes = _ref.read(notesProvider).value ?? [];
    
    // Выбираем заметки без тега "AI" и не удаленные
    final notesToProcess = allNotes
        .where((n) => !n.isDeleted && !n.tags.contains('AI') && n.content.trim().isNotEmpty)
        .toList();

    if (notesToProcess.isEmpty) {
      state = state.copyWith(status: AiBatchStatus.completed, total: 0, processed: 0);
      return;
    }

    state = state.copyWith(
      status: AiBatchStatus.processing,
      total: notesToProcess.length,
      processed: 0,
    );

    final gemini = _ref.read(geminiServiceProvider);
    
    // Гарантируем загрузку контактов (ждем завершения фьючерса)
    final userContacts = await _ref.read(allSystemContactsProvider.future);

    const int batchSize = 5;
    for (int i = 0; i < notesToProcess.length; i += batchSize) {
      if (_isStopped) break;

      final chunk = notesToProcess.sublist(
        i, 
        i + batchSize > notesToProcess.length ? notesToProcess.length : i + batchSize,
      );

      try {
        final existingFolders = _ref.read(allTagsProvider);
        final results = await gemini.structureNotesBatch(
          chunk,
          userContacts: userContacts,
          existingFolders: existingFolders,
        );

        for (final note in chunk) {
          final structured = results[note.id];
          if (structured != null) {
            // Исправлено: берем теги, созданные нейросетью, и добавляем наш системный тег 'AI'
            final updatedTags = {...structured.tags, 'AI'}.toList();
            
            await _ref.read(notesProvider.notifier).editNote(
              note.id,
              title: structured.title,
              content: structured.content,
              tags: updatedTags,
              imagePaths: note.imagePaths,
              eventAt: structured.eventAt,
              reminderMinutes: structured.reminderMinutes,
              contacts: structured.contacts,
              originalContent: note.content,
              colorIndex: structured.colorIndex,
            );
          }
        }

        state = state.copyWith(processed: state.processed + chunk.length);
      } catch (e) {
        dev.log('AiBatchNotifier: Error processing chunk: $e');
        // Продолжаем дальше или останавливаемся? Для пакетной обработки лучше попробовать пропустить ошибку
        // но если ошибка фатальная (например, API лимит), то лучше прервать.
        if (e.toString().contains('429')) {
           state = state.copyWith(status: AiBatchStatus.error, error: 'Превышен лимит запросов (Rate Limit)');
           return;
        }
      }
    }

    if (!_isStopped) {
      state = state.copyWith(status: AiBatchStatus.completed);
    }
  }
}
