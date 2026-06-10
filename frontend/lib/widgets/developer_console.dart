import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../utils/app_logger.dart';
import '../app/l10n/translations.dart';

/// A developer tool to view live internal logs, intended to be used in debug mode.
class DeveloperConsole extends StatefulWidget {
  const DeveloperConsole({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const DeveloperConsole(),
    );
  }

  @override
  State<DeveloperConsole> createState() => _DeveloperConsoleState();
}

class _DeveloperConsoleState extends State<DeveloperConsole> {
  late StreamSubscription _sub;

  @override
  void initState() {
    super.initState();
    _sub = AppTracker.eventStream.listen((_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }

  Color _getColor(LogSeverity s) {
    switch (s) {
      case LogSeverity.error:
      case LogSeverity.wtf:
        return Colors.redAccent;
      case LogSeverity.warning:
        return Colors.orangeAccent;
      case LogSeverity.info:
        return Colors.lightBlueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 10)],
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Developer Console',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.delete_sweep, size: 20),
                      onPressed: AppTracker.clear,
                      tooltip: 'Clear',
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 20),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: AppTracker.history.join('\n')));
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text(L10n.tr(context, 'logs_copied'))),
                        );
                      },
                      tooltip: 'Copy All',
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 20),
                      onPressed: () => Navigator.pop(context),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Container(
              color: Colors.black, // Typical console background
              child: ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: AppTracker.history.length,
                itemBuilder: (context, i) {
                  final e = AppTracker.history[i];
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3.0),
                    child: SelectableText(
                      e.toString(),
                      style: TextStyle(
                        color: _getColor(e.severity),
                        fontFamily: 'monospace',
                        fontSize: 12,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
