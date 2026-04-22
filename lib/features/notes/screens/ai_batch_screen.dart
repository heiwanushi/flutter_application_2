import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ai_batch_provider.dart';

class AiBatchScreen extends ConsumerWidget {
  const AiBatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final batchState = ref.watch(aiBatchProvider);
    final notifier = ref.read(aiBatchProvider.notifier);
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final progress = batchState.total == 0 ? 0.0 : batchState.processed / batchState.total;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Умная обработка'),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Icon & Animation area
            Container(
              padding: const EdgeInsets.all(32),
              decoration: BoxDecoration(
                color: scheme.primaryContainer.withValues(alpha: 0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.auto_awesome,
                size: 64,
                color: scheme.primary,
              ),
            ),
            const SizedBox(height: 32),

            // Общая статистика базы
            if (batchState.status == AiBatchStatus.idle || batchState.status == AiBatchStatus.completed)
              _OverallStatsCard(
                total: batchState.overallTotal,
                processed: batchState.overallProcessed,
                scheme: scheme,
                tt: tt,
              ),

            const SizedBox(height: 24),
            
            Text(
              batchState.status == AiBatchStatus.processing
                  ? 'Обработка заметок...'
                  : batchState.status == AiBatchStatus.completed
                      ? 'Готово!'
                      : batchState.status == AiBatchStatus.error
                          ? 'Ошибка'
                          : 'Начать обработку',
              style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'ИИ структурирует ваши заметки, добавляет теги,\nсобытия и контакты в фоновом режиме.',
              textAlign: TextAlign.center,
              style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 48),

            // Progress Section
            if (batchState.total > 0 || batchState.status == AiBatchStatus.processing) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 12,
                  backgroundColor: scheme.surfaceContainerHighest,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${(progress * 100).toInt()}%',
                    style: tt.labelLarge?.copyWith(color: scheme.primary, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${batchState.processed} из ${batchState.total}',
                    style: tt.labelLarge?.copyWith(color: scheme.onSurfaceVariant),
                  ),
                ],
              ),
            ],

            if (batchState.error != null) ...[
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: scheme.errorContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: scheme.error),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        batchState.error!,
                        style: TextStyle(color: scheme.onErrorContainer),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            const Spacer(),

            // Actions
            Row(
              children: [
                if (batchState.status == AiBatchStatus.processing)
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => notifier.stop(),
                      icon: const Icon(Icons.stop_rounded),
                      label: const Text('Остановить'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        side: BorderSide(color: scheme.error),
                        foregroundColor: scheme.error,
                      ),
                    ),
                  )
                else
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () {
                         if (batchState.status == AiBatchStatus.completed) {
                           notifier.reset();
                         }
                         notifier.startProcessing();
                      },
                      icon: const Icon(Icons.play_arrow_rounded),
                      label: Text(batchState.status == AiBatchStatus.completed ? 'Запустить снова' : 'Запустить'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _OverallStatsCard extends StatelessWidget {
  final int total;
  final int processed;
  final ColorScheme scheme;
  final TextTheme tt;

  const _OverallStatsCard({
    required this.total,
    required this.processed,
    required this.scheme,
    required this.tt,
  });

  @override
  Widget build(BuildContext context) {
    final remaining = total - processed;
    final progress = total == 0 ? 1.0 : processed / total;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: scheme.outlineVariant, width: 1),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Text(
                'Состояние базы',
                style: tt.titleSmall?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Text(
                '${(progress * 100).toInt()}%',
                style: tt.titleSmall?.copyWith(
                  color: scheme.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: scheme.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(scheme.primary),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Осталось обработать:',
                style: tt.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
              ),
              Text(
                '$remaining заметок',
                style: tt.bodySmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: remaining > 0 ? scheme.primary : scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
