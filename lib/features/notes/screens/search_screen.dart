import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/utils/note_colors.dart';
import '../../../data/models/note.dart';
import '../providers/notes_provider.dart';
import '../widgets/note_card.dart';
import 'note_editor_screen.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _ctrl = TextEditingController();
  final _focus = FocusNode();
  String _query = '';
  int? _colorFilter;
  String? _tagFilter;
  List<String> _history = [];

  static const _historyKey = 'search_history';
  static const _maxHistory = 10;

  @override
  void initState() {
    super.initState();
    _loadHistory();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focus.requestFocus());
  }

  @override
  void dispose() {
    _ctrl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() => _history = prefs.getStringList(_historyKey) ?? []);
  }

  Future<void> _saveHistory(String q) async {
    if (q.isEmpty) return;
    final prefs = await SharedPreferences.getInstance();
    final h = [q, ..._history.where((e) => e != q)].take(_maxHistory).toList();
    await prefs.setStringList(_historyKey, h);
    setState(() => _history = h);
  }

  Future<void> _removeHistory(String q) async {
    final prefs = await SharedPreferences.getInstance();
    final h = _history.where((e) => e != q).toList();
    await prefs.setStringList(_historyKey, h);
    setState(() => _history = h);
  }

  void _submit(String q) {
    final trimmed = q.trim();
    if (trimmed.isEmpty) return;
    _saveHistory(trimmed);
    setState(() => _query = trimmed);
    _focus.unfocus();
  }

  void _applyHistory(String q) {
    _ctrl.text = q;
    setState(() => _query = q);
    _focus.unfocus();
  }

  List<Note> _filter(List<Note> all) {
    return all.where((n) {
      final matchQ = _query.isEmpty ||
          n.title.toLowerCase().contains(_query.toLowerCase()) ||
          n.content.toLowerCase().contains(_query.toLowerCase()) ||
          n.tags.any((t) => t.toLowerCase().contains(_query.toLowerCase()));
      final matchColor = _colorFilter == null || n.colorIndex == _colorFilter;
      final matchTag = _tagFilter == null || n.tags.contains(_tagFilter);
      return matchQ && matchColor && matchTag;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final tt = Theme.of(context).textTheme;
    final allNotes = ref.watch(notesProvider).value ?? [];
    final allTags = ref.watch(allTagsProvider);
    final results = _filter(allNotes);
    final showResults = _query.isNotEmpty || _colorFilter != null || _tagFilter != null;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      appBar: AppBar(
        backgroundColor: scheme.surfaceContainerLow,
        surfaceTintColor: Colors.transparent,
        titleSpacing: 0,
        title: Container(
          height: 50,
          margin: const EdgeInsets.only(right: 12),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              const SizedBox(width: 12),
              Icon(Icons.search_rounded, size: 22, color: scheme.outline),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  focusNode: _focus,
                  style: tt.bodyMedium,
                  decoration: InputDecoration(
                    hintText: 'Поиск заметок...',
                    hintStyle: TextStyle(color: scheme.outline),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (v) => setState(() => _query = v),
                  onSubmitted: _submit,
                  textInputAction: TextInputAction.search,
                ),
              ),
              if (_query.isNotEmpty)
                GestureDetector(
                  onTap: () {
                    _ctrl.clear();
                    setState(() => _query = '');
                  },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10),
                    child: Icon(Icons.close_rounded, size: 20, color: scheme.outline),
                  ),
                ),
            ],
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Filters ──────────────────────────────────────────────
          Container(
            color: scheme.surfaceContainerLow,
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Color filter
                SizedBox(
                  height: 40,
                  child: ListView.builder(
                    scrollDirection: Axis.horizontal,
                    itemCount: NoteColors.count + 1,
                    itemBuilder: (_, i) {
                      if (i == 0) {
                        final sel = _colorFilter == null;
                        return GestureDetector(
                          onTap: () => setState(() => _colorFilter = null),
                          child: Container(
                            width: 34,
                            height: 34,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainerHigh,
                              borderRadius: BorderRadius.circular(9),
                              border: Border.all(
                                color: sel ? scheme.primary : scheme.outlineVariant,
                                width: sel ? 2 : 1,
                              ),
                            ),
                            child: Icon(
                              Icons.palette_outlined,
                              size: 16,
                              color: sel ? scheme.primary : scheme.outline,
                            ),
                          ),
                        );
                      }
                      final idx = i - 1;
                      final sel = _colorFilter == idx;
                      return GestureDetector(
                        onTap: () => setState(
                            () => _colorFilter = sel ? null : idx),
                        child: Container(
                          width: 34,
                          height: 34,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: NoteColors.bg(idx, brightness),
                            borderRadius: BorderRadius.circular(9),
                            border: Border.all(
                              color: sel ? scheme.primary : scheme.outlineVariant,
                              width: sel ? 2.5 : 1,
                            ),
                          ),
                          child: sel
                              ? Icon(Icons.check_rounded, size: 16, color: scheme.primary)
                              : null,
                        ),
                      );
                    },
                  ),
                ),
                if (allTags.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 36,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: allTags
                          .map((t) {
                            final sel = _tagFilter == t;
                            return GestureDetector(
                              onTap: () => setState(
                                  () => _tagFilter = sel ? null : t),
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 150),
                                margin: const EdgeInsets.only(right: 8),
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 14, vertical: 6),
                                decoration: BoxDecoration(
                                  color: sel
                                      ? scheme.primaryContainer
                                      : scheme.surfaceContainerHigh,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  t,
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: sel
                                        ? FontWeight.w600
                                        : FontWeight.normal,
                                    color: sel
                                        ? scheme.onPrimaryContainer
                                        : scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            );
                          })
                          .toList(),
                    ),
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),

          // ── Content ───────────────────────────────────────────────
          Expanded(
            child: showResults
                ? results.isEmpty
                    ? Center(
                        child: Text('Ничего не найдено',
                            style: tt.bodyLarge?.copyWith(color: scheme.outline)),
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 32),
                        itemCount: results.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 8),
                        itemBuilder: (_, i) => NoteCard(
                          key: ValueKey(results[i].id),
                          note: results[i],
                          onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => NoteEditorScreen(note: results[i]),
                            ),
                          ),
                          onDelete: () =>
                              ref.read(notesProvider.notifier).delete(results[i].id),
                          onTogglePin: () =>
                              ref.read(notesProvider.notifier).togglePin(results[i].id),
                        ),
                      )
                : _history.isEmpty
                    ? const SizedBox.shrink()
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 32),
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(left: 4, bottom: 8),
                            child: Text('История',
                                style: tt.labelMedium
                                    ?.copyWith(color: scheme.outline)),
                          ),
                          ..._history.map((h) => ListTile(
                                contentPadding:
                                    const EdgeInsets.symmetric(horizontal: 4),
                                leading: Icon(Icons.history_rounded,
                                    color: scheme.onSurfaceVariant),
                                title: Text(h),
                                trailing: IconButton(
                                  icon: Icon(Icons.close_rounded,
                                      size: 16, color: scheme.outline),
                                  onPressed: () => _removeHistory(h),
                                ),
                                onTap: () => _applyHistory(h),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10)),
                              )),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
