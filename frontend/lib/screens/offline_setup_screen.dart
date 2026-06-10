import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../app/theme.dart';
import '../providers/gemma_provider.dart';
import '../app/l10n/translations.dart';

/// One-time screen shown after onboarding/first login to suggest
/// downloading the Gemma 4 model for offline use.
class OfflineSetupScreen extends ConsumerWidget {
  const OfflineSetupScreen({super.key});

  Future<void> _skipAndGoHome(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('offline_setup_shown', true);
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gemmaState = ref.watch(gemmaProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 24),
              child: Column(
                children: [
              const Spacer(flex: 1),

              // Icon
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      AgriAgentTheme.mossGreen,
                      AgriAgentTheme.mossGreen.withOpacity(0.6),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: AgriAgentTheme.mossGreen.withOpacity(0.3),
                      blurRadius: 24,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.offline_bolt_rounded,
                  color: Colors.white,
                  size: 48,
                ),
              ).animate().scale(
                    begin: const Offset(0.8, 0.8),
                    end: const Offset(1.0, 1.0),
                    duration: 600.ms,
                    curve: Curves.elasticOut,
                  ),

              const SizedBox(height: 32),

              // Title
              Text(
                L10n.tr(context, 'offline_title') ?? 'Offline AI Assistant',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms, duration: 400.ms),

              const SizedBox(height: 16),

              // Description
              Text(
                '${L10n.tr(context, 'offline_desc_1') ?? ''}\n\n'
                '${L10n.tr(context, 'offline_desc_2') ?? ''}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.6),
                      height: 1.6,
                    ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 400.ms, duration: 400.ms),

              const SizedBox(height: 12),

              // Model info chip
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.white.withOpacity(0.08)
                      : Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.memory_rounded,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.5)),
                    const SizedBox(width: 8),
                    Flexible(
                      child: Text(
                        L10n.tr(context, 'model_info') ?? 'Gemma 4 E2B  •  ~1 GB  •  Download once, use anytime',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.5),
                        ),
                      ),
                    ),
                  ],
                ),
              ).animate().fadeIn(delay: 600.ms, duration: 400.ms),

              const Spacer(flex: 2),

              // Download progress (shown during download)
              if (gemmaState.state == GemmaState.downloading) ...[
                Column(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: gemmaState.progress,
                        minHeight: 8,
                        backgroundColor: Theme.of(context)
                            .colorScheme
                            .onSurface
                            .withOpacity(0.1),
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            AgriAgentTheme.mossGreen),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${(gemmaState.progress * 100).toStringAsFixed(1)}% ${L10n.tr(context, 'downloading_progress') ?? 'downloading...'}',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AgriAgentTheme.mossGreen,
                      ),
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ],

              // Ready state
              if (gemmaState.state == GemmaState.ready) ...[
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AgriAgentTheme.successGreen.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AgriAgentTheme.successGreen.withOpacity(0.3)),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.check_circle_rounded,
                          color: AgriAgentTheme.successGreen, size: 22),
                      const SizedBox(width: 10),
                      Flexible(
                        child: Text(
                          L10n.tr(context, 'offline_ready_msg') ?? 'Model ready! You can use it offline.',
                          style: const TextStyle(
                            color: AgriAgentTheme.successGreen,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                )
                    .animate()
                    .fadeIn(duration: 300.ms)
                    .scale(begin: const Offset(0.9, 0.9)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton(
                    onPressed: () => _skipAndGoHome(context),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AgriAgentTheme.mossGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      L10n.tr(context, 'lets_go') ?? 'Let\'s Go!',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                  ),
                ),
              ],

              // Error state
              if (gemmaState.state == GemmaState.error) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AgriAgentTheme.errorRed.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    'Error: ${gemmaState.errorMessage ?? "Unknown error"}',
                    style: const TextStyle(
                        color: AgriAgentTheme.errorRed, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Buttons (shown when not downloading and not ready)
              if (gemmaState.state != GemmaState.downloading &&
                  gemmaState.state != GemmaState.ready) ...[
                // Download button
                SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: () {
                      ref.read(gemmaProvider.notifier).downloadModel();
                    },
                    icon: const Icon(Icons.download_rounded, size: 22),
                    label: Text(
                      L10n.tr(context, 'download_model') ?? 'Download Model (~1 GB)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AgriAgentTheme.mossGreen,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                  ),
                )
                    .animate()
                    .fadeIn(delay: 800.ms, duration: 400.ms)
                    .slideY(begin: 0.2),

                const SizedBox(height: 14),

                // Skip button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: TextButton(
                    onPressed: () => _skipAndGoHome(context),
                    style: TextButton.styleFrom(
                      foregroundColor: Theme.of(context)
                          .colorScheme
                          .onSurface
                          .withOpacity(0.5),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: Theme.of(context)
                              .colorScheme
                              .onSurface
                              .withOpacity(0.12),
                        ),
                      ),
                    ),
                    child: Text(
                      L10n.tr(context, 'skip_offline') ?? 'No need, my internet is fine 👋',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ).animate().fadeIn(delay: 1000.ms, duration: 400.ms),
              ],

              const SizedBox(height: 16),

              // Note at bottom
              if (gemmaState.state != GemmaState.ready)
                Text(
                  L10n.tr(context, 'download_later') ?? 'You can also download it later from Settings.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Theme.of(context)
                        .colorScheme
                        .onSurface
                        .withOpacity(0.35),
                  ),
                  textAlign: TextAlign.center,
                ).animate().fadeIn(delay: 1200.ms),

              const Spacer(flex: 1),
            ],
          ),
        ),
          ),
        ),
      ),
    );
  }
}
