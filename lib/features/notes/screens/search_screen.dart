import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/utils/note_colors.dart';
import '../../../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/event_note_cards.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

enum SearchScope { all, events }

class SearchScreen extends ConsumerStatefulWidget {
  final bool embedInScaffold;

  const SearchScreen({super.key, this.embedInScaffold = false});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();

  Timer? _debounce;
  String _inputValue = '';
  String _query = '';
  int? _colorFilter;
  String? _tagFilter;
  SearchScope _scope = SearchScope.all;
  List<String> _history = [];

  static const _historyKey = 'search_history';
  static const _maxHistory = 10;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    if (!widget.embedInScaffold) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _focus.requestFocus();
      });
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() => _history = prefs.getStringList(_historyKey) ?? []);
  }

  Future<void> _saveHistory(String q) async {
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final history = [
      q,
      ..._history.where((item) => item != q),
    ].take(_maxHistory).toList();
    await prefs.setStringList(_historyKey, history);
    if (!mounted) return;
    setState(() => _history = history);
  }

  Future<void> _removeHistory(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final history = _history.where((item) => item != q).toList();
    await prefs.setStringList(_historyKey, history);
    if (!mounted) return;
    setState(() => _history = history);
  }

  void _submit(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    _debounce?.cancel();
    _saveHistory(trimmed);
    setState(() {
      _inputValue = trimmed;
      _query = trimmed;
    });
    _focus.unfocus();
  }

  void _applyHistory(String q) {
    _debounce?.cancel();
    _ctrl.text = q;
    setState(() {
      _inputValue = q;
      _query = q;
    });
    _focus.unfocus();
  }

  List<Note> _filter(List<Note> allNotes) {
    final query = _query.toLowerCase();
    return allNotes.where((note) {
      final matchQuery =
          query.isEmpty ||
          note.title.toLowerCase().contains(query) ||
          note.content.toLowerCase().contains(query) ||
          note.tags.any((tag) => tag.toLowerCase().contains(query));
      final matchColor =
          _colorFilter == null || note.colorIndex == _colorFilter;
      final matchTag = _tagFilter == null || note.tags.contains(_tagFilter);
      final matchScope = _scope == SearchScope.all || note.eventAt != null;
      return matchQuery && matchColor && matchTag && matchScope;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final brightness = Theme.of(context).brightness;
    final allNotes = ref.watch(notesProvider).value ?? [];
    final allTags = ref.watch(allTagsProvider);

    final showResults =
        _inputValue.isNotEmpty ||
        _colorFilter != null ||
        _tagFilter != null ||
        _scope == SearchScope.events;
    final results = showResults ? _filter(allNotes) : const <Note>[];

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SearchBar(
                    controller: _ctrl,
                    focusNode: _focus,
                    hintText: 'Поиск заметок и событий',
                    leading: const Icon(Icons.search_rounded),
                    trailing: [
                      if (_inputValue.isNotEmpty)
                        IconButton(
                          onPressed: () {
                            _debounce?.cancel();
                            _ctrl.clear();
                            setState(() {
                              _inputValue = '';
                              _query = '';
                            });
                          },
                          icon: const Icon(Icons.close_rounded),
                        ),
                    ],
                    elevation: WidgetStateProperty.all(0),
                    backgroundColor: WidgetStateProperty.all(
                      scheme.surfaceContainerHigh,
                    ),
                    side: WidgetStateProperty.all(
                      BorderSide(
                        color: scheme.outlineVariant.withValues(alpha: 0.45),
                      ),
                    ),
                    onChanged: (value) {
                      _debounce?.cancel();
                      setState(() => _inputValue = value);
                      _debounce = Timer(const Duration(milliseconds: 220), () {
                        if (!mounted) return;
                        setState(() => _query = value.trim());
                      });
                    },
                    onSubmitted: _submit,
                  ),
                  const SizedBox(height: 12),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        SegmentedButton<SearchScope>(
                          segments: const [
                            ButtonSegment(
                              value: SearchScope.all,
                              icon: Icon(Icons.notes_rounded, size: 18),
                              label: Text('Все'),
                            ),
                            ButtonSegment(
                              value: SearchScope.events,
                              icon: Icon(Icons.event_rounded, size: 18),
                              label: Text('События'),
                            ),
                          ],
                          selected: {_scope},
                          onSelectionChanged: (selection) =>
                              setState(() => _scope = selection.first),
                        ),
                        const SizedBox(width: 8),
                        FilterChip(
                          label: const Text('Цвет'),
                          selected: _colorFilter != null,
                          avatar: CircleAvatar(
                            radius: 9,
                            backgroundColor: _colorFilter == null
                                ? scheme.surfaceContainerHighest
                                : NoteColors.bg(_colorFilter!, brightness),
                          ),
                          onSelected: (_) => _showColorPicker(context, scheme),
                        ),
                      ],
                    ),
                  ),
                  if (allTags.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 38,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: allTags.map((tag) {
                          final selected = _tagFilter == tag;
                          return Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: FilterChip(
                              label: Text(tag),
                              selected: selected,
                              onSelected: (_) => setState(
                                () => _tagFilter = selected ? null : tag,
                              ),
                            ),
                          );
                        }).toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: showResults
                  ? _buildResults(context, results)
                  : _buildHistory(scheme, tt),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResults(BuildContext context, List<Note> results) {
    if (results.isEmpty) {
      final scheme = Theme.of(context).colorScheme;
      final tt = Theme.of(context).textTheme;
      return Center(
        child: Text(
          'Ничего не найдено',
          style: tt.bodyLarge?.copyWith(color: scheme.outline),
        ),
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
      itemCount: results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (_, i) {
        final note = results[i];
        if (note.eventAt != null) {
          return UpcomingEventCard(
            note: note,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
            ),
          );
        }
        return NoteCard(
          note: note,
          onTap: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
          ),
          onDelete: () {},
          onTogglePin: () {},
        );
      },
    );
  }

  Widget _buildHistory(ColorScheme scheme, TextTheme tt) {
    if (_history.isEmpty) {
      return Center(
        child: Text(
          'Введите запрос для поиска',
          style: tt.bodyLarge?.copyWith(color: scheme.outline),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            'История',
            style: tt.labelMedium?.copyWith(color: scheme.outline),
          ),
        ),
        ..._history.map(
          (item) => ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 8),
            leading: Icon(
              Icons.history_rounded,
              color: scheme.onSurfaceVariant,
            ),
            title: Text(item),
            trailing: IconButton(
              icon: Icon(Icons.close_rounded, size: 16, color: scheme.outline),
              onPressed: () => _removeHistory(item),
            ),
            onTap: () => _applyHistory(item),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _showColorPicker(
    BuildContext context,
    ColorScheme scheme,
  ) async {
    final brightness = Theme.of(context).brightness;
    final selected = await showModalBottomSheet<int?>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _ColorChoice(
                label: 'Без цвета',
                selected: _colorFilter == null,
                color: scheme.surfaceContainerHighest,
                onTap: () => Navigator.pop(context, null),
              ),
              ...List.generate(
                NoteColors.count,
                (i) => _ColorChoice(
                  label: 'Цвет ${i + 1}',
                  selected: _colorFilter == i,
                  color: NoteColors.bg(i, brightness),
                  onTap: () => Navigator.pop(context, i),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted) return;
    setState(() => _colorFilter = selected);
  }
}

class _ColorChoice extends StatelessWidget {
  final String label;
  final bool selected;
  final Color color;
  final VoidCallback onTap;

  const _ColorChoice({
    required this.label,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: 104,
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? scheme.primary : scheme.outlineVariant,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(
                color: color,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.outlineVariant),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelMedium,
            ),
          ],
        ),
      ),
    );
  }
}
