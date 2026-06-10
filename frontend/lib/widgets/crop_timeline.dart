import 'package:flutter/material.dart';

import '../app/l10n/translations.dart';
import '../app/theme.dart';
import '../models/farmer_profile.dart';

/// Horizontal 5-year crop rotation timeline.
///
/// Displays connected circles for each year, colored by crop type.
/// Highlights the current year and flags rotation violations
/// (consecutive same-type crops) with a red border.
class CropTimeline extends StatelessWidget {
  final List<CropHistoryEntry> history;
  final bool compact;

  const CropTimeline({
    super.key,
    required this.history,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) {
      return Center(
        child: Text(
          L10n.tr(context, 'no_crop_history'),
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    final sorted = List<CropHistoryEntry>.from(history)
      ..sort((a, b) => a.year.compareTo(b.year));

    final currentYear = DateTime.now().year;
    final circleSize = compact ? 36.0 : 48.0;
    final fontSize = compact ? 10.0 : 12.0;

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(sorted.length * 2 - 1, (index) {
          // Odd indices are connectors
          if (index.isOdd) {
            return Container(
              width: compact ? 20 : 32,
              height: 3,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AgriAgentTheme.cropTypeColor(sorted[index ~/ 2].crop),
                    AgriAgentTheme.cropTypeColor(sorted[index ~/ 2 + 1].crop),
                  ],
                ),
                borderRadius: BorderRadius.circular(2),
              ),
            );
          }

          final entry = sorted[index ~/ 2];
          final color = AgriAgentTheme.cropTypeColor(entry.crop);
          final isCurrent = entry.year == currentYear;

          // Check rotation violation (same crop type as previous)
          final entryIndex = index ~/ 2;
          final hasViolation = entryIndex > 0 &&
              _sameType(sorted[entryIndex - 1].crop, entry.crop);

          return Tooltip(
            message:
                '${entry.year}: ${entry.crop}\n'
                'Yield: ${entry.yieldTonsPerHectare.toStringAsFixed(1)} t/ha\n'
                'Profit: ₺${_formatNumber(entry.profit)}',
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 400),
              curve: Curves.easeOutBack,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Year label
                  Text(
                    entry.year.toString(),
                    style: TextStyle(
                      fontSize: fontSize,
                      fontWeight:
                          isCurrent ? FontWeight.w700 : FontWeight.w500,
                      color: isCurrent
                          ? AgriAgentTheme.mossGreen
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Circle
                  Container(
                    width: circleSize,
                    height: circleSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: color.withOpacity(isCurrent ? 0.3 : 0.15),
                      border: Border.all(
                        color: hasViolation
                            ? AgriAgentTheme.errorRed
                            : (isCurrent ? color : color.withOpacity(0.5)),
                        width: hasViolation
                            ? 3
                            : (isCurrent ? 2.5 : 1.5),
                      ),
                      boxShadow: isCurrent
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 12,
                                spreadRadius: 2,
                              ),
                            ]
                          : null,
                    ),
                    child: Center(
                      child: Text(
                        entry.crop.substring(0, entry.crop.length.clamp(0, 3)).toUpperCase(),
                        style: TextStyle(
                          fontSize: fontSize - 1,
                          fontWeight: FontWeight.w700,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Crop name
                  SizedBox(
                    width: circleSize + 16,
                    child: Text(
                      entry.crop,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: fontSize - 1,
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                        fontWeight: FontWeight.w500,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),

                  // Violation indicator
                  if (hasViolation) ...[
                    const SizedBox(height: 2),
                    Icon(
                      Icons.warning_amber_rounded,
                      size: compact ? 12 : 14,
                      color: AgriAgentTheme.errorRed,
                    ),
                  ],
                ],
              ),
            ),
          );
        }),
      ),
    );
  }

  /// Very simple same-type check (checks crop category).
  bool _sameType(String cropA, String cropB) {
    return _cropCategory(cropA) == _cropCategory(cropB);
  }

  String _cropCategory(String crop) {
    final lower = crop.toLowerCase();
    if (['wheat', 'barley', 'corn', 'maize', 'rice', 'oat', 'rye']
        .any((c) => lower.contains(c))) return 'cereal';
    if (['chickpea', 'lentil', 'bean', 'pea', 'soybean']
        .any((c) => lower.contains(c))) return 'legume';
    if (['sunflower', 'canola', 'rapeseed', 'sesame', 'olive']
        .any((c) => lower.contains(c))) return 'oilseed';
    if (['tomato', 'pepper', 'cucumber', 'lettuce', 'onion', 'potato']
        .any((c) => lower.contains(c))) return 'vegetable';
    if (['cotton', 'sugar beet', 'tobacco', 'hemp']
        .any((c) => lower.contains(c))) return 'industrial';
    return 'other';
  }

  String _formatNumber(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}
