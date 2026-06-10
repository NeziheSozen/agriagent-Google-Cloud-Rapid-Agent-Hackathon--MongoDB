import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';

import '../models/farmer_profile.dart';
import '../services/farmer_api.dart';
import 'shared_prefs_provider.dart';

part 'farmer_provider.g.dart';

/// Currently selected farmer user ID.
@Riverpod(keepAlive: true)
class SelectedFarmerId extends _$SelectedFarmerId {
  @override
  String build() => 'farmer_001';

  void set(String id) => state = id;
}

/// Fetches the farmer profile for a given user ID.
@riverpod
Future<FarmerProfile> farmerProfile(Ref ref, String userId) async {
  AppTracker.info('Provider build: farmer_provider.dart');

  if (userId == 'guest') {
    throw Exception('Please login or create a profile to view your farm data.');
  }
  
  final api = ref.read(farmerApiProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final cacheKey = 'cache_farmer_$userId';

  try {
    final data = await api.getProfile(userId);
    // Cache it
    await prefs.setString(cacheKey, jsonEncode(data.toJson()));
    await prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
    return data;
  } catch (e) {
    AppTracker.warn('Failed to fetch farmer profile, trying cache. Error: $e');
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      AppTracker.info('Using cached farmer profile from: ${prefs.getString('${cacheKey}_timestamp')}');
      return FarmerProfile.fromJson(jsonDecode(cached));
    }
    rethrow;
  }
}

/// Convenience provider that fetches the currently selected farmer.
@riverpod
Future<FarmerProfile> currentFarmer(Ref ref) async {
  final userId = ref.watch(selectedFarmerIdProvider);
  return ref.watch(farmerProfileProvider(userId).future);
}
