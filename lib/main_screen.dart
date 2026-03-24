import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'features/notes/screens/notes_list_screen.dart';
import 'features/notes/screens/note_editor_screen.dart';
import 'features/settings/screens/settings_screen.dart';

final navIndexProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedIndex = ref.watch(navIndexProvider);

    // В стеке теперь только два постоянных экрана
    final screens = [
      const NotesListScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        // Если индекс 2 (настройки), показываем screens[1]
        index: selectedIndex == 2 ? 1 : 0, 
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        // Для визуального выделения иконок
        selectedIndex: selectedIndex,
        onDestinationSelected: (index) {
          if (index == 1) {
            // Кнопка "Создать": не меняем вкладку, а открываем экран поверх
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const NoteEditorScreen()),
            );
          } else {
            // Заметки или Настройки: меняем вкладку
            ref.read(navIndexProvider.notifier).state = index;
          }
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.notes_outlined),
            selectedIcon: Icon(Icons.notes_rounded),
            label: 'Заметки',
          ),
          NavigationDestination(
            icon: Icon(Icons.add_circle_outline_rounded),
            selectedIcon: Icon(Icons.add_circle_rounded),
            label: 'Создать',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded),
            label: 'Настройки',
          ),
        ],
      ),
    );
  }
}