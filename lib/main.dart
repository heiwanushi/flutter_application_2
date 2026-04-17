import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:receive_sharing_intent/receive_sharing_intent.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/services/notification_service.dart';
import 'core/services/settings_service.dart';
import 'core/theme/app_theme.dart';
import 'core/utils/note_deep_links.dart';
import 'data/models/note.dart';
import 'features/notes/providers/notes_filters_provider.dart';
import 'features/notes/providers/notes_provider.dart';
import 'features/notes/screens/note_editor_screen.dart';
import 'firebase_options.dart';
import 'main_screen.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Colors.transparent,
  ));

  await Hive.initFlutter();
  await Hive.openBox<String>('notesBox');
  await NotificationService().init();
  await initializeDateFormatting('ru');

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(
    // ignore: deprecated_member_use
    androidProvider: AndroidProvider.playIntegrity,
  );

  await Supabase.initialize(
    url: 'https://usgquikdsefdgmuumiyu.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzZ3F1aWtkc2VmZGdtdXVtaXl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNzI0MzksImV4cCI6MjA4OTc0ODQzOX0.asaTvbu5MB_ILPTfPPRJb_HFdR33JhDBz-bgX63ohNg',
  );

  final container = ProviderContainer();
  final settings = container.read(settingsServiceProvider);

  final themeIndex = await settings.loadThemeIndex();
  final viewIndex = await settings.loadViewMode();
  final mainModeIndex = await settings.loadMainMode();
  final sortIndex = await settings.loadSortMode();
  final sortAsc = await settings.loadSortAsc();
  final accentColor = await settings.loadAccentColor();

  container.read(themeModeProvider.notifier).state =
      ThemeMode.values[themeIndex];
  container
      .read(viewModeProvider.notifier)
      .setInitial(ViewMode.values[viewIndex]);
  container
      .read(mainScreenModeProvider.notifier)
      .setInitial(MainScreenMode.values[mainModeIndex]);
  container
      .read(sortModeProvider.notifier)
      .setInitial(SortMode.values[sortIndex]);
  container.read(sortAscProvider.notifier).setInitial(sortAsc);
  container.read(accentColorProvider.notifier).state = accentColor;

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
  StreamSubscription<List<SharedMediaFile>>? _intentDataStreamSubscription;

  @override
  void initState() {
    super.initState();
    _initDeepLinks();
    _initSharingIntent();
  }

  @override
  void dispose() {
    _linkSubscription?.cancel();
    _intentDataStreamSubscription?.cancel();
    super.dispose();
  }

  Future<void> _initDeepLinks() async {
    final initialLink = await _appLinks.getInitialLink();
    await _handleIncomingLink(initialLink);

    _linkSubscription = _appLinks.uriLinkStream.listen((uri) {
      _handleIncomingLink(uri);
    });
  }

  void _initSharingIntent() {
    // Handling media AND Text/URLs shared while app is in memory
    _intentDataStreamSubscription =
        ReceiveSharingIntent.instance.getMediaStream().listen((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
      }
    }, onError: (err) {
      debugPrint("getMediaStream error: $err");
    });

    // Handling media AND Text/URLs shared while app is closed
    ReceiveSharingIntent.instance.getInitialMedia().then((value) {
      if (value.isNotEmpty) {
        _handleSharedMedia(value);
      }
    });
  }

  void _handleSharedMedia(List<SharedMediaFile> media) async {
    if (media.isEmpty) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null) return;

    // Reset to first tab (Notes)
    ref.read(navIndexProvider.notifier).state = 0;
    await Future<void>.delayed(Duration.zero);

    String? path;
    String? text;

    for (var file in media) {
      if (file.type == SharedMediaType.image) {
        path = file.path;
      } else if (file.type == SharedMediaType.text ||
          file.type == SharedMediaType.url) {
        text = file.path;
      }
    }

    if (path != null || text != null) {
      navigator.push(
        MaterialPageRoute(
          builder: (_) => NoteEditorScreen(
            initialImagePath: path,
            initialText: text,
          ),
        ),
      );
    }
    
    ReceiveSharingIntent.instance.reset();
  }

  Future<void> _handleIncomingLink(Uri? uri) async {
    if (uri == null) return;

    final navigator = appNavigatorKey.currentState;
    if (navigator == null || !mounted) return;

    // Handle "New Note" from Widget
    if (uri.scheme == 'notesapp' && uri.host == 'new') {
      ref.read(navIndexProvider.notifier).state = 0;
      await Future<void>.delayed(Duration.zero);
      navigator.push(
        MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
      );
      return;
    }

    // Handle "Screenshot & Note" from Tile
    if (uri.scheme == 'notesapp' && uri.host == 'screenshot') {
      final path = uri.queryParameters['path'];
      if (path != null) {
        ref.read(navIndexProvider.notifier).state = 0;
        await Future<void>.delayed(Duration.zero);
        navigator.push(
          MaterialPageRoute(
            builder: (_) => NoteEditorScreen(initialImagePath: path),
          ),
        );
        return;
      }
    }

    // Handle existing note deep link
    final noteId = extractNoteIdFromDeepLink(uri);
    if (noteId == null) return;

    final notes = await ref.read(notesProvider.future);
    final note = _findNote(notes, noteId);
    if (note == null) return;

    ref.read(navIndexProvider.notifier).state = 0;

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
    final accentColorValue = ref.watch(accentColorProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) {
        final accentColor = accentColorValue == null
            ? null
            : Color(accentColorValue);
        final lightScheme = accentColor == null
            ? lightDynamic
            : ColorScheme.fromSeed(seedColor: accentColor);
        final darkScheme = accentColor == null
            ? darkDynamic
            : ColorScheme.fromSeed(
                seedColor: accentColor,
                brightness: Brightness.dark,
              );

        return MaterialApp(
          navigatorKey: appNavigatorKey,
          title: 'Заметки',
          theme: AppTheme.light(lightScheme),
          darkTheme: AppTheme.dark(darkScheme),
          themeMode: themeMode,
          home: const MainScreen(),
          debugShowCheckedModeBanner: false,
        );
      },
    );
  }
}
