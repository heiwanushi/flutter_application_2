import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../data/models/note.dart';
import '../providers/notes_filters_provider.dart';

import '../widgets/event_note_cards.dart';
import 'note_editor_screen.dart';

class EventsScreen extends ConsumerWidget {
  const EventsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final remindersAsync = ref.watch(reminderNotesProvider);

    void openNote(Note note) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
      );
    }

    return Scaffold(
      backgroundColor: Color.alphaBlend(
        scheme.primary.withValues(alpha: 0.04),
        scheme.surface,
      ),
      body: SafeArea(
        child: remindersAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Ошибка: $e')),
          data: (notes) {
            if (notes.isEmpty) return _EmptyEventsState(scheme: scheme, tt: tt);

            final grouped = _groupNotes(notes);
            final today = grouped['today'] ?? const <Note>[];

            return CustomScrollView(
              slivers: [
                if (grouped['overdue']!.isNotEmpty)
                  _buildSmallSection(
                    'Просрочено',
                    grouped['overdue']!,
                    openNote,
                  ),
                if (today.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
                      child: _SectionHeader(
                        title: 'Сегодня',
                        subtitle: '${today.length} ${_noteWord(today.length)}',
                      ),
                    ),
                  ),
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: 240,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: today.length,
                        separatorBuilder: (_, _) => const SizedBox(width: 12),
                        itemBuilder: (context, index) => TodayEventCard(
                          note: today[index],
                          onTap: () => openNote(today[index]),
                        ),
                      ),
                    ),
                  ),
                ],
                if (grouped['tomorrow']!.isNotEmpty)
                  _buildSmallSection('Завтра', grouped['tomorrow']!, openNote),
                if (grouped['week']!.isNotEmpty)
                  _buildSmallSection(
                    'На этой неделе',
                    grouped['week']!,
                    openNote,
                  ),
                if (grouped['later']!.isNotEmpty)
                  _buildSmallSection('Позже', grouped['later']!, openNote),
                const SliverToBoxAdapter(child: SizedBox(height: 100)),
              ],
            );
          },
        ),
      ),
    );
  }

  SliverList _buildSmallSection(
    String title,
    List<Note> notes,
    void Function(Note) openNote,
  ) {
    return SliverList.list(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 10),
          child: _SectionHeader(
            title: title,
            subtitle: '${notes.length} ${_noteWord(notes.length)}',
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 0),
          child: Column(
            children: [
              for (var i = 0; i < notes.length; i++) ...[
                UpcomingEventCard(
                  note: notes[i],
                  onTap: () => openNote(notes[i]),
                ),
                if (i != notes.length - 1) const SizedBox(height: 10),
              ],
            ],
          ),
        ),
      ],
    );
  }

  Map<String, List<Note>> _groupNotes(List<Note> notes) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final weekEnd = today.add(const Duration(days: 7));

    final groups = {
      'overdue': <Note>[],
      'today': <Note>[],
      'tomorrow': <Note>[],
      'week': <Note>[],
      'later': <Note>[],
    };

    for (final note in notes) {
      final event = note.eventAt!;
      final eventDay = DateTime(event.year, event.month, event.day);
      if (event.isBefore(now) && !_isSameDay(event, now)) {
        groups['overdue']!.add(note);
      } else if (_isSameDay(event, now)) {
        groups['today']!.add(note);
      } else if (_isSameDay(eventDay, tomorrow)) {
        groups['tomorrow']!.add(note);
      } else if (eventDay.isBefore(weekEnd)) {
        groups['week']!.add(note);
      } else {
        groups['later']!.add(note);
      }
    }
    return groups;
  }

  bool _isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  static String _noteWord(int count) {
    final mod10 = count % 10;
    final mod100 = count % 100;
    if (mod10 == 1 && mod100 != 11) {
      return 'событие';
    }
    if (mod10 >= 2 && mod10 <= 4 && (mod100 < 12 || mod100 > 14)) {
      return 'события';
    }
    return 'событий';
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final String subtitle;

  const _SectionHeader({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Row(
      children: [
        Expanded(
          child: Text(
            title,
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w900),
          ),
        ),
        Text(
          subtitle,
          style: tt.bodySmall?.copyWith(
            color: scheme.onSurfaceVariant,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _EmptyEventsState extends StatelessWidget {
  final ColorScheme scheme;
  final TextTheme tt;

  const _EmptyEventsState({required this.scheme, required this.tt});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 28),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 88,
              height: 88,
              decoration: BoxDecoration(
                color: scheme.primaryContainer,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.event_available_rounded,
                size: 40,
                color: scheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 18),
            Text(
              'Пока нет событий',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'Добавьте напоминание в заметке, и оно появится здесь отдельной карточкой.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}
