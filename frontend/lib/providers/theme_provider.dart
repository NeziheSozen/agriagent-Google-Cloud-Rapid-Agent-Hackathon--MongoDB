import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';
import 'shared_prefs_provider.dart';

part 'theme_provider.g.dart';

/// Theme mode notifier — persists to SharedPreferences.
@Riverpod(keepAlive: true)
class ThemeNotifier extends _$ThemeNotifier {
  static const _themeKey = 'selected_theme';

  @override
  ThemeMode build() {
    AppTracker.info('Provider build: theme_provider.dart');

    final prefs = ref.watch(sharedPreferencesProvider);
    final themeStr = prefs.getString(_themeKey);
    if (themeStr == 'light') return ThemeMode.light;
    if (themeStr == 'dark') return ThemeMode.dark;
    return ThemeMode.system;
  }

  void setTheme(ThemeMode mode) {
    state = mode;
    final prefs = ref.read(sharedPreferencesProvider);
    if (mode == ThemeMode.light) {
      prefs.setString(_themeKey, 'light');
    } else if (mode == ThemeMode.dark) {
      prefs.setString(_themeKey, 'dark');
    } else {
      prefs.setString(_themeKey, 'system');
    }
  }
}

