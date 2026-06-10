import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/climate_trend.dart';
import 'api_client.dart';

/// Service for climate trend API endpoints.
class ClimateApi {
  final ApiClient _client;

  ClimateApi(this._client);

  /// GET /climate-trend/{location}?lang={lang}
  ///
  /// The backend accepts `location` as a path parameter and
  /// optional `lang` query parameter for localized text.
  Future<ClimateTrend> getTrends({required String location, String lang = 'en'}) {
    return _client.get(
      '/climate-trend/$location?lang=$lang',
      parser: (data) => ClimateTrend.fromJson(data as Map<String, dynamic>),
    );
  }
}

/// Riverpod provider for [ClimateApi].
final climateApiProvider = Provider<ClimateApi>((ref) {
  return ClimateApi(ref.read(apiClientProvider));
});
