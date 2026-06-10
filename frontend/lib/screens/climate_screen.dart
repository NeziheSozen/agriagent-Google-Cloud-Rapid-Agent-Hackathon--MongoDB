import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/l10n/translations.dart';

import '../app/responsive.dart';
import '../app/theme.dart';
import '../providers/climate_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/trend_chart.dart';
import '../widgets/threat_badge.dart';
import '../widgets/shimmer_loading.dart';

/// Climate trends screen showing historical data and forecasts.
class ClimateScreen extends ConsumerWidget {
  const ClimateScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final climateAsync = ref.watch(currentClimateTrendProvider);

    return Scaffold(
      body: SafeArea(
        child: climateAsync.when(
          loading: () => Padding(
            padding: context.responsivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                ShimmerLoading.box(width: 200, height: 28),
                const SizedBox(height: 24),
                ShimmerLoading.chartSkeleton(),
                const SizedBox(height: 16),
                ShimmerLoading.chartSkeleton(),
              ],
            ),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.cloud_off_rounded,
                    color: AgriAgentTheme.errorRed, size: 48),
                const SizedBox(height: 16),
                Text(L10n.tr(context, 'failed_to_load_climate'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('$error',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () =>
                      ref.invalidate(currentClimateTrendProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(L10n.tr(context, 'retry')),
                ),
              ],
            ),
          ),
          data: (climate) {
            // Build chart data
            final rainfallData = climate.historical
                .map((h) => TrendDataPoint(
                      x: h.year.toDouble(),
                      y: h.avgSpringRainfallMm,
                      label: h.year.toString(),
                    ))
                .toList();

            final tempData = climate.historical
                .map((h) => TrendDataPoint(
                      x: h.year.toDouble(),
                      y: h.avgSummerTempCelsius,
                      label: h.year.toString(),
                    ))
                .toList();

            final forecastYear = climate.historical.isNotEmpty
                ? climate.historical.last.year + 1
                : DateTime.now().year + 1;

            final rainfallForecast = TrendDataPoint(
              x: forecastYear.toDouble(),
              y: climate.forecast.predictedRainfallMm,
              label: '$forecastYear (${L10n.tr(context, 'forecast_abbr')})',
            );

            final tempForecast = TrendDataPoint(
              x: forecastYear.toDouble(),
              y: climate.forecast.predictedAvgTempCelsius,
              label: '$forecastYear (${L10n.tr(context, 'forecast_abbr')})',
            );

            return CustomScrollView(
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: context.responsivePadding,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    L10n.tr(context, 'climate_trends'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .headlineMedium
                                        ?.copyWith(
                                            fontWeight: FontWeight.w700),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${climate.location}, ${climate.region}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              onPressed: () =>
                                  ref.invalidate(currentClimateTrendProvider),
                              icon: Icon(Icons.refresh_rounded,
                                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
                ),

                SliverPadding(
                  padding: context.responsivePadding,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Rainfall chart
                      GlassCard(
                        child: TrendChart(
                          data: rainfallData,
                          title: L10n.tr(context, 'spring_rainfall'),
                          yAxisLabel: 'mm',
                          lineColor: AgriAgentTheme.infoBlue,
                          forecastPoint: rainfallForecast,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Temperature chart
                      GlassCard(
                        child: TrendChart(
                          data: tempData,
                          title: L10n.tr(context, 'summer_temperature'),
                          yAxisLabel: '°C',
                          lineColor: AgriAgentTheme.warningOrange,
                          gradientTopColor:
                              AgriAgentTheme.warningOrange.withOpacity(0.2),
                          forecastPoint: tempForecast,
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Drought & frost metrics
                      _buildDroughtFrostRow(context, climate),
                      const SizedBox(height: 16),

                      // Forecast card
                      _ForecastCard(forecast: climate.forecast),
                      const SizedBox(height: 16),

                      // Analysis notes
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(Icons.notes_rounded,
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), size: 20),
                                const SizedBox(width: 8),
                                Text(
                                  L10n.tr(context, 'analysis_notes'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            Text(
                              climate.analysisNotes,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                                    height: 1.6,
                                  ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                    ]),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _buildDroughtFrostRow(BuildContext context, dynamic climate) {
    final historical = climate.historical;
    if (historical.isEmpty) return const SizedBox.shrink();

    final isWide = !context.isMobile;

    final droughtCard = GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.wb_sunny_rounded,
                  color: AgriAgentTheme.warningOrange, size: 20),
              const SizedBox(width: 8),
              Text(
                L10n.tr(context, 'drought_days'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...historical.map<Widget>((h) {
            final maxDrought = 60;
            final ratio = (h.droughtDays / maxDrought).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text('${h.year}',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation(
                          Color.lerp(AgriAgentTheme.successGreen,
                              AgriAgentTheme.errorRed, ratio)!,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${h.droughtDays}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color.lerp(AgriAgentTheme.successGreen,
                            AgriAgentTheme.errorRed, ratio),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    final frostCard = GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.ac_unit_rounded,
                  color: AgriAgentTheme.infoBlue, size: 20),
              const SizedBox(width: 8),
              Text(
                L10n.tr(context, 'frost_days'),
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...historical.map<Widget>((h) {
            final maxFrost = 30;
            final ratio = (h.frostDays / maxFrost).clamp(0.0, 1.0);
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  SizedBox(
                    width: 40,
                    child: Text('${h.year}',
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: ratio,
                        minHeight: 8,
                        backgroundColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.08),
                        valueColor: AlwaysStoppedAnimation(
                          Color.lerp(AgriAgentTheme.successGreen,
                              AgriAgentTheme.infoBlue, ratio)!,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  SizedBox(
                    width: 30,
                    child: Text(
                      '${h.frostDays}',
                      textAlign: TextAlign.end,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color.lerp(AgriAgentTheme.successGreen,
                            AgriAgentTheme.infoBlue, ratio),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: droughtCard),
          const SizedBox(width: 16),
          Expanded(child: frostCard),
        ],
      );
    }

    return Column(
      children: [
        droughtCard,
        const SizedBox(height: 16),
        frostCard,
      ],
    );
  }
}

class _ForecastCard extends StatelessWidget {
  final dynamic forecast;

  const _ForecastCard({required this.forecast});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      showGradientBorder: true,
      accentColor: AgriAgentTheme.harvestGold,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: AgriAgentTheme.goldGradient,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.auto_awesome_rounded,
                    color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.tr(context, 'season_forecast'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  Text(
                    forecast.season,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                            color: AgriAgentTheme.harvestGold,
                            fontSize: 12),
                  ),
                ],
              ),
              const Spacer(),
              ThreatBadge(
                severity: forecast.droughtRisk,
                label: '${L10n.tr(context, 'drought')}: ${L10n.trSeverity(context, forecast.droughtRisk)}',
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _ForecastMetric(
                icon: Icons.water_drop_rounded,
                label: L10n.tr(context, 'predicted_rainfall'),
                value:
                    '${forecast.predictedRainfallMm.toStringAsFixed(0)} mm',
                color: AgriAgentTheme.infoBlue,
              ),
              const SizedBox(width: 24),
              _ForecastMetric(
                icon: Icons.thermostat_rounded,
                label: L10n.tr(context, 'avg_temperature'),
                value:
                    '${forecast.predictedAvgTempCelsius.toStringAsFixed(1)}°C',
                color: AgriAgentTheme.warningOrange,
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.lightbulb_outline_rounded,
                    color: AgriAgentTheme.harvestGold, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    forecast.trendSummary,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                          height: 1.5,
                        ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ForecastMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  const _ForecastMetric({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color.withOpacity(0.7)),
            const SizedBox(width: 4),
            Text(
              label,
              style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}
