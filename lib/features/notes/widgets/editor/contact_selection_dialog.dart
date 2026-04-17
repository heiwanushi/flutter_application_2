import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../data/models/note.dart';
import '../../providers/contacts_provider.dart';

class ContactSelectionDialog extends ConsumerStatefulWidget {
  const ContactSelectionDialog({super.key});

  @override
  ConsumerState<ContactSelectionDialog> createState() => _ContactSelectionDialogState();
}

class _ContactSelectionDialogState extends ConsumerState<ContactSelectionDialog> {
  String _query = '';
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    
    final pinnedAsync = ref.watch(pinnedContactsProvider);
    final allAsync = ref.watch(allSystemContactsProvider);
    final searched = ref.watch(searchedContactsProvider(_query));

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      backgroundColor: scheme.surface,
      child: Container(
        padding: const EdgeInsets.all(24),
        constraints: const BoxConstraints(maxWidth: 400, maxHeight: 600),
        child: Column(
          children: [
            Row(
              children: [
                Icon(Icons.person_search_rounded, color: scheme.primary),
                const SizedBox(width: 12),
                Text(
                  'Выбор контакта',
                  style: tt.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _ctrl,
              onChanged: (val) => setState(() => _query = val),
              decoration: InputDecoration(
                hintText: 'Поиск по имени или номеру',
                prefixIcon: const Icon(Icons.search_rounded),
                filled: true,
                fillColor: scheme.surfaceContainerHigh,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: CustomScrollView(
                slivers: [
                  if (_query.isEmpty) ...[
                    pinnedAsync.when(
                      data: (pinned) => pinned.isEmpty
                          ? const SliverToBoxAdapter(child: SizedBox.shrink())
                          : SliverToBoxAdapter(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.symmetric(vertical: 8),
                                    child: Text(
                                      'ЗАКРЕПЛЕННЫЕ',
                                      style: tt.labelMedium?.copyWith(
                                        color: scheme.primary,
                                        fontWeight: FontWeight.w800,
                                        letterSpacing: 1.1,
                                      ),
                                    ),
                                  ),
                                  ...pinned.map((c) => _ContactTile(contact: c, isPinned: true)),
                                  const Divider(height: 32),
                                ],
                              ),
                            ),
                      loading: () => const SliverToBoxAdapter(child: Center(child: Padding(
                        padding: EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ))),
                      error: (e, s) => const SliverToBoxAdapter(child: SizedBox.shrink()),
                    ),
                  ],
                  allAsync.when(
                    data: (all) => SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final contact = _query.isEmpty ? all[index] : searched[index];
                          final isPinned = pinnedAsync.value?.any((p) => p.phoneNumber == contact.phoneNumber) ?? false;
                          
                          // Hide already shown in pinned if no query
                          if (_query.isEmpty && isPinned) return const SizedBox.shrink();
                          
                          return _ContactTile(contact: contact, isPinned: isPinned);
                        },
                        childCount: _query.isEmpty ? all.length : searched.length,
                      ),
                    ),
                    loading: () => const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator())),
                    error: (e, s) => SliverToBoxAdapter(child: Center(child: Text('Ошибка: $e'))),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactTile extends ConsumerWidget {
  final NoteContact contact;
  final bool isPinned;

  const _ContactTile({required this.contact, required this.isPinned});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: CircleAvatar(
        backgroundColor: scheme.primaryContainer,
        child: Text(contact.name.isNotEmpty ? contact.name[0].toUpperCase() : '?'),
      ),
      title: Text(contact.name, style: tt.bodyLarge?.copyWith(fontWeight: FontWeight.w600)),
      subtitle: Text(contact.phoneNumber, style: tt.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(
              isPinned ? Icons.push_pin_rounded : Icons.push_pin_outlined,
              size: 20,
              color: isPinned ? scheme.primary : scheme.outline,
            ),
            onPressed: () {
              ref.read(pinnedContactsProvider.notifier).togglePin(contact);
            },
          ),
        ],
      ),
      onTap: () => Navigator.pop(context, contact),
    );
  }
}
