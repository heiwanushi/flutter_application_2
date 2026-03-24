import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart'; // Добавь этот импорт
import '../../../core/services/settings_service.dart';
import '../../../core/services/auth_service.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final currentTheme = ref.watch(themeModeProvider);
    final userAsync = ref.watch(authStateProvider);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLow,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Text(
                'Настройки',
                style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.w900),
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _buildSectionTitle('Аккаунт'),
                  userAsync.when(
                    data: (user) => user == null 
                      ? _ProminentAccountCard(
                          title: 'Войти в аккаунт',
                          subtitle: 'Включите облачную синхронизацию',
                          icon: Icons.login_rounded,
                          backgroundColor: scheme.primaryContainer,
                          foregroundColor: scheme.onPrimaryContainer,
                          onTap: () => ref.read(authServiceProvider).signInWithGoogle(),
                        )
                      : _ProminentAccountCard(
                          title: user.displayName ?? 'Пользователь',
                          subtitle: user.email ?? '',
                          image: user.photoURL, // Передаем URL
                          backgroundColor: scheme.secondaryContainer,
                          foregroundColor: scheme.onSecondaryContainer,
                          isLoggedIn: true,
                          onTap: () => _showSignOutDialog(context, ref),
                        ),
                    loading: () => const _LoadingCard(),
                    error: (e, _) => Text('Ошибка: $e'),
                  ),
                  const SizedBox(height: 32),
                  _buildSectionTitle('Оформление'),
                  _SettingsCard(
                    title: 'Тема приложения',
                    subtitle: _themeText(currentTheme),
                    icon: Icons.palette_outlined,
                    scheme: scheme,
                    onTap: () => _chooseTheme(context, ref, currentTheme),
                  ),
                  const SizedBox(height: 12),
                  _SettingsCard(
                    title: 'Версия',
                    subtitle: '1.2.8 Stable',
                    icon: Icons.info_outline_rounded,
                    scheme: scheme,
                    onTap: () {}, 
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ... (методы _buildSectionTitle, _themeText, _showSignOutDialog, _chooseTheme остаются прежними)
  
  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(left: 8, bottom: 8),
      child: Text(
        title.toUpperCase(),
        style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1.2, color: Colors.grey),
      ),
    );
  }

  String _themeText(ThemeMode mode) {
    return switch (mode) {
      ThemeMode.system => 'Системная',
      ThemeMode.light => 'Светлая',
      ThemeMode.dark => 'Темная',
    };
  }

  void _showSignOutDialog(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Выйти из аккаунта?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton.tonal(
            onPressed: () {
              ref.read(authServiceProvider).signOut();
              Navigator.pop(ctx);
            }, 
            child: const Text('Выйти')
          ),
        ],
      ),
    );
  }

  void _chooseTheme(BuildContext context, WidgetRef ref, ThemeMode current) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerHigh,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 16),
            ...ThemeMode.values.map((mode) => RadioListTile<ThemeMode>(
              title: Text(_themeText(mode)),
              value: mode,
              groupValue: current,
              onChanged: (val) {
                if (val != null) {
                  ref.read(themeModeProvider.notifier).state = val;
                  ref.read(settingsServiceProvider).saveThemeIndex(val.index);
                  Navigator.pop(context);
                }
              },
            )),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _ProminentAccountCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData? icon;
  final String? image;
  final Color backgroundColor;
  final Color foregroundColor;
  final VoidCallback onTap;
  final bool isLoggedIn;

  const _ProminentAccountCard({
    required this.title,
    required this.subtitle,
    this.icon,
    this.image,
    required this.backgroundColor,
    required this.foregroundColor,
    required this.onTap,
    this.isLoggedIn = false,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: backgroundColor,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              // КЭШИРОВАННАЯ АВАТАРКА
              if (image != null)
                CachedNetworkImage(
                  imageUrl: image!,
                  imageBuilder: (context, imageProvider) => CircleAvatar(
                    radius: 28,
                    backgroundImage: imageProvider,
                  ),
                  // Заглушка, пока качается
                  placeholder: (context, url) => Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: foregroundColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                    child: const CircularProgressIndicator(strokeWidth: 2),
                  ),
                  // Ошибка (например, нет интернета)
                  errorWidget: (context, url, error) => const CircleAvatar(
                    radius: 28,
                    child: Icon(Icons.person),
                  ),
                )
              else
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: foregroundColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(icon, color: foregroundColor, size: 32),
                ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TextStyle(fontWeight: FontWeight.w900, fontSize: 18, color: foregroundColor)),
                    Text(subtitle, style: TextStyle(color: foregroundColor.withValues(alpha: 0.7), fontSize: 13)),
                  ],
                ),
              ),
              Icon(isLoggedIn ? Icons.logout_rounded : Icons.arrow_forward_ios_rounded, color: foregroundColor, size: isLoggedIn ? 24 : 16),
            ],
          ),
        ),
      ),
    );
  }
}

// ... Остальные виджеты (_SettingsCard, _LoadingCard) остаются прежними
class _SettingsCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final ColorScheme scheme;
  final VoidCallback onTap;

  const _SettingsCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.scheme,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: scheme.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: scheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
                child: Icon(icon, color: scheme.primary, size: 22),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    Text(subtitle, style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: scheme.outline),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 90,
      decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(24)),
      child: const Center(child: CircularProgressIndicator()),
    );
  }
}