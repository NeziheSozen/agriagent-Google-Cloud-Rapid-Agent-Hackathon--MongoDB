import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:http/http.dart' as http;
import '../utils/app_logger.dart';
import 'shared_prefs_provider.dart';

part 'offline_queue_provider.g.dart';

class PendingJob {
  final String id;
  final String endpoint;
  final String method;
  final Map<String, dynamic> payload;
  final DateTime timestamp;

  PendingJob({
    required this.id,
    required this.endpoint,
    required this.method,
    required this.payload,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'endpoint': endpoint,
        'method': method,
        'payload': payload,
        'timestamp': timestamp.toIso8601String(),
      };

  factory PendingJob.fromJson(Map<String, dynamic> json) => PendingJob(
        id: json['id'] as String,
        endpoint: json['endpoint'] as String,
        method: json['method'] as String,
        payload: json['payload'] as Map<String, dynamic>,
        timestamp: DateTime.parse(json['timestamp'] as String),
      );
}

@Riverpod(keepAlive: true)
class OfflineQueue extends _$OfflineQueue {
  static const _queueKey = 'offline_queue';
  bool _isSyncing = false;

  @override
  List<PendingJob> build() {
    _loadQueue();
    _listenConnectivity();
    return [];
  }

  void _loadQueue() {
    final prefs = ref.read(sharedPreferencesProvider);
    final data = prefs.getString(_queueKey);
    if (data != null) {
      try {
        final list = jsonDecode(data) as List;
        state = list.map((e) => PendingJob.fromJson(e as Map<String, dynamic>)).toList();
      } catch (e) {
        AppTracker.warn('Failed to parse offline queue: $e');
        state = [];
      }
    } else {
      state = [];
    }
  }

  void _saveQueue(List<PendingJob> queue) {
    final prefs = ref.read(sharedPreferencesProvider);
    prefs.setString(_queueKey, jsonEncode(queue.map((e) => e.toJson()).toList()));
    state = queue;
  }

  void addJob({
    required String endpoint,
    required String method,
    required Map<String, dynamic> payload,
  }) {
    final job = PendingJob(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      endpoint: endpoint,
      method: method,
      payload: payload,
      timestamp: DateTime.now(),
    );
    final current = List<PendingJob>.from(state);
    current.add(job);
    _saveQueue(current);
    AppTracker.info('Added offline job to queue: ${job.endpoint}');
    
    // Attempt sync just in case we are actually online
    syncQueue();
  }

  void removeJob(String id) {
    final current = List<PendingJob>.from(state);
    current.removeWhere((j) => j.id == id);
    _saveQueue(current);
  }

  void _listenConnectivity() {
    Connectivity().onConnectivityChanged.listen((List<ConnectivityResult> results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncQueue();
      }
    });
  }

  Future<void> syncQueue() async {
    if (_isSyncing || state.isEmpty) return;
    
    final results = await Connectivity().checkConnectivity();
    if (results.contains(ConnectivityResult.none)) return;

    _isSyncing = true;
    AppTracker.info('Starting background sync for ${state.length} jobs...');

    final currentQueue = List<PendingJob>.from(state);
    currentQueue.sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final job in currentQueue) {
      try {
        AppTracker.info('Syncing job: ${job.endpoint} (${job.method})');
        final url = Uri.parse(job.endpoint);
        http.Response response;

        if (job.method.toUpperCase() == 'POST') {
          response = await http.post(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(job.payload),
          );
        } else if (job.method.toUpperCase() == 'PUT') {
          response = await http.put(
            url,
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode(job.payload),
          );
        } else {
          throw Exception('Unsupported method: ${job.method}');
        }

        if (response.statusCode >= 200 && response.statusCode < 300) {
          // Success, remove from queue
          removeJob(job.id);
          AppTracker.info('Job ${job.id} synced successfully.');
        } else {
          AppTracker.warn('Job ${job.id} failed with status ${response.statusCode}: ${response.body}');
          // Depending on logic, we could keep it to retry or remove it if it's a permanent error (like 400).
          // For now, if it's a 4xx error (not auth/temp), we might want to drop it. 
          // But to be safe, we keep it in queue to retry later.
          break; // Stop syncing this batch if we hit an error, network might be flaky
        }
      } catch (e) {
        AppTracker.warn('Job ${job.id} sync exception: $e');
        break; // Stop syncing on network exception
      }
    }

    _isSyncing = false;
  }
}
