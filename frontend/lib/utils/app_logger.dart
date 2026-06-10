import 'dart:async';
import 'package:flutter/foundation.dart';

enum LogSeverity { info, warning, error, wtf }

class AppLogEvent {
  final DateTime timestamp;
  final LogSeverity severity;
  final String message;

  AppLogEvent(this.severity, this.message) : timestamp = DateTime.now();

  @override
  String toString() {
    return '[${severity.name.toUpperCase()}] ${timestamp.toIso8601String().substring(11, 19)}: $message';
  }
}

/// A lightweight, custom logging system for monitoring app activity.
/// Used internally instead of relying on external packages.
class AppTracker {
  static final List<AppLogEvent> _history = [];
  static final StreamController<AppLogEvent> _eventController = StreamController.broadcast();

  static Stream<AppLogEvent> get eventStream => _eventController.stream;
  static List<AppLogEvent> get history => List.unmodifiable(_history);

  static void info(String msg) => _track(LogSeverity.info, msg);
  static void warn(String msg) => _track(LogSeverity.warning, msg);
  static void error(String msg) => _track(LogSeverity.error, msg);
  static void wtf(String msg) => _track(LogSeverity.wtf, msg);

  static void _track(LogSeverity severity, String message) {
    final event = AppLogEvent(severity, message);
    _history.add(event);
    _eventController.add(event);
    if (kDebugMode) {
      print(event.toString());
    }
  }

  static void clear() {
    _history.clear();
    _eventController.add(AppLogEvent(LogSeverity.info, '--- Tracker Cleared ---'));
  }
}
