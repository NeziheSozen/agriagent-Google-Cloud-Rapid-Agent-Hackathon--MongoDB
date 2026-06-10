import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';

import '../app/theme.dart';
import '../models/market_forecast.dart';
import '../utils/crop_translator.dart';
import '../utils/crop_icon_service.dart';
import '../utils/crop_image_service.dart';
import '../app/l10n/translations.dart';
import '../utils/currency_formatter.dart';
import '../providers/currency_provider.dart';

/// Row widget showing a crop's price forecast information.
///
/// Displays crop name, current/predicted price, trend arrow,
/// volatility indicator, and confidence percentage.
class PriceRow extends ConsumerWidget {
  final CropPriceForecast forecast;
  final VoidCallback? onTap;

  const PriceRow({
    super.key,
    required this.forecast,
    this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final locale = Localizations.localeOf(context).languageCode;
    final userCurrency = ref.watch(userCurrencyProvider);
    
    // Determine overall trend vs last year just for icon color
    final double trendPercent = forecast.price1YearAgoPerTon > 0 
        ? ((forecast.priceTodayPerTon - forecast.price1YearAgoPerTon) / forecast.price1YearAgoPerTon) * 100
        : 0;
    
    final Color iconColor = trendPercent > 0 ? Colors.green : (trendPercent < 0 ? Colors.red : Colors.orange);

    // Get crop image URL from cache
    final imageUrl = CropImageService.getCachedImageUrl(forecast.crop);
    final hasImage = imageUrl != null && imageUrl.isNotEmpty;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: theme.cardTheme.color ?? theme.cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(color: theme.dividerColor.withOpacity(0.1)),
          ),
          child: Row(
            children: [
              // Crop icon and name
              Expanded(
                flex: 2,
                child: Row(
                  children: [
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: hasImage
                            ? Colors.transparent
                            : iconColor.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: hasImage
                          ? CachedNetworkImage(
                              imageUrl: imageUrl,
                              width: 48,
                              height: 48,
                              fit: BoxFit.cover,
                              httpHeaders: const {
                                'User-Agent': 'AgriAgent/2.0 (Agricultural Advisory App; contact@agriagent.app)'
                              },
                              placeholder: (context, url) => const Center(
                                child: CircularProgressIndicator(strokeWidth: 2),
                              ),
                              errorWidget: (context, url, error) => Center(
                                child: Icon(Icons.local_florist, color: iconColor),
                              ),
                            )
                          : Center(
                              child: Icon(Icons.local_florist, color: iconColor),
                            ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        CropTranslator.translate(forecast.crop, locale: locale),
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Price Grid
              Expanded(
                flex: 5,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildPriceColumn(context, L10n.tr(context, 'price_today') ?? 'Bugün', forecast.priceTodayPerTon, userCurrency, isBold: true),
                    _buildPriceColumn(context, L10n.tr(context, 'price_1w') ?? '1 Hft', forecast.price1WeekAgoPerTon, userCurrency),
                    _buildPriceColumn(context, L10n.tr(context, 'price_1m') ?? '1 Ay', forecast.price1MonthAgoPerTon, userCurrency),
                    _buildPriceColumn(context, L10n.tr(context, 'price_1y') ?? '1 Yıl', forecast.price1YearAgoPerTon, userCurrency),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceColumn(BuildContext context, String label, double usdPrice, String userCurrency, {bool isBold = false}) {
    final theme = Theme.of(context);
    final priceStr = usdPrice <= 0.0 ? (L10n.tr(context, 'price_failed') ?? "N/A") : CurrencyFormatter.formatLocalPricePerTon(usdPrice, userCurrency);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.4),
            fontSize: 10,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          priceStr,
          style: theme.textTheme.bodySmall?.copyWith(
            color: usdPrice <= 0.0 ? theme.colorScheme.error : theme.colorScheme.onSurface,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            fontSize: isBold ? 13 : 12,
          ),
        ),
      ],
    );
  }

  String _formatPrice(double value) {
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(1)}K/t';
    }
    return '${value.toStringAsFixed(0)}/t';
  }
}

/// Small colored dot indicating volatility level.
class _VolatilityDot extends StatelessWidget {
  final String volatility;

  const _VolatilityDot({required this.volatility});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color,
            boxShadow: [
              BoxShadow(color: color.withOpacity(0.4), blurRadius: 4),
            ],
          ),
        ),
        const SizedBox(width: 4),
        Text(
          volatility,
          style: TextStyle(fontSize: 10, color: color.withOpacity(0.8)),
        ),
      ],
    );
  }

  Color _color() {
    switch (volatility.toLowerCase()) {
      case 'low':
        return AgriAgentTheme.successGreen;
      case 'moderate':
      case 'medium':
        return AgriAgentTheme.harvestGold;
      case 'high':
        return AgriAgentTheme.warningOrange;
      case 'very high':
      case 'extreme':
        return AgriAgentTheme.errorRed;
      default:
        return Colors.grey;
    }
  }
}
