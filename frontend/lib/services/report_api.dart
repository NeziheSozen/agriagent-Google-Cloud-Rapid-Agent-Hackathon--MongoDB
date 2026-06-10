import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/strategy_report.dart';
import 'api_client.dart';

/// Service for strategy report API endpoints.
class ReportApi {
  final ApiClient _client;

  ReportApi(this._client);

  /// POST /save-strategy-report
  ///
  /// Persists an AI-generated strategy report to MongoDB.
  /// Returns the saved document with its generated `_id`.
  Future<Map<String, dynamic>> saveReport(StrategyReport report) {
    return _client.post(
      '/save-strategy-report',
      data: report.toJson(),
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  /// GET /reports/{userId}
  ///
  /// Retrieves all saved strategy reports for a farmer,
  /// ordered newest first.
  Future<List<StrategyReport>> listReports(String userId) {
    return _client.get(
      '/reports/$userId',
      parser: (data) => (data as List<dynamic>)
          .map((e) => StrategyReport.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }
}

/// Riverpod provider for [ReportApi].
final reportApiProvider = Provider<ReportApi>((ref) {
  return ReportApi(ref.read(apiClientProvider));
});
