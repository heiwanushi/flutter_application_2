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
    final currentTheme = ref.watch(themeModeProvider);
    final currentAccent = ref.watch(accentColorProvider);
    final currentModel = ref.watch(aiModelProvider);
    final useFallbackKey = ref.watch(useFallbackApiKeyProvider);
    final userAsync = ref.watch(authStateProvider);
    final colorScheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

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
          _SectionTitle(title: 'ИСКУССТВЕННЫЙ ИНТЕЛЛЕКТ'),
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
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: useFallbackKey 
                    ? colorScheme.primaryContainer.withValues(alpha: 0.2) 
                    : colorScheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: useFallbackKey ? colorScheme.primary : colorScheme.outlineVariant,
                  width: 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Использовать свой ключ',
                      style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      'Для прямого доступа к API Studio',
                      style: tt.bodySmall,
                    ),
                    secondary: Icon(Icons.vpn_key_rounded, color: useFallbackKey ? colorScheme.primary : null),
                    value: useFallbackKey,
                    onChanged: (val) async {
                      ref.read(useFallbackApiKeyProvider.notifier).state = val;
                      await ref.read(settingsServiceProvider).saveUseFallbackApiKey(val);
                    },
                  ),
                  if (useFallbackKey) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: _apiKeyCtrl,
                      obscureText: _obscureKey,
                      decoration: InputDecoration(
                        hintText: 'Введите ваш API ключ',
                        isDense: true,
                        fillColor: colorScheme.surface,
                        filled: true,
                        suffixIcon: IconButton(
                          icon: Icon(_obscureKey ? Icons.visibility : Icons.visibility_off),
                          onPressed: () => setState(() => _obscureKey = !_obscureKey),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
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
          ),
          const Divider(height: 32),
          _SectionTitle(title: 'ДАННЫЕ'),
          ListTile(
            leading: Icon(Icons.inventory_2_rounded, color: colorScheme.primary),
            title: const Text('Архив событий'),
            subtitle: const Text('Выполненные события собраны здесь'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const ArchiveScreen()),
            ),
          ),
          ListTile(
            leading: Icon(Icons.delete_rounded, color: colorScheme.primary),
            title: const Text('Корзина'),
            subtitle: const Text('Удалённые заметки'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => const TrashScreen()),
            ),
          ),
          const Divider(height: 32),
          _SectionTitle(title: 'ОФОРМЛЕНИЕ'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Тема', style: tt.titleMedium),
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
                Text('Акцентный цвет', style: tt.titleMedium),
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