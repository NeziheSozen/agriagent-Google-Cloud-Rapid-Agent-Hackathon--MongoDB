import 'package:flutter/material.dart';

import '../app/l10n/translations.dart';
import '../app/theme.dart';

/// Severity badge / chip showing threat severity level.
///
/// Color-coded: Low=green, Medium=amber, High=orange, Critical=red.
/// Critical severity gets a subtle pulse animation.
class ThreatBadge extends StatefulWidget {
  final String severity;
  final String? label;
  final bool compact;

  const ThreatBadge({
    super.key,
    required this.severity,
    this.label,
    this.compact = false,
  });

  @override
  State<ThreatBadge> createState() => _ThreatBadgeState();
}

class _ThreatBadgeState extends State<ThreatBadge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.08).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.severity.toLowerCase() == 'critical') {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant ThreatBadge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.severity.toLowerCase() == 'critical') {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      _pulseController.stop();
      _pulseController.reset();
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = AgriAgentTheme.severityColor(widget.severity);
    final text = widget.label ?? L10n.trSeverity(context, widget.severity);
    final isCritical = widget.severity.toLowerCase() == 'critical';

    final icon = _severityIcon(widget.severity);

    Widget badge = Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.compact ? 8 : 12,
        vertical: widget.compact ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.4)),
        boxShadow: isCritical
            ? [
                BoxShadow(
                  color: color.withOpacity(0.2),
                  blurRadius: 8,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: widget.compact ? 12 : 14, color: color),
          SizedBox(width: widget.compact ? 4 : 6),
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontSize: widget.compact ? 10 : 11,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );

    if (isCritical) {
      badge = ScaleTransition(scale: _pulseAnimation, child: badge);
    }

    return badge;
  }

  IconData _severityIcon(String severity) {
    switch (severity.toLowerCase()) {
      case 'low':
        return Icons.info_outline_rounded;
      case 'medium':
        return Icons.warning_amber_rounded;
      case 'high':
        return Icons.error_outline_rounded;
      case 'critical':
        return Icons.dangerous_rounded;
      default:
        return Icons.help_outline_rounded;
    }
  }
}

/// A type badge for threat categories (pest, disease, weather, etc.)
class ThreatTypeBadge extends StatelessWidget {
  final String type;

  const ThreatTypeBadge({super.key, required this.type});

  @override
  Widget build(BuildContext context) {
    final color = _typeColor(type);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_typeIcon(type), size: 13, color: color),
          const SizedBox(width: 4),
          Text(
            L10n.trThreatType(context, type),
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Color _typeColor(String type) {
    switch (type.toLowerCase()) {
      case 'pest':
        return const Color(0xFFEF5350);
      case 'disease':
        return const Color(0xFFAB47BC);
      case 'weather':
        return const Color(0xFF42A5F5);
      case 'invasive_species':
        return const Color(0xFFFF7043);
      default:
        return Colors.grey;
    }
  }

  IconData _typeIcon(String type) {
    switch (type.toLowerCase()) {
      case 'pest':
        return Icons.bug_report_rounded;
      case 'disease':
        return Icons.coronavirus_rounded;
      case 'weather':
        return Icons.thunderstorm_rounded;
      case 'invasive_species':
        return Icons.pest_control_rounded;
      default:
        return Icons.warning_rounded;
    }
  }
}
