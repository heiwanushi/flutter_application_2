import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/settings_service.dart';
import '../../notes/screens/archive_screen.dart';
import '../../notes/screens/trash_screen.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final userAsync = ref.watch(authStateProvider);

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('Настройки'),
        scrolledUnderElevation: 0,
        backgroundColor: colorScheme.surface,
        centerTitle: true,
      ),
      body: ListView(
        children: [
          _SectionTitle(title: 'СИНХРОНИЗАЦИЯ'),
          userAsync.when(
            data: (user) => user == null
                ? ListTile(
                    leading: Icon(Icons.cloud_off_rounded, color: colorScheme.primary),
                    title: const Text('Синхронизация отключена'),
                    subtitle: const Text('Войти через Google для сохранения данных'),
                    onTap: () => ref.read(authServiceProvider).signInWithGoogle(),
                  )
                : ListTile(
                    leading: user.photoURL != null
                        ? CircleAvatar(radius: 16, backgroundImage: CachedNetworkImageProvider(user.photoURL!))
                        : const CircleAvatar(radius: 16, child: Icon(Icons.person)),
                    title: Text(user.displayName ?? 'Пользователь'),
                    subtitle: Text(user.email ?? ''),
                    trailing: TextButton(
                      onPressed: () => _showSignOutDialog(context, ref),
                      child: const Text('Выйти'),
                    ),
                  ),
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => ListTile(title: Text('Ошибка: $e')),
          ),
          const Divider(indent: 16, endIndent: 16),
          const SizedBox(height: 8),
          _SettingsCategoryTile(
            title: 'Искусственный интеллект',
            subtitle: 'Выбор модели и API ключи',
            icon: Icons.auto_awesome_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _AISettings()),
            ),
          ),
          _SettingsCategoryTile(
            title: 'Оформление',
            subtitle: 'Тема приложения и цвета',
            icon: Icons.palette_outlined,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _AppearanceSettings()),
            ),
          ),
          _SettingsCategoryTile(
            title: 'Данные и хранилище',
            subtitle: 'Архив событий и корзина',
            icon: Icons.storage_rounded,
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const _DataSettings()),
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsCategoryTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _SettingsCategoryTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: scheme.primary, size: 24),
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(subtitle),
      trailing: const Icon(Icons.chevron_right_rounded, size: 20),
      onTap: onTap,
    );
  }
}

// --- SUB-SCREENS ---

class _AISettings extends ConsumerStatefulWidget {
  const _AISettings();
  @override
  ConsumerState<_AISettings> createState() => _AISettingsState();
}

class _AISettingsState extends ConsumerState<_AISettings> {
  late TextEditingController _apiKeyCtrl;
  bool _obscureKey = true;

  @override
  void initState() {
    super.initState();
    _apiKeyCtrl = TextEditingController(text: ref.read(fallbackApiKeyProvider) ?? '');
  }

  @override
  void dispose() {
    _apiKeyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentModel = ref.watch(aiModelProvider);
    final useFallbackKey = ref.watch(useFallbackApiKeyProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Искусственный интеллект')),
      body: ListView(
        children: [
          _SectionTitle(title: 'ВЫБОР МОДЕЛИ'),
          _ModelTile(
            model: AIModel.gemini,
            title: 'Gemini',
            subtitle: 'Рекомендовано для обработки заметок',
            icon: Icons.auto_awesome_rounded,
            isSelected: currentModel == AIModel.gemini,
            onTap: () async {
              ref.read(aiModelProvider.notifier).state = AIModel.gemini;
              await ref.read(settingsServiceProvider).saveAIModel(AIModel.gemini);
            },
          ),
          _ModelTile(
            model: AIModel.qwen,
            title: 'Qwen',
            subtitle: 'Мощная альтернативная модель',
            icon: Icons.psychology_rounded,
            isSelected: currentModel == AIModel.qwen,
            isLocked: true,
            statusLabel: 'В РАЗРАБОТКЕ',
            onTap: null,
          ),
          const Divider(),
          _SectionTitle(title: 'API КЛЮЧ'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              children: [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Свой API ключ', style: TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: const Text('Для прямого доступа к Google AI Studio'),
                  value: useFallbackKey,
                  onChanged: (val) async {
                    ref.read(useFallbackApiKeyProvider.notifier).state = val;
                    await ref.read(settingsServiceProvider).saveUseFallbackApiKey(val);
                  },
                ),
                if (useFallbackKey) ...[
                  const SizedBox(height: 8),
                  TextField(
                    controller: _apiKeyCtrl,
                    obscureText: _obscureKey,
                    decoration: InputDecoration(
                      hintText: 'Введите API ключ',
                      isDense: true,
                      filled: true,
                      fillColor: scheme.surfaceContainerLow,
                      suffixIcon: IconButton(
                        icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                        onPressed: () => setState(() => _obscureKey = !_obscureKey),
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                    ),
                    onChanged: (val) async {
                      ref.read(fallbackApiKeyProvider.notifier).state = val.isEmpty ? null : val;
                      await ref.read(settingsServiceProvider).saveFallbackApiKey(val);
                    },
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AppearanceSettings extends ConsumerWidget {
  const _AppearanceSettings();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(accentColorProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Оформление')),
      body: ListView(
        children: [
          _SectionTitle(title: 'ТЕМА ПРИЛОЖЕНИЯ'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
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
            ),
          ),
          const SizedBox(height: 24),
          _SectionTitle(title: 'ЦВЕТОВОЙ АКЦЕНТ'),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                _ColorSwatch(
                  color: scheme.primary,
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
    );
  }

  Future<void> _setAccentColor(WidgetRef ref, int? colorValue) async {
    ref.read(accentColorProvider.notifier).state = colorValue;
    await ref.read(settingsServiceProvider).saveAccentColor(colorValue);
  }
}

class _DataSettings extends StatelessWidget {
  const _DataSettings();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Данные и хранилище')),
      body: ListView(
        children: [
          ListTile(
            leading: Icon(Icons.inventory_2_rounded, color: scheme.primary),
            title: const Text('Архив событий'),
            subtitle: const Text('Завершенные задачи и события'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchiveScreen()),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_rounded, color: scheme.primary),
            title: const Text('Корзина'),
            subtitle: const Text('Удаленные заметки'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
          ),
        ],
      ),
    );
  }
}

void _showSignOutDialog(BuildContext context, WidgetRef ref) {
  showDialog(
    context: context,
    builder: (ctx) => AlertDialog(
      icon: const Icon(Icons.logout_rounded),
      title: const Text('Выйти из аккаунта?'),
      content: const Text('Синхронизация будет приостановлена.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
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

class _ModelTile extends StatelessWidget {
  final AIModel model;
  final String title;
  final String subtitle;
  final IconData icon;
  final bool isSelected;
  final bool isLocked;
  final String? statusLabel;
  final VoidCallback? onTap;

  const _ModelTile({
    required this.model,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.isSelected,
    this.isLocked = false,
    this.statusLabel,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListTile(
      enabled: !isLocked,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: isSelected
              ? scheme.primaryContainer
              : scheme.surfaceContainerHighest.withValues(alpha: isLocked ? 0.4 : 1.0),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Icon(
          icon,
          color: isSelected
              ? scheme.onPrimaryContainer
              : scheme.onSurfaceVariant.withValues(alpha: isLocked ? 0.4 : 1.0),
        ),
      ),
      title: Row(
        children: [
          Text(
            title,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isLocked ? scheme.onSurface.withValues(alpha: 0.4) : null,
            ),
          ),
          if (statusLabel != null) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Text(
                statusLabel!,
                style: tt.labelSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 9,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
      subtitle: Text(
        subtitle,
        style: tt.bodySmall?.copyWith(
          color: isLocked ? scheme.onSurface.withValues(alpha: 0.3) : scheme.onSurfaceVariant,
        ),
      ),
      trailing: isLocked
          ? const Icon(Icons.lock_outline_rounded, size: 20)
          : isSelected
              ? Icon(Icons.check_circle_rounded, color: scheme.primary)
              : null,
      onTap: onTap,
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16, bottom: 8, top: 16),
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