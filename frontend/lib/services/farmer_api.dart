import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import '../models/farmer_profile.dart';
import 'api_client.dart';

/// Service for farmer profile API endpoints.
class FarmerApi {
  final ApiClient _client;

  FarmerApi(this._client);

  /// GET /profile/{userId}
  Future<FarmerProfile> getProfile(String userId) {
    return _client.get(
      '/profile/$userId',
      parser: (data) => FarmerProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  /// POST /profile/login
  Future<FarmerProfile> login(String email) {
    return _client.post(
      '/profile/login',
      data: {'email': email},
      parser: (data) => FarmerProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  /// POST /profile/onboarding
  Future<FarmerProfile> createProfile(Map<String, dynamic> data) {
    return _client.post(
      '/profile/onboarding',
      data: data,
      parser: (json) => FarmerProfile.fromJson(json as Map<String, dynamic>),
    );
  }

  /// PUT /profile/{userId}
  Future<FarmerProfile> updateProfile(String userId, Map<String, dynamic> data) {
    return _client.put(
      '/profile/$userId',
      data: data,
      parser: (json) => FarmerProfile.fromJson(json as Map<String, dynamic>),
    );
  }

  /// PUT /profile/{userId}/plot/{plotIndex}
  Future<FarmerProfile> updatePlot(String userId, int plotIndex, Map<String, dynamic> data) {
    return _client.put(
      '/profile/$userId/plot/$plotIndex',
      data: data,
      parser: (json) => FarmerProfile.fromJson(json as Map<String, dynamic>),
    );
  }

  /// POST /profile/{userId}/plot/{plotIndex}/crop
  Future<FarmerProfile> addCropHistory(String userId, int plotIndex, Map<String, dynamic> data) {
    return _client.post(
      '/profile/$userId/plot/$plotIndex/crop',
      data: data,
      parser: (json) => FarmerProfile.fromJson(json as Map<String, dynamic>),
    );
  }

  /// POST /profile/{userId}/plot/{plotIndex}/upload-soil
  Future<FarmerProfile> uploadSoilReport(String userId, int plotIndex, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    return _client.post(
      '/profile/$userId/plot/$plotIndex/upload-soil',
      data: formData,
      parser: (data) => FarmerProfile.fromJson(data as Map<String, dynamic>),
    );
  }

  /// GET /cooperatives/nearby
  Future<List<Map<String, dynamic>>> getNearbyCooperatives(double lat, double lon) {
    return _client.get(
      '/coop/nearby?lat=$lat&lon=$lon&max_distance_km=50',
      parser: (data) => List<Map<String, dynamic>>.from(data as List),
    );
  }

  /// POST /sensor/{plotId}/sync-open-meteo
  Future<Map<String, dynamic>> syncOpenMeteoData(String plotId, double lat, double lon) {
    return _client.post(
      '/sensor/$plotId/sync-open-meteo?lat=$lat&lon=$lon',
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  /// GET /sensor/{plotId}/trend
  Future<List<Map<String, dynamic>>> getSensorTrend(String plotId) {
    return _client.get(
      '/sensor/$plotId/trend',
      parser: (data) => List<Map<String, dynamic>>.from(data as List),
    );
  }

  /// POST /sensor/{plotId}/scan-lcd
  Future<Map<String, dynamic>> scanLcdSensor(String plotId, String filePath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(filePath),
    });

    return _client.post(
      '/sensor/$plotId/scan-lcd',
      data: formData,
      parser: (data) => data as Map<String, dynamic>,
    );
  }
}

/// Riverpod provider for [FarmerApi].
final farmerApiProvider = Provider<FarmerApi>((ref) {
  return FarmerApi(ref.read(apiClientProvider));
});
