import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';

import '../models/regional_threats.dart';
import '../services/threat_api.dart';
import 'farmer_provider.dart';

import 'dart:convert';
import 'shared_prefs_provider.dart';

part 'threat_provider.g.dart';

/// Fetches regional threats for the given region.
@riverpod
Future<RegionalThreats> threat(Ref ref, String region) async {
  final api = ref.read(threatApiProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final cacheKey = 'cache_threat_$region';

  try {
    final data = await api.getThreats(region: region);
    // Cache it
    await prefs.setString(cacheKey, jsonEncode(data.toJson()));
    await prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
    return data;
  } catch (e) {
    AppTracker.warn('Failed to fetch threats, trying cache. Error: $e');
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      AppTracker.info('Using cached threat data from: ${prefs.getString('${cacheKey}_timestamp')}');
      return RegionalThreats.fromJson(jsonDecode(cached));
    }
    rethrow;
  }
}

/// Regional threats for the current farmer's region.
@riverpod
Future<RegionalThreats> currentThreats(Ref ref) async {
  final farmer = await ref.watch(currentFarmerProvider.future);
  return ref.watch(threatProvider(farmer.region).future);
}
