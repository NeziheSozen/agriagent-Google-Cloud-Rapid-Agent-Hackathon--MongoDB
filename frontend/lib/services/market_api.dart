import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/market_forecast.dart';
import 'api_client.dart';

/// Service for market forecast API endpoints.
class MarketApi {
  final ApiClient _client;

  MarketApi(this._client);

  /// POST /market-forecast
  Future<MarketForecast> getForecast(CropForecastRequest request) {
    return _client.post(
      '/market-forecast',
      data: request.toJson(),
      parser: (data) =>
          MarketForecast.fromJson(data as Map<String, dynamic>),
    );
  }
}

/// Riverpod provider for [MarketApi].
final marketApiProvider = Provider<MarketApi>((ref) {
  return MarketApi(ref.read(apiClientProvider));
});
