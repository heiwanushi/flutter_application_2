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
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        children: [
          // Секция аккаунта
          _SectionTitle(title: 'Аккаунт'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            child: userAsync.when(
              data: (user) => user == null
                  ? ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: CircleAvatar(
                        backgroundColor: colorScheme.primaryContainer,
                        child: Icon(Icons.login_rounded, color: colorScheme.onPrimaryContainer),
                      ),
                      title: const Text('Войти в аккаунт'),
                      subtitle: const Text('Включить облачную синхронизацию'),
                      onTap: () => ref.read(authServiceProvider).signInWithGoogle(),
                    )
                  : ListTile(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      leading: user.photoURL != null
                          ? CachedNetworkImage(
                              imageUrl: user.photoURL!,
                              imageBuilder: (context, imageProvider) => CircleAvatar(
                                backgroundImage: imageProvider,
                                radius: 24,
                              ),
                              placeholder: (context, url) => const CircleAvatar(
                                radius: 24,
                                child: CircularProgressIndicator(),
                              ),
                              errorWidget: (context, url, error) => CircleAvatar(
                                radius: 24,
                                backgroundColor: colorScheme.primaryContainer,
                                child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
                              ),
                            )
                          : CircleAvatar(
                              radius: 24,
                              backgroundColor: colorScheme.primaryContainer,
                              child: Icon(Icons.person, color: colorScheme.onPrimaryContainer),
                            ),
                      title: Text(user.displayName ?? 'Пользователь'),
                      subtitle: Text(user.email ?? ''),
                      trailing: IconButton(
                        icon: const Icon(Icons.logout_rounded),
                        onPressed: () => _showSignOutDialog(context, ref),
                        tooltip: 'Выйти',
                      ),
                    ),
              loading: () => const Padding(
                padding: EdgeInsets.all(24.0),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Ошибка: $e', style: TextStyle(color: colorScheme.error)),
              ),
            ),
          ),
          
          const SizedBox(height: 24),

          // Секция оформления
          _SectionTitle(title: 'Оформление'),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainer,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ListTile(
                  leading: const Icon(Icons.dark_mode_outlined),
                  title: const Text('Тема приложения'),
                  subtitle: Text(_themeText(currentTheme)),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _chooseTheme(context, ref, currentTheme),
                ),
                const Divider(height: 1),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Акцентный цвет',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        currentAccent == null
                            ? 'Используется системный Dynamic Color'
                            : 'Выбран пользовательский цвет',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: [
                          _ColorSwatch(
                            color: colorScheme.primary,
                            isSelected: currentAccent == null,
                            isSystem: true,
                            onTap: () => _setAccentColor(ref, null),
                          ),
                          ..._accentColors.map(
                            (choice) => _ColorSwatch(
                              color: choice.color,
                              isSelected: currentAccent == choice.color.toARGB32(),
                              onTap: () => _setAccentColor(ref, choice.color.toARGB32()),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Future<void> _setAccentColor(WidgetRef ref, int? colorValue) async {
    ref.read(accentColorProvider.notifier).state = colorValue;
    await ref.read(settingsServiceProvider).saveAccentColor(colorValue);
  }

  String _themeText(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Системная',
      ThemeMode.light => 'Светлая',
      ThemeMode.dark => 'Тёмная',
    };
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

  void _chooseTheme(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Выберите тему',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              ),
              ...ThemeMode.values.map(
                (mode) => RadioListTile<ThemeMode>(
                  title: Text(_themeText(mode)),
                  value: mode,
                  groupValue: current,
                  onChanged: (value) async {
                    if (value == null) return;
                    ref.read(themeModeProvider.notifier).state = value;
                    await ref.read(settingsServiceProvider).saveThemeIndex(value.index);
                    if (context.mounted) Navigator.pop(context);
                  },
                ),
              ),
            ],
          ),
        ),
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
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.bold,
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