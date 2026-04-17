import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:permission_handler/permission_handler.dart' hide PermissionStatus;
import '../../../data/models/note.dart';
import '../../../data/repositories/contacts_repository.dart';

final contactsRepositoryProvider = Provider((ref) => ContactsRepository());

final pinnedContactsProvider = AsyncNotifierProvider<PinnedContactsNotifier, List<NoteContact>>(
  PinnedContactsNotifier.new,
);

class PinnedContactsNotifier extends AsyncNotifier<List<NoteContact>> {
  @override
  Future<List<NoteContact>> build() async {
    return ref.read(contactsRepositoryProvider).getPinnedContacts();
  }

  Future<void> togglePin(NoteContact contact) async {
    await ref.read(contactsRepositoryProvider).togglePin(contact);
    ref.invalidateSelf();
  }
}

final allSystemContactsProvider = FutureProvider<List<NoteContact>>((ref) async {
  final status = await Permission.contacts.request();
  if (!status.isGranted) return [];

  final ok = await FlutterContacts.permissions.request(PermissionType.read);
  if (ok != PermissionStatus.granted && ok != PermissionStatus.limited) return [];

  final systemContacts = await FlutterContacts.getAll(
    properties: {ContactProperty.name, ContactProperty.phone},
  );
  return systemContacts
      .where((c) => c.phones.isNotEmpty)
      .map((c) => NoteContact(
            name: c.displayName ?? 'Без имени',
            phoneNumber: c.phones.first.number,
          ))
      .toList();
});

final searchedContactsProvider = Provider.family<List<NoteContact>, String>((ref, query) {
  final all = ref.watch(allSystemContactsProvider).value ?? [];
  if (query.isEmpty) return all;
  
  final q = query.toLowerCase();
  return all.where((c) {
    return c.name.toLowerCase().contains(q) || c.phoneNumber.contains(q);
  }).toList();
});
