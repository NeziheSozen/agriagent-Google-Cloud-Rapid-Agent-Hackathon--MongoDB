import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';

import '../app/l10n/translations.dart';
import '../app/responsive.dart';
import '../app/theme.dart';
import '../models/regional_threats.dart';
import '../providers/threat_provider.dart';
import '../providers/farmer_provider.dart';
import '../services/agent_api.dart';
import '../widgets/glass_card.dart';
import '../widgets/threat_badge.dart';
import '../widgets/shimmer_loading.dart';

/// Threats screen showing active regional pest/disease/weather alerts.
class ThreatsScreen extends ConsumerStatefulWidget {
  const ThreatsScreen({super.key});

  @override
  ConsumerState<ThreatsScreen> createState() => _ThreatsScreenState();
}

class _ThreatsScreenState extends ConsumerState<ThreatsScreen> {
  bool _isScanning = false;

  Future<void> _scanPest(ImageSource source) async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: source);
    if (file == null) return;

    if (!mounted) return;
    setState(() => _isScanning = true);

    try {
      final userId = ref.read(selectedFarmerIdProvider);
      if (userId == null) throw Exception("No farmer selected.");

      final api = ref.read(agentApiProvider);
      final langCode = Localizations.localeOf(context).languageCode;
      final result = await api.scanPest(userId, file, langCode);
      
      // Refresh the threats list after a successful scan
      ref.invalidate(currentThreatsProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L10n.tr(context, 'identified')}: ${result["threat_name"]}'),
            backgroundColor: AgriAgentTheme.successGreen,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${L10n.tr(context, 'scan_failed')}: $e'),
            backgroundColor: AgriAgentTheme.errorRed,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isScanning = false);
      }
    }
  }

  void _showImageSourcePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(
                L10n.tr(context, 'choose_source'),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: Text(L10n.tr(context, 'camera')),
              onTap: () {
                Navigator.pop(context);
                _scanPest(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: Text(L10n.tr(context, 'gallery')),
              onTap: () {
                Navigator.pop(context);
                _scanPest(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final threatsAsync = ref.watch(currentThreatsProvider);

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _isScanning ? null : _showImageSourcePicker,
        backgroundColor: AgriAgentTheme.mossGreen,
        foregroundColor: Colors.white,
        icon: _isScanning 
            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
            : const Icon(Icons.camera_alt, color: Colors.white),
        label: Text(
          _isScanning ? L10n.tr(context, 'analyzing') : L10n.tr(context, 'scan_pest'),
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
        ),
      ),
      body: SafeArea(
        child: threatsAsync.when(
          loading: () => Padding(
            padding: context.responsivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                ShimmerLoading.box(width: 200, height: 28),
                const SizedBox(height: 24),
                ShimmerLoading.card(height: 100),
                const SizedBox(height: 12),
                ShimmerLoading.listSkeleton(count: 3, rowHeight: 140),
              ],
            ),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.shield_outlined,
                    color: AgriAgentTheme.errorRed, size: 48),
                const SizedBox(height: 16),
                Text(L10n.tr(context, 'load_threats_failed'),
                    style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 8),
                Text('$error',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4))),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(currentThreatsProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(L10n.tr(context, 'retry')),
                ),
              ],
            ),
          ),
          data: (threats) => CustomScrollView(
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
                                  L10n.tr(context, 'regional_threats'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                          fontWeight: FontWeight.w700),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${threats.region} · ${threats.queryDate}',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                                ),
                              ],
                            ),
                          ),
                          ThreatBadge(severity: threats.overallRiskLevel),
                        ],
                      ),
                      const SizedBox(height: 20),

                      // Advisory card
                      GlassCard(
                        accentColor: AgriAgentTheme.severityColor(
                            threats.overallRiskLevel),
                        showGradientBorder: true,
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AgriAgentTheme.severityColor(
                                        threats.overallRiskLevel)
                                    .withOpacity(0.12),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                Icons.shield_rounded,
                                color: AgriAgentTheme.severityColor(
                                    threats.overallRiskLevel),
                                size: 24,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment:
                                    CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    L10n.tr(context, 'advisory'),
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                            fontWeight: FontWeight.w600),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    threats.advisory,
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
                      const SizedBox(height: 20),

                      // Section header
                      Row(
                        children: [
                          Text(
                            L10n.tr(context, 'active_alerts'),
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: AgriAgentTheme.mossGreen
                                  .withOpacity(0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${threats.activeThreats.length}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AgriAgentTheme.mossGreen,
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

              // Threat list
              SliverPadding(
                padding: context.responsivePadding,
                sliver: SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      if (index >= threats.activeThreats.length) {
                        return null;
                      }
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _ThreatAlertCard(
                          threat: threats.activeThreats[index],
                          index: index,
                        ),
                      );
                    },
                    childCount: threats.activeThreats.length,
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 100),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ThreatAlertCard extends StatelessWidget {
  final ThreatAlert threat;
  final int index;

  const _ThreatAlertCard({required this.threat, required this.index});

  @override
  Widget build(BuildContext context) {
    final lang = Localizations.localeOf(context).languageCode;
    String displayTitle;
    String displayDesc;
    String subtitle = '';

    if (lang == 'tr') {
      // Turkish: prefer Turkish name, fall back to local name, then English
      if (threat.threatNameTr != null && threat.threatNameTr!.isNotEmpty) {
        displayTitle = threat.threatNameTr!;
      } else if (threat.localThreatName != null && threat.localThreatName!.isNotEmpty) {
        displayTitle = threat.localThreatName!;
      } else {
        displayTitle = threat.threatName;
      }
      displayDesc = threat.descriptionTr ?? threat.localDescription ?? threat.description;
      // Show English name as subtitle if different
      if (displayTitle != threat.threatName) {
        subtitle = threat.threatName;
      }
    } else {
      // All other languages: use English name
      displayTitle = threat.threatName;
      displayDesc = threat.description;
      // No Turkish subtitle for non-Turkish users
      subtitle = '';
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + index * 100),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: GlassCard(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (threat.imageUrl != null && threat.imageUrl!.isNotEmpty) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.network(
                      threat.imageUrl!,
                      width: 64,
                      height: 64,
                      fit: BoxFit.cover,
                      headers: const {
                        'User-Agent': 'AgriAgent/2.0 (Agricultural Advisory App)',
                      },
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Center(
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          ),
                        );
                      },
                      errorBuilder: (_, error, ___) => Container(
                        width: 64,
                        height: 64,
                        decoration: BoxDecoration(
                          color: AgriAgentTheme.severityColor(threat.severity).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Icon(
                          threat.threatType == 'Disease' ? Icons.coronavirus_rounded : Icons.bug_report_rounded,
                          color: AgriAgentTheme.severityColor(threat.severity),
                          size: 28,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                ] else ...[
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AgriAgentTheme.severityColor(threat.severity).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      threat.threatType == 'Disease' ? Icons.coronavirus_rounded : Icons.bug_report_rounded,
                      color: AgriAgentTheme.severityColor(threat.severity),
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayTitle,
                        style: Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      if (subtitle.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context)
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                                fontStyle: FontStyle.italic,
                              ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                ThreatBadge(severity: threat.severity),
              ],
            ),
            const SizedBox(height: 12),

            // Type + date
            Row(
              children: [
                ThreatTypeBadge(type: threat.threatType),
                const Spacer(),
                Icon(Icons.calendar_today_rounded,
                    size: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                const SizedBox(width: 4),
                Text(
                  _formatDate(threat.reportedDate),
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), fontSize: 11),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Affected crops
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: threat.affectedCrops.map((crop) {
                final color = AgriAgentTheme.cropTypeColor(crop);
                return Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withOpacity(0.2)),
                  ),
                  child: Text(
                    L10n.trCrop(context, crop),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 14),

            // Source + spread risk
            Row(
              children: [
                Icon(Icons.location_on_outlined,
                    size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                const SizedBox(width: 4),
                Text(
                  threat.sourceLocation,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                ),
                const Spacer(),
                _SpreadRiskIndicator(
                    risk: threat.spreadRiskToNeighbors),
              ],
            ),
            const SizedBox(height: 12),

            // Description
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.03),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                displayDesc,
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.5),
                      height: 1.5,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatDate(String isoDate) {
    try {
      final dt = DateTime.parse(isoDate);
      return '${dt.day.toString().padLeft(2, '0')}.${dt.month.toString().padLeft(2, '0')}.${dt.year}';
    } catch (_) {
      return isoDate;
    }
  }
}

class _SpreadRiskIndicator extends StatelessWidget {
  final double risk;

  const _SpreadRiskIndicator({required this.risk});

  @override
  Widget build(BuildContext context) {
    final percentage = (risk * 100).toStringAsFixed(0);
    final color = risk >= 0.7
        ? AgriAgentTheme.errorRed
        : risk >= 0.4
            ? AgriAgentTheme.warningOrange
            : AgriAgentTheme.successGreen;

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.share_rounded, size: 12, color: color.withOpacity(0.7)),
        const SizedBox(width: 4),
        Text(
          '${L10n.tr(context, 'spread_label')}: $percentage%',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}
