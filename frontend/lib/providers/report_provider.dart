import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';

import '../models/strategy_report.dart';
import '../services/report_api.dart';
import 'farmer_provider.dart';

part 'report_provider.g.dart';

/// Previous reports list for the current farmer.
@riverpod
Future<List<StrategyReport>> previousReports(Ref ref) async {
  final userId = ref.watch(selectedFarmerIdProvider);
  final api = ref.read(reportApiProvider);
  return api.listReports(userId);
}

/// State for the report save operation.
@riverpod
Future<Map<String, dynamic>> saveReport(Ref ref, StrategyReport report) async {
  final api = ref.read(reportApiProvider);
  return api.saveReport(report);
}

/// Tracks whether a report is currently being saved.
@riverpod
class IsSavingReport extends _$IsSavingReport {
  @override
  bool build() => false;

  void set(bool value) => state = value;
}
