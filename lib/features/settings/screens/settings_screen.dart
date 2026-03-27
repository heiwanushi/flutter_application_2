import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/settings_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(accentColorProvider);
    final userAsync = ref.watch(authStateProvider);
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Настройки'),
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.only(bottom: 32),
        children: [
          _SectionTitle(title: 'АККАУНТ'),
          userAsync.when(
            data: (user) => user == null
                ? ListTile(
                    leading: CircleAvatar(
                      backgroundColor: colorScheme.primaryContainer,
                      child: Icon(Icons.cloud_sync_rounded, color: colorScheme.onPrimaryContainer),
                    ),
                    title: const Text('Включить синхронизацию'),
                    subtitle: const Text('Войти через Google'),
                    onTap: () => ref.read(authServiceProvider).signInWithGoogle(),
                  )
                : ListTile(
                    leading: user.photoURL != null
                        ? CircleAvatar(backgroundImage: CachedNetworkImageProvider(user.photoURL!))
                        : CircleAvatar(
                            backgroundColor: colorScheme.primaryContainer,
                            child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
                          ),
                    title: Text(user.displayName ?? 'Пользователь'),
                    subtitle: Text(user.email ?? ''),
                    trailing: IconButton(
                      icon: const Icon(Icons.logout_rounded),
                      tooltip: 'Выйти',
                      onPressed: () => _showSignOutDialog(context, ref),
                    ),
                  ),
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(16.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Ошибка: $e', style: TextStyle(color: colorScheme.error)),
            ),
          ),
          const Divider(height: 32),
          _SectionTitle(title: 'ОФОРМЛЕНИЕ'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тема', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment(value: ThemeMode.system, label: Text('Авто')),
                      ButtonSegment(value: ThemeMode.light, label: Text('Светлая')),
                      ButtonSegment(value: ThemeMode.dark, label: Text('Тёмная')),
                    ],
                    selected: {currentTheme},
                    onSelectionChanged: (vals) async {
                      final value = vals.first;
                      ref.read(themeModeProvider.notifier).state = value;
                      await ref.read(settingsServiceProvider).saveThemeIndex(value.index);
                    },
                    showSelectedIcon: true,
                  ),
                ),
                const SizedBox(height: 24),
                Text('Акцентный цвет', style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _ColorSwatch(
                        color: colorScheme.primary,
                        isSelected: currentAccent == null,
                        isSystem: true,
                        onTap: () => _setAccentColor(ref, null),
                      ),
                      const SizedBox(width: 12),
                      ..._accentColors.map(
                        (choice) => Padding(
                          padding: const EdgeInsets.only(right: 12),
                          child: _ColorSwatch(
                            color: choice.color,
                            isSelected: currentAccent == choice.color.toARGB32(),
                            onTap: () => _setAccentColor(ref, choice.color.toARGB32()),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _setAccentColor(WidgetRef ref, int? colorValue) async {
    ref.read(accentColorProvider.notifier).state = colorValue;
    await ref.read(settingsServiceProvider).saveAccentColor(colorValue);
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.logout_rounded),
        title: const Text('Выйти из аккаунта?'),
        content: const Text('Вы больше не сможете синхронизировать свои данные, пока не войдете снова.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton.tonal(
            onPressed: () {
              ref.read(authServiceProvider).signOut();
              Navigator.pop(ctx);
            },
            child: const Text('Выйти'),
          ),
        ],
      ),
    );
  }
}

// Вспомогательный виджет для заголовков секций (Material Design)
class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
            ),
      ),
    );
  }
}

// Виджет выбора цвета (стандартный Material кружок с галочкой)
class _ColorSwatch extends StatelessWidget {
  final Color color;
  final bool isSelected;
  final bool isSystem;
  final VoidCallback onTap;

  const _ColorSwatch({
    required this.color,
    required this.isSelected,
    required this.onTap,
    this.isSystem = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: isSystem && !isSelected
              ? Border.all(color: Theme.of(context).colorScheme.outline, width: 1)
              : null,
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: color.withValues(alpha: 0.4),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: isSelected
            ? Icon(
                Icons.check_rounded,
                color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                    ? Colors.white
                    : Colors.black,
              )
            : isSystem
                ? Icon(
                    Icons.auto_awesome_rounded,
                    color: ThemeData.estimateBrightnessForColor(color) == Brightness.dark
                        ? Colors.white
                        : Colors.black,
                    size: 20,
                  )
                : null,
      ),
    );
  }
}

class _AccentColorOption {
  final String label;
  final Color color;

  const _AccentColorOption(this.label, this.color);
}

const _accentColors = [
  _AccentColorOption('Blue', Color(0xFF3B82F6)),
  _AccentColorOption('Green', Color(0xFF16A34A)),
  _AccentColorOption('Orange', Color(0xFFF97316)),
  _AccentColorOption('Rose', Color(0xFFE11D48)),
  _AccentColorOption('Teal', Color(0xFF0F766E)),
  _AccentColorOption('Gold', Color(0xFFD4A017)),
];