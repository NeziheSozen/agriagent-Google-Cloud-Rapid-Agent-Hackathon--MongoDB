import 'dart:math' as math;
import 'package:flutter/material.dart';

import '../app/theme.dart';

/// Circular risk gauge displaying a 0–10 score with color gradient.
///
/// Uses a custom painter to render a circular arc that transitions
/// from green (0) through yellow (5) to red (10).
class RiskGauge extends StatefulWidget {
  final double score;
  final double size;
  final String? label;
  final bool showLabel;

  const RiskGauge({
    super.key,
    required this.score,
    this.size = 100,
    this.label,
    this.showLabel = true,
  });

  @override
  State<RiskGauge> createState() => _RiskGaugeState();
}

class _RiskGaugeState extends State<RiskGauge>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _animation = Tween<double>(begin: 0, end: widget.score.clamp(0, 10))
        .animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void didUpdateWidget(covariant RiskGauge oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.score != widget.score) {
      _animation = Tween<double>(
        begin: _animation.value,
        end: widget.score.clamp(0, 10),
      ).animate(CurvedAnimation(
        parent: _controller,
        curve: Curves.easeOutCubic,
      ));
      _controller
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: widget.size,
              height: widget.size,
              child: CustomPaint(
                painter: _RiskGaugePainter(
                  score: _animation.value,
                  maxScore: 10,
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _animation.value.toStringAsFixed(1),
                        style: TextStyle(
                          fontSize: widget.size * 0.22,
                          fontWeight: FontWeight.w800,
                          color: _scoreColor(_animation.value),
                        ),
                      ),
                      Text(
                        '/10',
                        style: TextStyle(
                          fontSize: widget.size * 0.1,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (widget.showLabel && widget.label != null) ...[
              const SizedBox(height: 8),
              Text(
                widget.label!,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                    ),
                textAlign: TextAlign.center,
              ),
            ],
          ],
        );
      },
    );
  }

  Color _scoreColor(double score) {
    if (score <= 3) return AgriAgentTheme.successGreen;
    if (score <= 5) return AgriAgentTheme.harvestGold;
    if (score <= 7) return AgriAgentTheme.warningOrange;
    return AgriAgentTheme.errorRed;
  }
}

class _RiskGaugePainter extends CustomPainter {
  final double score;
  final double maxScore;

  _RiskGaugePainter({required this.score, required this.maxScore});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    const strokeWidth = 10.0;

    // Background arc
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.06)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    const startAngle = math.pi * 0.75; // 135 degrees
    const sweepAngle = math.pi * 1.5; // 270 degrees

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      bgPaint,
    );

    // Value arc with gradient
    if (score > 0) {
      final progress = (score / maxScore).clamp(0.0, 1.0);
      final valueSweep = sweepAngle * progress;

      final gradient = SweepGradient(
        startAngle: startAngle,
        endAngle: startAngle + sweepAngle,
        colors: const [
          AgriAgentTheme.successGreen,
          AgriAgentTheme.harvestGold,
          AgriAgentTheme.warningOrange,
          AgriAgentTheme.errorRed,
        ],
        stops: const [0.0, 0.35, 0.65, 1.0],
      );

      final valuePaint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round
        ..shader = gradient.createShader(
          Rect.fromCircle(center: center, radius: radius),
        );

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        valueSweep,
        false,
        valuePaint,
      );

      // Glow dot at tip
      final tipAngle = startAngle + valueSweep;
      final tipPos = Offset(
        center.dx + radius * math.cos(tipAngle),
        center.dy + radius * math.sin(tipAngle),
      );

      final glowColor = _colorForProgress(progress);

      canvas.drawCircle(
        tipPos,
        6,
        Paint()
          ..color = glowColor
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
      canvas.drawCircle(
        tipPos,
        4,
        Paint()..color = glowColor,
      );
      canvas.drawCircle(
        tipPos,
        2,
        Paint()..color = Colors.white,
      );
    }
  }

  Color _colorForProgress(double progress) {
    if (progress <= 0.3) return AgriAgentTheme.successGreen;
    if (progress <= 0.5) return AgriAgentTheme.harvestGold;
    if (progress <= 0.7) return AgriAgentTheme.warningOrange;
    return AgriAgentTheme.errorRed;
  }

  @override
  bool shouldRepaint(covariant _RiskGaugePainter oldDelegate) {
    return oldDelegate.score != score;
  }
}
