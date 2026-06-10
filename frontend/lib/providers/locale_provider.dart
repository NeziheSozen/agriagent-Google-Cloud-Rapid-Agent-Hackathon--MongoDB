import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';
import 'shared_prefs_provider.dart';

part 'locale_provider.g.dart';

/// Locale notifier — persists to SharedPreferences.
@Riverpod(keepAlive: true)
class LocaleNotifier extends _$LocaleNotifier {
  static const _localeKey = 'selected_locale';

  @override
  Locale? build() {
    AppTracker.info('Provider build: locale_provider.dart');

    final prefs = ref.watch(sharedPreferencesProvider);
    final langCode = prefs.getString(_localeKey);
    if (langCode != null && langCode.isNotEmpty) {
      return Locale(langCode);
    }
    return null; // system default
  }

  void setLocale(Locale? locale) {
    state = locale;
    final prefs = ref.read(sharedPreferencesProvider);
    if (locale == null) {
      prefs.remove(_localeKey);
    } else {
      prefs.setString(_localeKey, locale.languageCode);
    }
  }
}

