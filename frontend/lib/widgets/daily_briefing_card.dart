import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../models/farmer_profile.dart';
import '../models/market_forecast.dart';
import '../app/l10n/translations.dart';
import '../utils/crop_translator.dart';
import '../utils/currency_formatter.dart';
import '../providers/market_provider.dart';
import '../providers/currency_provider.dart';
import '../widgets/glass_card.dart';

class DailyBriefingCard extends ConsumerWidget {
  final FarmerProfile farmer;

  const DailyBriefingCard({super.key, required this.farmer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final forecastAsync = ref.watch(marketForecastProvider);
    final locale = Localizations.localeOf(context).languageCode;
    final userCurrency = ref.watch(userCurrencyProvider);

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.analytics, color: AgriAgentTheme.infoBlue, size: 24),
              const SizedBox(width: 8),
              Text(
                L10n.tr(context, 'market_title') ?? "Günlük Piyasa ve Talep Özeti",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            L10n.tr(context, 'market_subtitle') ?? "Global ve bölgesel piyasalardaki güncel analizler:",
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 16),
          SizedBox(
            height: 140,
            child: forecastAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (err, stack) => Center(child: Text('${L10n.tr(context, 'radar_error') ?? "Veri çekilemedi:"} $err', style: const TextStyle(color: Colors.red))),
              data: (forecast) {
                if (forecast.predictions.isEmpty) {
                  return Center(child: Text(L10n.tr(context, 'market_no_data') ?? "Güncel piyasa verisi bulunamadı."));
                }
                return ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: forecast.predictions.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final p = forecast.predictions[index];
                    
                    final double trendPercent = p.price1YearAgoPerTon > 0 
                        ? ((p.priceTodayPerTon - p.price1YearAgoPerTon) / p.price1YearAgoPerTon) * 100
                        : 0;
                    final bool isRising = trendPercent > 0;
                    final bool isFalling = trendPercent < 0;
                    
                    return Container(
                      width: 240,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AgriAgentTheme.infoBlue.withOpacity(0.3)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(CropTranslator.translate(p.crop, locale: locale), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(
                                  color: isRising
                                      ? AgriAgentTheme.successGreen.withOpacity(0.1)
                                      : isFalling 
                                          ? Colors.redAccent.withOpacity(0.1)
                                          : Colors.grey.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  isRising ? (L10n.tr(context, 'trend_rising') ?? "Yükseliş") : (isFalling ? (L10n.tr(context, 'trend_falling') ?? "Düşüş") : (L10n.tr(context, 'trend_stable') ?? "Stabil")), 
                                  style: TextStyle(
                                    fontSize: 10, 
                                    color: isRising
                                        ? AgriAgentTheme.successGreen
                                        : isFalling 
                                            ? Colors.redAccent
                                            : Colors.grey
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const Spacer(),
                          Text("${L10n.tr(context, 'annual_change') ?? 'Yıllık Değişim'}: ${trendPercent >= 0 ? '+' : ''}${trendPercent.toStringAsFixed(1)}%", style: const TextStyle(fontSize: 13)),
                          const SizedBox(height: 4),
                          Text("${L10n.tr(context, 'price_label') ?? 'Fiyat'}: ${CurrencyFormatter.formatLocalPricePerTon(p.priceTodayPerTon, userCurrency)}", style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: AgriAgentTheme.mossGreen)),
                          const SizedBox(height: 8),
                          Text("${L10n.tr(context, 'last_year') ?? 'Geçen Yıl'}: ${CurrencyFormatter.formatLocalPricePerTon(p.price1YearAgoPerTon, userCurrency)}", style: const TextStyle(fontSize: 11, color: Colors.grey), maxLines: 1, overflow: TextOverflow.ellipsis),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.tr(context, 'market_snackbar') ?? "Genişletilmiş piyasa analizine gidiliyor...")),
                );
              },
              child: Text(L10n.tr(context, 'market_button') ?? "Tüm Talepleri ve Analizleri Gör"),
            ),
          ),
        ],
      ),
    );
  }
}
