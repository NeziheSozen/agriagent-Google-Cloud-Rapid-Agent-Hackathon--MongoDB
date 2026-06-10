import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import '../app/l10n/translations.dart';
import '../app/theme.dart';

/// Data point for the trend chart.
class TrendDataPoint {
  final double x;
  final double y;
  final String? label;

  const TrendDataPoint({required this.x, required this.y, this.label});
}

/// Configurable fl_chart line chart for climate data visualization.
///
/// Supports gradient fills, touch tooltips, grid lines, and axis labels.
/// Can display rainfall, temperature, or any numeric trend data.
class TrendChart extends StatelessWidget {
  final List<TrendDataPoint> data;
  final String title;
  final String yAxisLabel;
  final Color lineColor;
  final Color? gradientTopColor;
  final Color? gradientBottomColor;
  final double? minY;
  final double? maxY;
  final bool showDots;
  final bool showGrid;
  final double height;
  final TrendDataPoint? forecastPoint;

  const TrendChart({
    super.key,
    required this.data,
    required this.title,
    this.yAxisLabel = '',
    this.lineColor = AgriAgentTheme.mossGreen,
    this.gradientTopColor,
    this.gradientBottomColor,
    this.minY,
    this.maxY,
    this.showDots = true,
    this.showGrid = true,
    this.height = 220,
    this.forecastPoint,
  });

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(child: Text(L10n.tr(context, 'no_data'))),
      );
    }

    final allPoints = [...data];
    if (forecastPoint != null) allPoints.add(forecastPoint!);

    final spots = allPoints
        .map((p) => FlSpot(p.x, p.y))
        .toList();

    final gradientTop =
        gradientTopColor ?? lineColor.withOpacity(0.3);
    final gradientBottom =
        gradientBottomColor ?? lineColor.withOpacity(0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title row
        Row(
          children: [
            Container(
              width: 4,
              height: 18,
              decoration: BoxDecoration(
                color: lineColor,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              title,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            if (yAxisLabel.isNotEmpty) ...[
              const SizedBox(width: 8),
              Text(
                '($yAxisLabel)',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                    ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 16),

        // Chart
        SizedBox(
          height: height,
          child: LineChart(
            LineChartData(
              gridData: FlGridData(
                show: showGrid,
                drawVerticalLine: false,
                horizontalInterval: _calculateInterval(spots),
                getDrawingHorizontalLine: (value) => FlLine(
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                  strokeWidth: 1,
                ),
              ),
              titlesData: FlTitlesData(
                topTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                rightTitles: const AxisTitles(
                    sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 30,
                    interval: 1,
                    getTitlesWidget: (value, meta) {
                      final point = allPoints.firstWhere(
                        (p) => p.x == value,
                        orElse: () =>
                            TrendDataPoint(x: value, y: 0),
                      );
                      final label = point.label ?? value.toInt().toString();
                      final isForecast =
                          forecastPoint != null && value == forecastPoint!.x;
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          label,
                          style: TextStyle(
                            fontSize: 11,
                            color: isForecast
                                ? AgriAgentTheme.harvestGold
                                : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontWeight: isForecast
                                ? FontWeight.w700
                                : FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 42,
                    interval: _calculateInterval(spots),
                    getTitlesWidget: (value, meta) {
                      return Text(
                        value.toStringAsFixed(0),
                        style: TextStyle(
                          fontSize: 10,
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.35),
                        ),
                      );
                    },
                  ),
                ),
              ),
              borderData: FlBorderData(show: false),
              minX: spots.first.x,
              maxX: spots.last.x,
              minY: minY ?? _autoMinY(spots),
              maxY: maxY ?? _autoMaxY(spots),
              lineTouchData: LineTouchData(
                touchTooltipData: LineTouchTooltipData(
                  getTooltipColor: (_) =>
                      Theme.of(context).cardColor,
                  tooltipRoundedRadius: 10,
                  tooltipBorder: BorderSide(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                  ),
                  getTooltipItems: (spots) {
                    return spots.map((spot) {
                      return LineTooltipItem(
                        '${spot.y.toStringAsFixed(1)}',
                        TextStyle(
                          color: lineColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      );
                    }).toList();
                  },
                ),
                handleBuiltInTouches: true,
              ),
              lineBarsData: [
                // Main data line
                LineChartBarData(
                  spots: data.map((p) => FlSpot(p.x, p.y)).toList(),
                  isCurved: true,
                  curveSmoothness: 0.3,
                  color: lineColor,
                  barWidth: 3,
                  isStrokeCapRound: true,
                  dotData: FlDotData(
                    show: showDots,
                    getDotPainter: (spot, percent, bar, index) {
                      return FlDotCirclePainter(
                        radius: 4,
                        color: lineColor,
                        strokeWidth: 2,
                        strokeColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                      );
                    },
                  ),
                  belowBarData: BarAreaData(
                    show: true,
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [gradientTop, gradientBottom],
                    ),
                  ),
                ),

                // Forecast dashed line (if present)
                if (forecastPoint != null && data.isNotEmpty)
                  LineChartBarData(
                    spots: [
                      FlSpot(data.last.x, data.last.y),
                      FlSpot(forecastPoint!.x, forecastPoint!.y),
                    ],
                    isCurved: false,
                    color: AgriAgentTheme.harvestGold,
                    barWidth: 2,
                    dashArray: [6, 4],
                    dotData: FlDotData(
                      show: true,
                      getDotPainter: (spot, percent, bar, index) {
                        if (index == 1) {
                          return FlDotCirclePainter(
                            radius: 5,
                            color: AgriAgentTheme.harvestGold,
                            strokeWidth: 2,
                            strokeColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.15),
                          );
                        }
                        return FlDotCirclePainter(
                          radius: 0,
                          color: Colors.transparent,
                          strokeWidth: 0,
                          strokeColor: Colors.transparent,
                        );
                      },
                    ),
                    belowBarData: BarAreaData(show: false),
                  ),
              ],
            ),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
          ),
        ),
      ],
    );
  }

  double _calculateInterval(List<FlSpot> spots) {
    if (spots.isEmpty) return 1;
    final values = spots.map((s) => s.y);
    final range = values.reduce((a, b) => a > b ? a : b) -
        values.reduce((a, b) => a < b ? a : b);
    if (range <= 0) return 1;
    if (range <= 10) return 2;
    if (range <= 50) return 10;
    if (range <= 200) return 50;
    return (range / 4).roundToDouble();
  }

  double _autoMinY(List<FlSpot> spots) {
    if (spots.isEmpty) return 0;
    final min = spots.map((s) => s.y).reduce((a, b) => a < b ? a : b);
    return (min - (min * 0.1)).floorToDouble();
  }

  double _autoMaxY(List<FlSpot> spots) {
    if (spots.isEmpty) return 100;
    final max = spots.map((s) => s.y).reduce((a, b) => a > b ? a : b);
    return (max + (max * 0.1)).ceilToDouble();
  }
}
