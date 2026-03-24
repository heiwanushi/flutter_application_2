import 'package:dynamic_color/dynamic_color.dart';
import 'package:firebase_core/firebase_core.dart'; // Импорт Firebase
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'core/theme/app_theme.dart';
import 'core/services/settings_service.dart';
import 'features/notes/providers/notes_provider.dart';
import 'main_screen.dart';
import 'firebase_options.dart'; // Сгенерированный файл настроек Firebase

void main() async {
  // 1. Обязательная привязка виджетов Flutter
  WidgetsFlutterBinding.ensureInitialized();
  
  // 2. Инициализация Firebase (обязательно перед запуском приложения)
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

    // Инициализация Supabase
  await Supabase.initialize(
    url: 'https://usgquikdsefdgmuumiyu.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVzZ3F1aWtkc2VmZGdtdXVtaXl1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzQxNzI0MzksImV4cCI6MjA4OTc0ODQzOX0.asaTvbu5MB_ILPTfPPRJb_HFdR33JhDBz-bgX63ohNg',
  );
  
  // 3. Создаем контейнер для доступа к провайдерам до старта UI
  final container = ProviderContainer();
  final settings = container.read(settingsServiceProvider);
  
  // 4. Загружаем все сохраненные настройки из памяти телефона
  final themeIndex = await settings.loadThemeIndex();
  final viewIndex = await settings.loadViewMode();
  final sortIndex = await settings.loadSortMode();
  final sortAsc = await settings.loadSortAsc();

  // 5. Прокидываем загруженные значения в соответствующие провайдеры
  container.read(themeModeProvider.notifier).state = ThemeMode.values[themeIndex];
  container.read(viewModeProvider.notifier).setInitial(ViewMode.values[viewIndex]);
  container.read(sortModeProvider.notifier).setInitial(SortMode.values[sortIndex]);
  container.read(sortAscProvider.notifier).setInitial(sortAsc);

  // 6. Запускаем приложение
  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const App(),
    ),
  );
}

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Подписываемся на изменение темы в реальном времени
    final themeMode = ref.watch(themeModeProvider);

    return DynamicColorBuilder(
      builder: (lightDynamic, darkDynamic) => MaterialApp(
        title: 'Заметки',
        theme: AppTheme.light(lightDynamic),
        darkTheme: AppTheme.dark(darkDynamic),
        themeMode: themeMode, // Применяем тему (Системная/Светлая/Темная)
        home: const MainScreen(),
        debugShowCheckedModeBanner: false,
      ),
    );
  }
}