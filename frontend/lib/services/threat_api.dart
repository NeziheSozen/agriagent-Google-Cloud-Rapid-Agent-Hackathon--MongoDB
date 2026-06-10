import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/regional_threats.dart';
import 'api_client.dart';

/// Service for regional threats API endpoints.
class ThreatApi {
  final ApiClient _client;

  ThreatApi(this._client);

  /// GET /regional-threats/{region}
  ///
  /// The backend accepts `region` as a path parameter and returns
  /// active threats from the last 30 days with an overall risk level.
  Future<RegionalThreats> getThreats({required String region}) {
    return _client.get(
      '/regional-threats/$region',
      parser: (data) =>
          RegionalThreats.fromJson(data as Map<String, dynamic>),
    );
  }
}

/// Riverpod provider for [ThreatApi].
final threatApiProvider = Provider<ThreatApi>((ref) {
  return ThreatApi(ref.read(apiClientProvider));
});
