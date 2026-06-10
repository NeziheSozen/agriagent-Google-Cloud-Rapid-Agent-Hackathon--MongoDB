import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:connectivity_plus/connectivity_plus.dart';
import '../models/cooperative_model.dart';
import 'farmer_provider.dart';
import 'offline_queue_provider.dart';

const _baseUrl =
    'https://agriagent-backend-385185579211.us-central1.run.app';

// ── Providers ──────────────────────────────────────────────────────────────

/// Get the current farmer's cooperative.
final myCooperativeProvider = FutureProvider<Cooperative?>((ref) async {
  final userId = ref.watch(selectedFarmerIdProvider);
  if (userId.isEmpty || userId == 'guest') return null;

  final url = Uri.parse('$_baseUrl/coop/my/$userId');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      final body = response.body;
      if (body.isEmpty || body == 'null') return null;
      final json = jsonDecode(body);
      if (json == null) return null;
      return Cooperative.fromJson(json as Map<String, dynamic>);
    }
  } catch (e) {
    // If offline, we just return null or cached version if we had one.
    // For now, returning null to avoid crash on load if offline.
    return null;
  }
  return null;
});

/// Shared machines in the cooperative.
final sharedMachinesProvider = FutureProvider<List<CoopMachine>>((ref) async {
  final coop = await ref.watch(myCooperativeProvider.future);
  if (coop == null) return [];
  return coop.machines.where((m) => m.shared).toList();
});

// ── API Functions ──────────────────────────────────────────────────────────

/// Creates a new cooperative / sharing network.
Future<Cooperative> createCooperative(
  WidgetRef ref, {
  required String name,
  required String region,
  required String description,
  required String coopType,
  required String adminId,
  required String adminName,
}) async {
  final url = '$_baseUrl/coop/create';
  final payload = {
    'name': name,
    'region': region,
    'description': description,
    'coop_type': coopType,
    'admin_id': adminId,
    'admin_name': adminName,
  };

  final conn = await Connectivity().checkConnectivity();
  if (conn.contains(ConnectivityResult.none)) {
    // Save to offline queue
    ref.read(offlineQueueProvider.notifier).addJob(
          endpoint: url,
          method: 'POST',
          payload: payload,
        );
    // Return a local pending Cooperative for optimistic UI
    return Cooperative(
      coopId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      name: name,
      region: region,
      description: description,
      coopType: coopType,
      memberIds: [adminId],
      machines: [],
      adminId: adminId,
      joinCode: 'PENDING',
      createdAt: DateTime.now(),
    );
  }

  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );
  if (response.statusCode == 200 || response.statusCode == 201) {
    return Cooperative.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
  throw Exception('Failed to create cooperative: ${response.body}');
}

/// Joins an existing cooperative using a join code.
Future<Cooperative> joinCooperative(
  WidgetRef ref, {
  required String joinCode,
  required String userId,
}) async {
  final url = '$_baseUrl/coop/join';
  final payload = {
    'join_code': joinCode,
    'user_id': userId,
  };

  final conn = await Connectivity().checkConnectivity();
  if (conn.contains(ConnectivityResult.none)) {
    ref.read(offlineQueueProvider.notifier).addJob(
          endpoint: url,
          method: 'POST',
          payload: payload,
        );
    return Cooperative(
      coopId: 'pending_${DateTime.now().millisecondsSinceEpoch}',
      name: 'Pending Join',
      region: '',
      description: 'Joining...',
      coopType: 'collective',
      memberIds: [userId],
      machines: [],
      adminId: '',
      joinCode: joinCode,
      createdAt: DateTime.now(),
    );
  }

  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );
  if (response.statusCode == 200 || response.statusCode == 201) {
    return Cooperative.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
  throw Exception('Failed to join cooperative: ${response.body}');
}

/// Adds a machine to a cooperative.
Future<CoopMachine> addMachine(
  WidgetRef ref, {
  required String coopId,
  required CoopMachine machine,
}) async {
  final url = '$_baseUrl/coop/machine';
  final payload = {
    'coop_id': coopId,
    ...machine.toJson(),
  };

  final conn = await Connectivity().checkConnectivity();
  if (conn.contains(ConnectivityResult.none)) {
    ref.read(offlineQueueProvider.notifier).addJob(
          endpoint: url,
          method: 'POST',
          payload: payload,
        );
    return machine; // Return the locally created machine as pending
  }

  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );
  if (response.statusCode == 200 || response.statusCode == 201) {
    return CoopMachine.fromJson(
        jsonDecode(response.body) as Map<String, dynamic>);
  }
  throw Exception('Failed to add machine: ${response.body}');
}

/// Toggles machine sharing status.
Future<void> toggleMachineSharing(
  WidgetRef ref, {
  required String coopId,
  required String machineId,
  required String ownerId,
  required bool shared,
}) async {
  final url = '$_baseUrl/coop/machine/toggle';
  final payload = {
    'coop_id': coopId,
    'machine_id': machineId,
    'owner_id': ownerId,
    'shared': shared,
  };

  final conn = await Connectivity().checkConnectivity();
  if (conn.contains(ConnectivityResult.none)) {
    ref.read(offlineQueueProvider.notifier).addJob(
          endpoint: url,
          method: 'PUT',
          payload: payload,
        );
    return;
  }

  final response = await http.put(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );
  if (response.statusCode != 200) {
    throw Exception('Failed to toggle machine sharing: ${response.body}');
  }
}

/// Books a shared machine for a given date.
Future<void> bookMachine(
  WidgetRef ref, {
  required String machineId,
  required String farmerName,
  required String date,
  required String coopId,
}) async {
  final url = '$_baseUrl/fleet/book';
  final payload = {
    'machine_id': machineId,
    'farmer_name': farmerName,
    'date': date,
    'coop_id': coopId,
  };

  final conn = await Connectivity().checkConnectivity();
  if (conn.contains(ConnectivityResult.none)) {
    ref.read(offlineQueueProvider.notifier).addJob(
          endpoint: url,
          method: 'POST',
          payload: payload,
        );
    return;
  }

  final response = await http.post(
    Uri.parse(url),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(payload),
  );
  if (response.statusCode != 200 && response.statusCode != 201) {
    throw Exception('Failed to book machine: ${response.body}');
  }
}
