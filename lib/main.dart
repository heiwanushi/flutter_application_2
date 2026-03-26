import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/note_deep_links.dart';
import 'data/models/note.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/notes/screens/note_editor_screen.dart';
import 'firebase_options.dart';
import 'main_screen.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  await Supabase.initialize(
    url: 'https://usgquikdsefdgmuumiyu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzZ3F1aWtkc2VmZGdtdXVtaXl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNzI0MzksImV4cCI6MjA4OTc0ODQzOX0.asaTvbu5MB_ILPTfPPRJb_HFdR33JhDBz-bgX63ohNg',
  );

  final container = ProviderContainer();
  final settings = container.read(settingsServiceProvider);

  final themeIndex = await settings.loadThemeIndex();
  final viewIndex = await settings.loadViewMode();
  final sortIndex = await settings.loadSortMode();
  final sortAsc = await settings.loadSortAsc();

  container.read(themeModeProvider.notifier).state =
      ThemeMode.values[themeIndex];
  container
      .read(viewModeProvider.notifier)
      .setInitial(ViewMode.values[viewIndex]);
  container
      .read(sortModeProvider.notifier)
      .setInitial(SortMode.values[sortIndex]);
  container.read(sortAscProvider.notifier).setInitial(sortAsc);

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}

class App extends ConsumerStatefulWidget {
  const App({super.key});

  @override
  ConsumerState<App> createState() => _AppState();
}

class _AppState extends ConsumerState<App> {
  final AppLinks _appLinks = AppLinks();
  StreamSubscription<Uri>? _linkSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    await _handleIncomingLink(initialLink);

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    });
  }

  Future<void> _handleIncomingLink(Uri? uri) async {
    final noteId = extractNoteIdFromDeepLink(uri);
    if (noteId == null) return;

    final notes = await ref.read(notesProvider.future);
    final note = _findNote(notes, noteId);
    if (note == null) return;

    ref.read(navIndexProvider.notifier).state = 0;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !mounted) return;

    await Future<void>.delayed(Duration.zero);
    navigator.push(
      MaterialPageRoute(builder: (_) => NoteEditorScreen(note: note)),
    );
  }

  Note? _findNote(List<Note> notes, String id) {
    for (final note in notes) {
      if (note.id == id) return note;
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        navigatorKey: appNavigatorKey,
        title: 'Заметки',
        theme: AppTheme.light(lightDynamic),
        darkTheme: AppTheme.dark(darkDynamic),
        themeMode: themeMode,
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}
