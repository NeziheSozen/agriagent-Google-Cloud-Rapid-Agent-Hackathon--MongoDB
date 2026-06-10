import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/l10n/translations.dart';

import '../app/responsive.dart';
import '../app/theme.dart';
import '../providers/market_provider.dart';
import '../providers/shared_prefs_provider.dart';
import '../utils/crop_image_service.dart';
import '../widgets/glass_card.dart';
import '../widgets/price_row.dart';
import '../widgets/shimmer_loading.dart';

/// Market forecast screen with crop price predictions.
class MarketScreen extends ConsumerStatefulWidget {
  const MarketScreen({super.key});

  @override
  ConsumerState<MarketScreen> createState() => _MarketScreenState();
}

class _MarketScreenState extends ConsumerState<MarketScreen> {
  bool _imagesFetched = false;

  @override
  Widget build(BuildContext context) {
    final forecastAsync = ref.watch(marketForecastProvider);
    final sortedAsync = ref.watch(sortedPredictionsProvider);
    final currentSort = ref.watch(marketSortProvider);

    return Scaffold(
      body: SafeArea(
        child: forecastAsync.when(
          loading: () => Padding(
            padding: context.responsivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                ShimmerLoading.box(width: 200, height: 28),
                const SizedBox(height: 24),
                ShimmerLoading.card(height: 60),
                const SizedBox(height: 12),
                ShimmerLoading.listSkeleton(count: 5, rowHeight: 72),
              ],
            ),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.monetization_on_outlined,
                    color: AgriAgentTheme.errorRed, size: 48),
                const SizedBox(height: 16),
                Text(L10n.tr(context, 'failed_to_load_market'),
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
                      ref.invalidate(marketForecastProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(L10n.tr(context, 'retry')),
                ),
              ],
            ),
          ),
          data: (forecast) {
            // Trigger image fetching once when data is available
            if (!_imagesFetched && forecast.predictions.isNotEmpty) {
              _imagesFetched = true;
              final prefs = ref.read(sharedPreferencesProvider);
              CropImageService.loadCache(prefs).then((_) {
                final cropNames = forecast.predictions.map((p) => p.crop).toList();
                CropImageService.fetchImages(cropNames, prefs).then((_) {
                  if (mounted) setState(() {}); // Rebuild with images
                });
              });
            }

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
                                  L10n.tr(context, 'market_data_title'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  L10n.tr(context, 'market_data_subtitle'),
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
                                ref.invalidate(marketForecastProvider),
                            icon: Icon(Icons.refresh_rounded,
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Data sources
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: forecast.dataSources.map((source) {
                          return Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: AgriAgentTheme.mossGreen
                                  .withOpacity(0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: AgriAgentTheme.mossGreen
                                    .withOpacity(0.2),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.source_rounded,
                                    size: 12,
                                    color: AgriAgentTheme.mossGreen
                                        .withOpacity(0.7)),
                                const SizedBox(width: 6),
                                Text(
                                  source,
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: AgriAgentTheme.mossGreen
                                        .withOpacity(0.8),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                      const SizedBox(height: 20),

                      // Search Bar
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
                        ),
                        child: TextField(
                          onChanged: (value) => ref.read(marketSearchProvider.notifier).set(value),
                          decoration: InputDecoration(
                            hintText: L10n.tr(context, 'search_crop'),
                            border: InputBorder.none,
                            icon: Icon(Icons.search, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Sort row
                      Row(
                        children: [
                          Text(
                            L10n.tr(context, 'price_list'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Expanded(
                            child: SingleChildScrollView(
                              scrollDirection: Axis.horizontal,
                              child: Row(
                                children: [
                                  _SortButton(
                                    label: L10n.tr(context, 'sort_crop'),
                                    isActive:
                                        currentSort == MarketSortCriteria.crop,
                                    onTap: () => ref
                                        .read(marketSortProvider.notifier)
                                        .set(MarketSortCriteria.crop),
                                  ),
                                  const SizedBox(width: 6),
                                  _SortButton(
                                    label: L10n.tr(context, 'sort_price'),
                                    isActive:
                                        currentSort == MarketSortCriteria.price,
                                    onTap: () => ref
                                        .read(marketSortProvider.notifier)
                                        .set(MarketSortCriteria.price),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                    ],
                  ),
                ),
              ),

              // Price list
              sortedAsync.when(
                loading: () => SliverPadding(
                  padding: context.responsivePadding,
                  sliver: SliverToBoxAdapter(
                    child: ShimmerLoading.listSkeleton(count: 4),
                  ),
                ),
                error: (e, _) => const SliverToBoxAdapter(
                    child: SizedBox.shrink()),
                data: (predictions) => SliverPadding(
                  padding: context.responsivePadding,
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        return TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(
                              milliseconds: 300 + index * 80),
                          curve: Curves.easeOutCubic,
                          builder: (context, value, child) {
                            return Opacity(
                              opacity: value,
                              child: Transform.translate(
                                offset:
                                    Offset(0, 16 * (1 - value)),
                                child: child,
                              ),
                            );
                          },
                          child: Padding(
                            padding:
                                const EdgeInsets.only(bottom: 10),
                            child: PriceRow(
                              forecast: predictions[index],
                            ),
                          ),
                        );
                      },
                      childCount: predictions.length,
                    ),
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          );
          },
        ),
      ),
    );
  }
}

class _SortButton extends StatelessWidget {
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _SortButton({
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: isActive
                ? AgriAgentTheme.mossGreen.withOpacity(0.15)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isActive
                  ? AgriAgentTheme.mossGreen.withOpacity(0.4)
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
              color: isActive
                  ? AgriAgentTheme.mossGreen
                  : Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
            ),
          ),
        ),
      ),
    );
  }
}
