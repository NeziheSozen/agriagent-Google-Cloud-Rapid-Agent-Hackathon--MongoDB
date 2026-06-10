import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';

import '../models/climate_trend.dart';
import '../services/climate_api.dart';
import 'farmer_provider.dart';
import 'locale_provider.dart';

import 'dart:convert';
import 'shared_prefs_provider.dart';

part 'climate_provider.g.dart';

/// Fetches climate trends for a given location and language.
/// The argument is a combined string: "location|lang" (e.g. "Tekirdağ|tr").
@riverpod
Future<ClimateTrend> climateTrend(Ref ref, String locationAndLang) async {
  final parts = locationAndLang.split('|');
  final location = parts[0];
  final lang = parts.length > 1 ? parts[1] : 'en';
  
  final api = ref.read(climateApiProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final cacheKey = 'cache_climate_${location}_$lang';
  
  try {
    final data = await api.getTrends(location: location, lang: lang);
    // Cache it
    await prefs.setString(cacheKey, jsonEncode(data.toJson()));
    await prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
    return data;
  } catch (e) {
    AppTracker.warn('Failed to fetch climate, trying cache. Error: $e');
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      AppTracker.info('Using cached climate data from: ${prefs.getString('${cacheKey}_timestamp')}');
      return ClimateTrend.fromJson(jsonDecode(cached));
    }
    rethrow;
  }
}

/// Climate trends for the current farmer's location.
@riverpod
Future<ClimateTrend> currentClimateTrend(Ref ref) async {
  final farmer = await ref.watch(currentFarmerProvider.future);
  final lang = ref.watch(localeProvider)?.languageCode ?? 'en';
  return ref.watch(climateTrendProvider('${farmer.location}|$lang').future);
}
