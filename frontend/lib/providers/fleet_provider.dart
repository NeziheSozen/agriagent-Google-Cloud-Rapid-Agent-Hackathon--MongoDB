import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';
import 'package:http/http.dart' as http;

import '../models/fleet_schedule.dart';
import 'farmer_provider.dart';

part 'fleet_provider.g.dart';

/// Fetches fleet schedule for the current farmer's cooperative.
@riverpod
Future<FleetSchedule?> fleet(Ref ref) async {
  final farmer = await ref.watch(currentFarmerProvider.future);

  // No cooperative means no fleet schedule
  if (farmer.cooperativeId == null || farmer.cooperativeId!.isEmpty) {
    return null;
  }

  final url = Uri.parse(
    'https://agriagent-backend-385185579211.us-central1.run.app/fleet/schedule'
    '?coop_id=${Uri.encodeComponent(farmer.cooperativeId!)}'
    '&farmer_name=${Uri.encodeComponent(farmer.name)}',
  );
  final response = await http.get(url);

  if (response.statusCode == 200) {
    return FleetSchedule.fromJson(json.decode(response.body));
  } else {
    throw Exception('Failed to load fleet schedule');
  }
}
