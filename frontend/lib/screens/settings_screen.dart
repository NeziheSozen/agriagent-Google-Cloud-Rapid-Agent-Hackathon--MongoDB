import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../providers/theme_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/farmer_provider.dart';
import '../app/l10n/translations.dart';
import '../widgets/glass_card.dart';
import '../widgets/developer_console.dart';
import '../providers/gemma_provider.dart';
import 'package:flutter/foundation.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeProvider);
    final locale = ref.watch(localeProvider);
    final gemmaState = ref.watch(gemmaProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.tr(context, 'settings')),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              L10n.tr(context, 'appearance'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                children: [
                  RadioListTile<ThemeMode>(
                    title: Text(L10n.tr(context, 'system_default')),
                    value: ThemeMode.system,
                    groupValue: themeMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(themeProvider.notifier).setTheme(mode);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(L10n.tr(context, 'light_theme')),
                    value: ThemeMode.light,
                    groupValue: themeMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(themeProvider.notifier).setTheme(mode);
                      }
                    },
                  ),
                  RadioListTile<ThemeMode>(
                    title: Text(L10n.tr(context, 'dark_theme')),
                    value: ThemeMode.dark,
                    groupValue: themeMode,
                    onChanged: (mode) {
                      if (mode != null) {
                        ref.read(themeProvider.notifier).setTheme(mode);
                      }
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              L10n.tr(context, 'language_label'),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              child: Column(
                children: [
                  _buildLangTile(ref, 'System Default', null),
                  _buildLangTile(ref, '🇹🇷 Türkçe', const Locale('tr')),
                  _buildLangTile(ref, '🇬🇧 English', const Locale('en')),
                  _buildLangTile(ref, '🇫🇷 Français', const Locale('fr')),
                  _buildLangTile(ref, '🇧🇷 Português', const Locale('pt')),
                  _buildLangTile(ref, '🇪🇸 Español', const Locale('es')),
                  _buildLangTile(ref, '🇮🇹 Italiano', const Locale('it')),
                  _buildLangTile(ref, '🇳🇱 Nederlands', const Locale('nl')),
                  _buildLangTile(ref, '🇨🇳 中文', const Locale('zh')),
                  _buildLangTile(ref, '🇮🇳 हिन्दी', const Locale('hi')),
                  _buildLangTile(ref, '🇯🇵 日本語', const Locale('ja')),
                  _buildLangTile(ref, '🇰🇷 한국어', const Locale('ko')),
                ],
              ),
            ),
            const SizedBox(height: 24),
            
            // --- GEMMA OFFLINE MODEL SECTION ---
            Text(
              'Offline AI (Edge Agent)',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
            ),
            const SizedBox(height: 8),
            GlassCard(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.memory_rounded, color: Theme.of(context).colorScheme.primary),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Gemma 4 E2B Local Model',
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                          ),
                        ),
                        if (gemmaState.state == GemmaState.ready)
                          const Icon(Icons.check_circle_rounded, color: Colors.green),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Download the AI model to use AgriAgent without an internet connection.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 16),
                    if (gemmaState.state == GemmaState.notDownloaded || gemmaState.state == GemmaState.error)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            ref.read(gemmaProvider.notifier).downloadModel();
                          },
                          icon: const Icon(Icons.download_rounded),
                          label: Text(L10n.tr(context, 'download_model')),
                        ),
                      ),
                    if (gemmaState.state == GemmaState.downloading)
                      Column(
                        children: [
                          LinearProgressIndicator(value: gemmaState.progress),
                          const SizedBox(height: 8),
                          Text('${(gemmaState.progress * 100).toStringAsFixed(1)}% downloaded'),
                        ],
                      ),
                    if (gemmaState.state == GemmaState.ready)
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                        decoration: BoxDecoration(
                          color: Colors.green.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.offline_bolt_rounded, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Expanded(child: Text(L10n.tr(context, 'model_ready_offline'), style: const TextStyle(color: Colors.green))),
                          ],
                        ),
                      ),
                    if (gemmaState.state == GemmaState.error)
                      Padding(
                        padding: const EdgeInsets.only(top: 8.0),
                        child: Text(
                          'Error: ${gemmaState.errorMessage}',
                          style: const TextStyle(color: Colors.red, fontSize: 12),
                        ),
                      ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => DeveloperConsole.show(context),
                icon: const Icon(Icons.bug_report_rounded),
                label: Text(L10n.tr(context, 'developer_console')),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
            const SizedBox(height: 16),
            // Logout Button
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final prefs = await SharedPreferences.getInstance();
                  await prefs.remove('logged_in_user_id');
                  ref.read(selectedFarmerIdProvider.notifier).set('guest');
                  if (context.mounted) {
                    context.go('/login');
                  }
                },
                icon: Icon(Icons.logout_rounded, color: Theme.of(context).colorScheme.error),
                label: Text(
                  L10n.tr(context, 'logout'),
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: Theme.of(context).colorScheme.error.withOpacity(0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLangTile(WidgetRef ref, String title, Locale? localeValue) {
    final currentLocale = ref.watch(localeProvider);
    return RadioListTile<Locale?>(
      title: Text(title),
      value: localeValue,
      groupValue: currentLocale,
      onChanged: (val) {
        // null means System Default
        ref.read(localeProvider.notifier).setLocale(val);
      },
    );
  }
}
