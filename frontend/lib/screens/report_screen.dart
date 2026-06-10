import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/l10n/translations.dart';

import '../app/responsive.dart';
import '../app/theme.dart';
import '../models/strategy_report.dart';
import '../providers/report_provider.dart';
import '../services/report_api.dart';
import '../providers/farmer_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/risk_gauge.dart';
import '../widgets/shimmer_loading.dart';
import '../services/agent_api.dart';

/// Strategy report screen — the crown jewel of AgriAgent.
///
/// Shows AI-generated crop recommendations with detailed analysis
/// sections, financials, risk gauges, and a prominent final recommendation.
class ReportScreen extends ConsumerStatefulWidget {
  const ReportScreen({super.key});

  @override
  ConsumerState<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends ConsumerState<ReportScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  bool _isSaving = false;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(previousReportsProvider);

    return Scaffold(
      body: SafeArea(
        child: reportsAsync.when(
          loading: () => _buildLoadingState(context),
          error: (error, _) => _buildErrorState(context, error),
          data: (reports) {
            if (_isGenerating) {
              return _buildLoadingState(context);
            }
            if (reports.isEmpty) {
              return _buildEmptyState(context);
            }
            return _buildReportContent(context, reports.first);
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: GlassCard(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.description_outlined,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25), size: 64),
            const SizedBox(height: 16),
            Text(
              L10n.tr(context, 'no_reports'),
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.tr(context, 'no_reports_desc'),
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), height: 1.5),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _generateReport,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(L10n.tr(context, 'generate_report')),
              style: ElevatedButton.styleFrom(
                backgroundColor: AgriAgentTheme.mossGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLoadingState(BuildContext context) {
    return Center(
      child: Padding(
        padding: context.responsivePadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Animated loading indicator
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: const Duration(milliseconds: 800),
              builder: (context, value, child) {
                return Opacity(opacity: value, child: child);
              },
              child: Column(
                children: [
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: AgriAgentTheme.primaryGradient,
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color:
                              AgriAgentTheme.mossGreen.withOpacity(0.3),
                          blurRadius: 24,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: const Center(
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 3,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    L10n.tr(context, 'generating_report'),
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    L10n.tr(context, 'ai_analyzing'),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4), height: 1.5),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
            SizedBox(
              width: 300,
              child: Column(
                children: [
                  ShimmerLoading.card(height: 60),
                  ShimmerLoading.card(height: 60),
                  ShimmerLoading.card(height: 60),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: GlassCard(
          accentColor: AgriAgentTheme.errorRed,
          showGradientBorder: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AgriAgentTheme.errorRed, size: 56),
              const SizedBox(height: 20),
              Text(
                L10n.tr(context, 'report_failed'),
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 8),
              Text(
                '$error',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () =>
                    ref.invalidate(previousReportsProvider),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: Text(L10n.tr(context, 'try_again')),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportContent(BuildContext context, StrategyReport report) {
    return CustomScrollView(
      slivers: [
        // Header
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
                            L10n.tr(context, 'strategy_report'),
                            style: Theme.of(context)
                                .textTheme
                                .headlineMedium
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${report.season} · ${report.createdAt}',
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                          ),
                        ],
                      ),
                    ),
                    // Save button
                    _SaveButton(
                      isSaving: _isSaving,
                      onSave: () => _saveReport(report),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Farm summary
                GlassCard(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: AgriAgentTheme.primaryGradient,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.summarize_rounded,
                            color: Colors.white, size: 22),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              L10n.tr(context, 'farm_summary'),
                              style: Theme.of(context)
                                  .textTheme
                                  .titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w600),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              report.farmSummary,
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
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Analysis tabs
                Container(
                  decoration: BoxDecoration(
                    color: Theme.of(context).cardColor,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                    ),
                  ),
                  child: TabBar(
                    controller: _tabController,
                    isScrollable: true,
                    tabs: [
                      Tab(text: L10n.tr(context, 'rotation_tab')),
                      Tab(text: L10n.tr(context, 'climate_tab')),
                      Tab(text: L10n.tr(context, 'threats_tab')),
                      Tab(text: L10n.tr(context, 'market_tab')),
                      Tab(text: L10n.tr(context, 'sustainability_tab')),
                      Tab(text: L10n.tr(context, 'insurance_tab')),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
              ],
            ),
          ),
        ),

        // Tab content
        SliverToBoxAdapter(
          child: Padding(
            padding: context.responsivePadding,
            child: AnimatedBuilder(
              animation: _tabController,
              builder: (context, _) {
                Widget child;
                switch (_tabController.index) {
                  case 0:
                    child = _AnalysisCard(
                      key: const ValueKey(0),
                      icon: Icons.rotate_right_rounded,
                      color: AgriAgentTheme.harvestGold,
                      title: L10n.tr(context, 'rotation_analysis'),
                      content: report.rotationAnalysis,
                    );
                    break;
                  case 1:
                    child = _AnalysisCard(
                      key: const ValueKey(1),
                      icon: Icons.thermostat_rounded,
                      color: AgriAgentTheme.infoBlue,
                      title: L10n.tr(context, 'climate_assessment'),
                      content: report.climateAssessment,
                    );
                    break;
                  case 2:
                    child = _AnalysisCard(
                      key: const ValueKey(2),
                      icon: Icons.warning_amber_rounded,
                      color: AgriAgentTheme.warningOrange,
                      title: L10n.tr(context, 'threat_assessment'),
                      content: report.threatAssessment,
                    );
                    break;
                  case 3:
                    child = _AnalysisCard(
                      key: const ValueKey(3),
                      icon: Icons.trending_up_rounded,
                      color: AgriAgentTheme.mossGreen,
                      title: L10n.tr(context, 'market_outlook'),
                      content: report.marketOutlook,
                    );
                    break;
                  case 4:
                    child = _AnalysisCard(
                      key: const ValueKey(4),
                      icon: Icons.eco_rounded,
                      color: AgriAgentTheme.mossGreen,
                      title: L10n.tr(context, 'sustainability_analysis'),
                      content: report.sustainabilityAnalysis.isEmpty
                          ? L10n.tr(context, 'not_available')
                          : report.sustainabilityAnalysis,
                    );
                    break;
                  case 5:
                    child = _AnalysisCard(
                      key: const ValueKey(5),
                      icon: Icons.shield_rounded,
                      color: AgriAgentTheme.infoBlue,
                      title: L10n.tr(context, 'insurance_analysis'),
                      content: report.insuranceRecommendations.isEmpty
                          ? L10n.tr(context, 'not_available')
                          : report.insuranceRecommendations,
                    );
                    break;
                  default:
                    child = const SizedBox.shrink();
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: child,
                );
              },
            ),
          ),
        ),

        // Recommendations header
        SliverToBoxAdapter(
          child: Padding(
            padding: context.responsivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 8),
                Row(
                  children: [
                    Container(
                      width: 4,
                      height: 20,
                      decoration: BoxDecoration(
                        color: AgriAgentTheme.mossGreen,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      L10n.tr(context, 'crop_recommendations'),
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),

        // Recommendation cards
        SliverPadding(
          padding: context.responsivePadding,
          sliver: context.isDesktop
              ? _buildDesktopRecommendations(report.recommendations, report.currencySymbol)
              : _buildMobileRecommendations(report.recommendations, report.currencySymbol),
        ),

        // Final recommendation
        SliverToBoxAdapter(
          child: Padding(
            padding: context.responsivePadding,
            child: Column(
              children: [
                const SizedBox(height: 16),
                _FinalRecommendationCard(
                  recommendation: report.finalRecommendation,
                ),
                const SizedBox(height: 16),

                // Regenerate button
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _generateReport,
                    icon: const Icon(Icons.auto_awesome_rounded,
                        size: 18),
                    label: Text(L10n.tr(context, 'regenerate_report')),
                  ),
                ),
                const SizedBox(height: 32),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDesktopRecommendations(List<CropOption> recs, String currencySymbol) {
    return SliverToBoxAdapter(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: recs.map((rec) {
          return Expanded(
            child: Padding(
              padding: EdgeInsets.only(
                  right: rec == recs.last ? 0 : 12),
              child: _RecommendationCard(option: rec, currencySymbol: currencySymbol),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildMobileRecommendations(List<CropOption> recs, String currencySymbol) {
    return SliverList(
      delegate: SliverChildBuilderDelegate(
        (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + index * 150),
              curve: Curves.easeOutBack,
              builder: (context, value, child) {
                return Transform.scale(
                  scale: 0.9 + 0.1 * value,
                  child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
                );
              },
              child: _RecommendationCard(option: recs[index], currencySymbol: currencySymbol),
            ),
          );
        },
        childCount: recs.length,
      ),
    );
  }

  Future<void> _saveReport(StrategyReport report) async {
    setState(() => _isSaving = true);
    try {
      final api = ref.read(reportApiProvider);
      await api.saveReport(report);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AgriAgentTheme.successGreen, size: 20),
                const SizedBox(width: 10),
                Text(L10n.tr(context, 'report_saved')),
              ],
            ),
            backgroundColor: Theme.of(context).cardColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AgriAgentTheme.errorRed, size: 20),
                const SizedBox(width: 10),
                Text('${L10n.tr(context, 'failed_to_save')}: $e'),
              ],
            ),
            backgroundColor: Theme.of(context).cardColor,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _generateReport() async {
    setState(() => _isGenerating = true);
    try {
      final userId = ref.read(selectedFarmerIdProvider);
      final api = ref.read(agentApiProvider);
      final langCode = Localizations.localeOf(context).languageCode;
      await api.generateReport(userId, langCode);
      ref.invalidate(previousReportsProvider);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L10n.tr(context, 'failed_to_generate_report')}: $e'),
            backgroundColor: AgriAgentTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Sub-widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SaveButton extends StatelessWidget {
  final bool isSaving;
  final VoidCallback onSave;

  const _SaveButton({required this.isSaving, required this.onSave});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: isSaving ? null : onSave,
      icon: isSaving
          ? const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : const Icon(Icons.save_rounded, size: 18),
      label: Text(isSaving ? L10n.tr(context, 'saving') : L10n.tr(context, 'save_report')),
    );
  }
}

class _AnalysisCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String content;
  final Color color;

  const _AnalysisCard({
    super.key,
    required this.icon,
    required this.title,
    required this.content,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              content,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.6),
                    height: 1.6,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RecommendationCard extends StatelessWidget {
  final CropOption option;
  final String currencySymbol;

  const _RecommendationCard({required this.option, required this.currencySymbol});

  @override
  Widget build(BuildContext context) {
    final isTopPick = option.rank == 1;
    final cropColor = AgriAgentTheme.cropTypeColor(option.crop);

    return GlassCard(
      showGradientBorder: isTopPick,
      accentColor: isTopPick ? AgriAgentTheme.mossGreen : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: rank + crop name
          Row(
            children: [
              // Rank badge
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  gradient: isTopPick
                      ? AgriAgentTheme.primaryGradient
                      : null,
                  color: isTopPick ? null : Theme.of(context).colorScheme.onSurface.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '#${option.rank}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                      color: isTopPick
                          ? Colors.white
                          : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      option.crop,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: cropColor,
                          ),
                    ),
                    Text(
                      '${option.expectedYieldTonsPerHectare.toStringAsFixed(1)} ${L10n.tr(context, 'expected_yield')}',
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
              if (isTopPick)
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    gradient: AgriAgentTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    L10n.tr(context, 'top_pick'),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: 1,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),

          // Risk gauge centered
          Center(
            child: RiskGauge(
              score: option.riskScore,
              size: 90,
              label: L10n.tr(context, 'risk_score'),
            ),
          ),
          const SizedBox(height: 20),

          // Financial breakdown
          _FinancialRow(
            label: L10n.tr(context, 'revenue'),
            value: option.estimatedRevenue,
            color: AgriAgentTheme.successGreen,
            currencySymbol: currencySymbol,
          ),
          const SizedBox(height: 6),
          _FinancialRow(
            label: L10n.tr(context, 'cost'),
            value: -option.estimatedCost,
            color: AgriAgentTheme.errorRed,
            currencySymbol: currencySymbol,
          ),
          Divider(
            color: Theme.of(context).dividerColor,
            height: 16,
          ),
          _FinancialRow(
            label: L10n.tr(context, 'profit'),
            value: option.estimatedProfit,
            color: option.estimatedProfit >= 0
                ? AgriAgentTheme.mossGreen
                : AgriAgentTheme.errorRed,
            isBold: true,
            currencySymbol: currencySymbol,
          ),
          const SizedBox(height: 16),

          // Risk factors
          if (option.riskFactors.isNotEmpty) ...[
            Text(
              L10n.tr(context, 'risk_factors'),
              style: Theme.of(context)
                  .textTheme
                  .labelSmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            ),
            const SizedBox(height: 6),
            ...option.riskFactors.map((factor) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(top: 5),
                      child: Icon(Icons.circle,
                          size: 5, color: AgriAgentTheme.warningOrange),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        factor,
                        style: Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                              color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                              height: 1.4,
                            ),
                      ),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: 12),
          ],

          // Rotation benefit
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AgriAgentTheme.mossGreen.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: AgriAgentTheme.mossGreen.withOpacity(0.15),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.autorenew_rounded,
                    size: 14, color: AgriAgentTheme.mossGreen),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    option.rotationBenefit,
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(
                          color: AgriAgentTheme.mossGreen.withOpacity(0.8),
                          fontSize: 11,
                          height: 1.4,
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

class _FinancialRow extends StatelessWidget {
  final String label;
  final double value;
  final Color color;
  final bool isBold;
  final String currencySymbol;

  const _FinancialRow({
    required this.label,
    required this.value,
    required this.color,
    required this.currencySymbol,
    this.isBold = false,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: isBold ? 13 : 12,
            fontWeight: isBold ? FontWeight.w700 : FontWeight.w500,
            color: isBold ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
          ),
        ),
        const Spacer(),
        Text(
          '${currencySymbol}${_formatCurrency(value.abs())}',
          style: TextStyle(
            fontSize: isBold ? 15 : 13,
            fontWeight: isBold ? FontWeight.w800 : FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }

  String _formatCurrency(double value) {
    if (value >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _FinalRecommendationCard extends StatelessWidget {
  final String recommendation;

  const _FinalRecommendationCard({required this.recommendation});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: 0.95 + 0.05 * value,
          child: Opacity(opacity: value.clamp(0.0, 1.0), child: child),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AgriAgentTheme.mossGreen.withOpacity(0.15),
              AgriAgentTheme.mossGreen.withOpacity(0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AgriAgentTheme.mossGreen.withOpacity(0.4),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AgriAgentTheme.mossGreen.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    gradient: AgriAgentTheme.primaryGradient,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color:
                            AgriAgentTheme.mossGreen.withOpacity(0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Text(
                  L10n.tr(context, 'final_recommendation'),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AgriAgentTheme.mossGreen,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              recommendation,
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withOpacity(0.85),
                    height: 1.7,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
