import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

import '../app/responsive.dart';
import '../app/theme.dart';
import '../providers/farmer_provider.dart';
import '../services/farmer_api.dart';
import '../providers/climate_provider.dart';
import '../providers/threat_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/stat_tile.dart';
import '../widgets/crop_timeline.dart';
import '../widgets/fleet_calendar_card.dart';
import '../widgets/threat_badge.dart';
import '../widgets/shimmer_loading.dart';
import '../widgets/location_search_dialog.dart';
import '../widgets/urgency_radar_card.dart';
import '../widgets/daily_briefing_card.dart';
import '../app/l10n/translations.dart';
import '../models/farmer_profile.dart';
import '../providers/theme_provider.dart';
import '../providers/shared_prefs_provider.dart';
import '../services/push_notification_service.dart';

final selectedPlotIdProvider = StateProvider<String?>((ref) => null);

/// Dashboard / Home screen showing key farm metrics at a glance.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmerAsync = ref.watch(currentFarmerProvider);

    // Initialize push notifications (requests permission and gets token)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushNotificationServiceProvider).initialize();
    });

    return Scaffold(
      endDrawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            DrawerHeader(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Icon(Icons.eco, size: 48, color: AgriAgentTheme.mossGreen),
                  const SizedBox(height: 8),
                  Text('AgriAgent', style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
            ),
            ListTile(
              leading: const Icon(Icons.groups_outlined),
              title: Text(L10n.tr(context, 'nav_cooperatives')),
              onTap: () {
                Navigator.pop(context);
                context.push('/cooperatives');
              },
            ),
            ListTile(
              leading: const Icon(Icons.local_shipping_outlined),
              title: const Text('Logistics'),
              onTap: () {
                Navigator.pop(context);
                context.push('/logistics');
              },
            ),
            const Divider(),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: Text(L10n.tr(context, 'settings')),
              onTap: () {
                Navigator.pop(context);
                context.push('/settings');
              },
            ),
          ],
        ),
      ),
      body: SafeArea(
        child: CustomScrollView(
          slivers: [
            // ── Header ────────────────────────────────────────────────────
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
                                L10n.tr(context, 'dashboard'),
                                style: Theme.of(context)
                                    .textTheme
                                    .headlineMedium
                                    ?.copyWith(fontWeight: FontWeight.w700),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                L10n.tr(context, 'predictive_overview'),
                                style: Theme.of(context)
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              _OfflineIndicator(ref: ref),
                            ],
                          ),
                        ),
                        const SizedBox(width: 4),
                        // Farmer selector
                        Flexible(
                          flex: 0,
                          child: _FarmerSelectorChip(ref: ref),
                        ),
                        Builder(
                          builder: (ctx) => IconButton(
                            onPressed: () => Scaffold.of(ctx).openEndDrawer(),
                            icon: Icon(
                              Icons.menu_rounded,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            tooltip: 'Menu',
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),

            // ── Content ───────────────────────────────────────────────────
            farmerAsync.when(
              loading: () => SliverPadding(
                padding: context.responsivePadding,
                sliver: SliverGrid.count(
                  crossAxisCount: context.gridColumns,
                  crossAxisSpacing: 12,
                  mainAxisSpacing: 12,
                  childAspectRatio: 2.5,
                  children: List.generate(
                    6,
                    (_) => ShimmerLoading.statTileSkeleton(),
                  ),
                ),
              ),
              error: (error, _) => SliverToBoxAdapter(
                child: _ErrorCard(
                  message: error.toString(),
                  onRetry: () => ref.invalidate(currentFarmerProvider),
                ),
              ),
              data: (farmer) {
                if (farmer.plots.isEmpty) {
                  return SliverToBoxAdapter(child: Center(child: Text(L10n.tr(context, 'no_plots_found'))));
                }
                final selectedPlotId = ref.watch(selectedPlotIdProvider);
                final currentPlot = farmer.plots.firstWhere(
                  (p) => p.plotId == selectedPlotId,
                  orElse: () => farmer.plots.first,
                );

                return SliverPadding(
                  padding: context.responsivePadding,
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Plot Selector
                      if (farmer.plots.length > 1)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: Wrap(
                            spacing: 8,
                            children: farmer.plots.map((p) {
                              final isSelected = p.plotId == currentPlot.plotId;
                              return ChoiceChip(
                                label: Text(p.name),
                                selected: isSelected,
                                selectedColor: AgriAgentTheme.mossGreen,
                                onSelected: (val) {
                                  if (val) {
                                    ref.read(selectedPlotIdProvider.notifier).state = p.plotId;
                                  }
                                },
                              );
                            }).toList(),
                          ),
                        ),
                      // Quick stats grid
                      _buildStatsGrid(context, ref, farmer, currentPlot),
                      const SizedBox(height: 20),

                      // Urgency Radar Card
                      UrgencyRadarCard(farmer: farmer),
                      const SizedBox(height: 16),

                      // Daily Briefing Card
                      DailyBriefingCard(farmer: farmer),
                      const SizedBox(height: 16),

                      // Crop rotation timeline
                      GlassCard(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(
                                  Icons.history_rounded,
                                  color: AgriAgentTheme.harvestGold,
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  L10n.tr(context, 'history'),
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleSmall
                                      ?.copyWith(
                                          fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            CropTimeline(
                              history: currentPlot.cropHistory,
                              compact: context.isMobile,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),

                      // Fleet Management Calendar
                      const FleetCalendarCard(),
                      const SizedBox(height: 16),

                      // Bottom row: Climate + Threats summary
                      _buildSummaryRow(context, ref),
                      const SizedBox(height: 16),

                      // Generate report CTA
                      _GenerateReportCTA(
                        onTap: () => context.go('/report'),
                      ),
                      const SizedBox(height: 100), // Added padding for FAB
                    ].animate(interval: 100.ms).fadeIn(duration: 400.ms).slideY(begin: 0.1, duration: 400.ms, curve: Curves.easeOutCubic)),
                  ),
                );
              },
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.go('/chat'),
        backgroundColor: AgriAgentTheme.mossGreen,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.smart_toy_rounded),
        label: Text(L10n.tr(context, 'assistant_title')),
      ),
    );
  }

  void _showEditDialog(
      BuildContext context, WidgetRef ref, FarmerProfile farmer, FarmPlot currentPlot, String fieldKey, String initialValue) {
    // For farm_size, convert hectares to the display unit (dönüm or ha)
    String editValue = initialValue;
    String unitLabel = '';
    if (fieldKey == 'farm_size') {
      final hectares = currentPlot.sizeHectares;
      if (hectares < 1.0) {
        editValue = (hectares * 10).round().toString();
        unitLabel = L10n.tr(context, 'unit_donum');
      } else {
        editValue = hectares.toStringAsFixed(1);
        unitLabel = L10n.tr(context, 'unit_hectare');
      }
    }
    final controller = TextEditingController(text: editValue);
    final dialogTitle = L10n.tr(context, 'edit_$fieldKey');
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(dialogTitle),
        content: TextField(
          controller: controller,
          keyboardType: fieldKey == 'farm_size' ? TextInputType.number : TextInputType.text,
          decoration: InputDecoration(
            border: const OutlineInputBorder(),
            suffixText: unitLabel.isNotEmpty ? unitLabel : null,
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.tr(context, 'cancel'))),
          ElevatedButton(
            onPressed: () async {
              try {
                final api = ref.read(farmerApiProvider);
                final plotIndex = farmer.plots.indexOf(currentPlot);
                if (fieldKey == 'farm_size') {
                  final inputVal = double.tryParse(controller.text) ?? 0;
                  final hectares = currentPlot.sizeHectares < 1.0
                      ? inputVal / 10.0
                      : inputVal;
                  await api.updatePlot(farmer.userId, plotIndex, {'size_hectares': hectares});
                }
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ref.invalidate(farmerProfileProvider(farmer.userId));
                  ref.invalidate(currentFarmerProvider);
                }
              } catch (e) {
                if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${L10n.tr(context, 'error_generic')}: $e')));
              }
            },
            child: Text(L10n.tr(context, 'save')),
          ),
        ],
      ),
    );
  }

  /// Show a dropdown dialog for irrigation level selection.
  void _showIrrigationPicker(
      BuildContext context, WidgetRef ref, FarmerProfile farmer, FarmPlot currentPlot) {
    final options = ['None', 'Low', 'Medium', 'High'];
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(L10n.tr(context, 'select_irrigation')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: options.map((level) {
            final isSelected = currentPlot.irrigationLevel.toLowerCase() == level.toLowerCase();
            return ListTile(
              leading: Icon(
                isSelected ? Icons.radio_button_checked : Icons.radio_button_unchecked,
                color: isSelected ? AgriAgentTheme.infoBlue : null,
              ),
              title: Text(
                L10n.formatIrrigation(context, level),
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                  color: isSelected ? AgriAgentTheme.infoBlue : null,
                ),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              onTap: () async {
                try {
                  final api = ref.read(farmerApiProvider);
                  final plotIndex = farmer.plots.indexOf(currentPlot);
                  await api.updatePlot(farmer.userId, plotIndex, {'irrigation_level': level});
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(farmerProfileProvider(farmer.userId));
                    ref.invalidate(currentFarmerProvider);
                  }
                } catch (e) {
                  if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('${L10n.tr(context, 'error_generic')}: $e')));
                }
              },
            );
          }).toList(),
        ),
      ),
    );
  }

  /// Show soil analysis details or prompt to add one.
  void _showSoilDialog(
      BuildContext context, WidgetRef ref, FarmerProfile farmer, FarmPlot currentPlot) {
    final soil = currentPlot.soilAnalysis;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.science_rounded, color: AgriAgentTheme.harvestGold, size: 22),
            const SizedBox(width: 8),
            Text(L10n.tr(context, 'edit_soil')),
          ],
        ),
        content: soil != null
            ? SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _soilRow(L10n.tr(context, 'soil_ph'), soil.ph.toStringAsFixed(1)),
                    _soilRow(L10n.tr(context, 'soil_nitrogen'), soil.nitrogenPpm.toStringAsFixed(0)),
                    _soilRow(L10n.tr(context, 'soil_phosphorus'), soil.phosphorusPpm.toStringAsFixed(0)),
                    _soilRow(L10n.tr(context, 'soil_potassium'), soil.potassiumPpm.toStringAsFixed(0)),
                    _soilRow(L10n.tr(context, 'soil_organic_matter'), soil.organicMatterPercent.toStringAsFixed(1)),
                    _soilRow(L10n.tr(context, 'soil_salinity'), soil.salinityDsM.toStringAsFixed(2)),
                    _soilRow(L10n.tr(context, 'soil_texture'), soil.texture),
                  ],
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.science_outlined, size: 48, color: Colors.grey.shade300),
                  const SizedBox(height: 12),
                  Text(L10n.tr(context, 'soil_no_data'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 4),
                  Text(L10n.tr(context, 'soil_add_desc'),
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                ],
              ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.tr(context, 'close')),
          ),
          if (soil == null) ...[
            TextButton.icon(
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(L10n.tr(context, 'soil_enter_manual')),
              onPressed: () {
                Navigator.pop(ctx);
                _showAddSoilDialog(context, ref, farmer, currentPlot);
              },
            ),
            ElevatedButton.icon(
              icon: const Icon(Icons.document_scanner_rounded, size: 18),
              label: Text(L10n.tr(context, 'soil_scan_report')),
              onPressed: () {
                Navigator.pop(ctx);
                // Navigate to farmer screen's scan feature
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(L10n.tr(context, 'scan_lab_desc'))),
                );
              },
            ),
          ],
        ],
      ),
    );
  }

  /// Show dialog to add a new soil analysis manually.
  void _showAddSoilDialog(
      BuildContext context, WidgetRef ref, FarmerProfile farmer, FarmPlot currentPlot) {
    final phController = TextEditingController();
    final nController = TextEditingController();
    final pController = TextEditingController();
    final kController = TextEditingController();
    final omController = TextEditingController();
    final salController = TextEditingController();
    final textureController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.edit_document, color: AgriAgentTheme.harvestGold, size: 22),
            const SizedBox(width: 8),
            Text(L10n.tr(context, 'soil_enter_manual')),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: phController,
                decoration: InputDecoration(labelText: L10n.tr(context, 'soil_ph')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: nController,
                decoration: InputDecoration(labelText: L10n.tr(context, 'soil_nitrogen')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: pController,
                decoration: InputDecoration(labelText: L10n.tr(context, 'soil_phosphorus')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: kController,
                decoration: InputDecoration(labelText: L10n.tr(context, 'soil_potassium')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: omController,
                decoration: InputDecoration(labelText: L10n.tr(context, 'soil_organic_matter')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: salController,
                decoration: InputDecoration(labelText: L10n.tr(context, 'soil_salinity')),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: textureController,
                decoration: InputDecoration(labelText: L10n.tr(context, 'soil_texture')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.tr(context, 'cancel')),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AgriAgentTheme.mossGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              try {
                final api = ref.read(farmerApiProvider);
                final plotIndex = farmer.plots.indexOf(currentPlot);

                final soilData = {
                  'ph': double.tryParse(phController.text) ?? 7.0,
                  'nitrogen_ppm': double.tryParse(nController.text) ?? 0.0,
                  'phosphorus_ppm': double.tryParse(pController.text) ?? 0.0,
                  'potassium_ppm': double.tryParse(kController.text) ?? 0.0,
                  'organic_matter_percent': double.tryParse(omController.text) ?? 0.0,
                  'salinity_ds_m': double.tryParse(salController.text) ?? 0.0,
                  'texture': textureController.text.trim().isEmpty ? 'Unknown' : textureController.text.trim(),
                  'test_date': DateTime.now().toIso8601String().split('T')[0],
                };

                await api.updatePlot(farmer.userId, plotIndex, {'soil_analysis': soilData});
                if (ctx.mounted) {
                  Navigator.pop(ctx);
                  ref.invalidate(farmerProfileProvider(farmer.userId));
                  ref.invalidate(currentFarmerProvider);
                }
              } catch (e) {
                if (ctx.mounted) {
                  ScaffoldMessenger.of(ctx).showSnackBar(
                    SnackBar(content: Text('${L10n.tr(context, 'error_generic')}: $e')),
                  );
                }
              }
            },
            child: Text(L10n.tr(context, 'save')),
          ),
        ],
      ),
    );
  }

  Widget _soilRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(fontSize: 13, color: Colors.grey.shade600)),
          Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  /// Show crop history dialog with option to add new entries.
  void _showCropHistoryDialog(
      BuildContext context, WidgetRef ref, FarmerProfile farmer, FarmPlot currentPlot) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          children: [
            Icon(Icons.history_rounded, color: AgriAgentTheme.cropCereal, size: 22),
            const SizedBox(width: 8),
            Text(L10n.tr(context, 'crop_history_title')),
          ],
        ),
        content: SizedBox(
          width: double.maxFinite,
          child: currentPlot.cropHistory.isNotEmpty
              ? ListView.separated(
                  shrinkWrap: true,
                  itemCount: currentPlot.cropHistory.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final entry = currentPlot.cropHistory[i];
                    return ListTile(
                      dense: true,
                      leading: CircleAvatar(
                        radius: 16,
                        backgroundColor: AgriAgentTheme.mossGreen.withOpacity(0.12),
                        child: Text(
                          '${entry.year}'.substring(2),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: AgriAgentTheme.mossGreen,
                          ),
                        ),
                      ),
                      title: Text(entry.crop, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: entry.yieldTonsPerHectare > 0
                          ? Text('${entry.yieldTonsPerHectare.toStringAsFixed(1)} ton/ha')
                          : null,
                    );
                  },
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.grass_rounded, size: 48, color: Colors.grey.shade300),
                    const SizedBox(height: 12),
                    Text(L10n.tr(context, 'no_crop_history'),
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 4),
                    Text(L10n.tr(context, 'add_first_crop'),
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Colors.grey.shade500)),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.tr(context, 'close')),
          ),
          ElevatedButton.icon(
            icon: const Icon(Icons.add_rounded, size: 18),
            label: Text(L10n.tr(context, 'add_crop')),
            style: ElevatedButton.styleFrom(
              backgroundColor: AgriAgentTheme.mossGreen,
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _showAddCropDialog(context, ref, farmer, currentPlot);
            },
          ),
        ],
      ),
    );
  }

  /// Show dialog to add a new crop entry.
  void _showAddCropDialog(
      BuildContext context, WidgetRef ref, FarmerProfile farmer, FarmPlot currentPlot) {
    String? selectedCrop;
    final yieldController = TextEditingController();
    final currentYear = DateTime.now().year;
    int selectedYear = currentYear;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Row(
            children: [
              Icon(Icons.eco_rounded, color: AgriAgentTheme.successGreen, size: 22),
              const SizedBox(width: 8),
              Text(L10n.tr(context, 'add_crop')),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Year dropdown
              DropdownButtonFormField<int>(
                value: selectedYear,
                decoration: InputDecoration(
                  labelText: L10n.tr(context, 'crop_year'),
                  border: const OutlineInputBorder(),
                ),
                items: List.generate(10, (i) => currentYear - i)
                    .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                    .toList(),
                onChanged: (v) => setDialogState(() => selectedYear = v ?? currentYear),
              ),
              const SizedBox(height: 14),
              // Crop name dropdown
              DropdownButtonFormField<String>(
                value: selectedCrop,
                decoration: InputDecoration(
                  labelText: L10n.tr(context, 'crop_name'),
                  border: const OutlineInputBorder(),
                ),
                items: () {
                  final list = L10n.allCrops.toList();
                  list.sort((a, b) => L10n.trCrop(context, a).compareTo(L10n.trCrop(context, b)));
                  return list.map((c) => DropdownMenuItem(value: c, child: Text(L10n.trCrop(context, c)))).toList();
                }(),
                onChanged: (v) => setDialogState(() => selectedCrop = v),
              ),
              const SizedBox(height: 14),
              // Yield
              TextField(
                controller: yieldController,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: L10n.tr(context, 'crop_yield'),
                  border: const OutlineInputBorder(),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L10n.tr(context, 'cancel')),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AgriAgentTheme.mossGreen,
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                if (selectedCrop == null) return;
                try {
                  final api = ref.read(farmerApiProvider);
                  final plotIndex = farmer.plots.indexOf(currentPlot);
                  await api.addCropHistory(farmer.userId, plotIndex, {
                    'year': selectedYear,
                    'crop': selectedCrop,
                    'yield_tons_per_hectare': double.tryParse(yieldController.text) ?? 0.0,
                  });
                  if (ctx.mounted) {
                    Navigator.pop(ctx);
                    ref.invalidate(farmerProfileProvider(farmer.userId));
                    ref.invalidate(currentFarmerProvider);
                  }
                } catch (e) {
                  if (ctx.mounted) {
                    ScaffoldMessenger.of(ctx).showSnackBar(
                      SnackBar(content: Text('${L10n.tr(context, 'error_generic')}: $e')),
                    );
                  }
                }
              },
              child: Text(L10n.tr(context, 'save')),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsGrid(BuildContext context, WidgetRef ref, FarmerProfile farmer, FarmPlot currentPlot) {
    final stats = [
      StatTile(
        icon: Icons.landscape_rounded,
        label: L10n.tr(context, 'farm_size'),
        value: L10n.formatFarmSize(context, currentPlot.sizeHectares),
        accentColor: AgriAgentTheme.mossGreen,
        onTap: () => _showEditDialog(context, ref, farmer, currentPlot, 'farm_size', currentPlot.sizeHectares.toString()),
      ),
      StatTile(
        icon: Icons.water_drop_rounded,
        label: L10n.tr(context, 'irrigation'),
        value: L10n.formatIrrigation(context, currentPlot.irrigationLevel),
        accentColor: AgriAgentTheme.infoBlue,
        onTap: () => _showIrrigationPicker(context, ref, farmer, currentPlot),
      ),
      StatTile(
        icon: Icons.science_rounded,
        label: L10n.tr(context, 'soil_ph'),
        value: currentPlot.soilAnalysis?.ph.toStringAsFixed(1) ?? 'N/A',
        accentColor: AgriAgentTheme.harvestGold,
        subtitle: currentPlot.soilAnalysis?.texture,
        onTap: () => _showSoilDialog(context, ref, farmer, currentPlot),
      ),
      StatTile(
        icon: Icons.history_rounded,
        label: L10n.tr(context, 'crop_years'),
        value: '${currentPlot.cropHistory.length}',
        accentColor: AgriAgentTheme.cropCereal,
        onTap: () => _showCropHistoryDialog(context, ref, farmer, currentPlot),
      ),
      StatTile(
        icon: Icons.location_on_rounded,
        label: L10n.tr(context, 'location'),
        value: farmer.location,
        accentColor: AgriAgentTheme.warningOrange,
        subtitle: farmer.region,
         onTap: () async {
          final result = await LocationSearchDialog.show(context, farmer.location);
          if (result != null && context.mounted) {
            try {
              final api = ref.read(farmerApiProvider);
              await api.updateProfile(farmer.userId, {
                'location': result.location,
                'region': result.region,
              });
              // Invalidate both providers to force a fresh fetch
              ref.invalidate(farmerProfileProvider(farmer.userId));
              ref.invalidate(currentFarmerProvider);
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('${L10n.tr(context, 'error_generic')}: $e')),
                );
              }
            }
          }
        },
      ),
      StatTile(
        icon: Icons.eco_rounded,
        label: L10n.tr(context, 'latest_crop'),
        value: currentPlot.cropHistory.isNotEmpty
            ? currentPlot.cropHistory.last.crop
            : 'N/A',
        accentColor: AgriAgentTheme.successGreen,
        onTap: () => _showCropHistoryDialog(context, ref, farmer, currentPlot),
      ),
    ];

    final columns = context.gridColumns;
    if (columns == 1) {
      return Column(
        children: stats
            .map((s) => Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: s,
                ))
            .toList(),
      );
    }

    final rows = <Widget>[];
    for (int i = 0; i < stats.length; i += columns) {
      final rowChildren = <Widget>[];
      for (int j = 0; j < columns && i + j < stats.length; j++) {
        rowChildren.add(Expanded(child: stats[i + j]));
        if (j < columns - 1 && i + j + 1 < stats.length) {
          rowChildren.add(const SizedBox(width: 10));
        }
      }
      rows.add(Row(children: rowChildren));
      if (i + columns < stats.length) {
        rows.add(const SizedBox(height: 10));
      }
    }
    return Column(children: rows);
  }

  Widget _buildSummaryRow(BuildContext context, WidgetRef ref) {
    final isWide = !context.isMobile;

    final climateCard = _ClimateSummaryCard(ref: ref);
    final threatCard = _ThreatSummaryCard(ref: ref);

    if (isWide) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: climateCard),
          const SizedBox(width: 16),
          Expanded(child: threatCard),
        ],
      );
    }

    return Column(
      children: [
        climateCard,
        const SizedBox(height: 16),
        threatCard,
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Helper Widgets
// ─────────────────────────────────────────────────────────────────────────────

class _FarmerSelectorChip extends StatelessWidget {
  final WidgetRef ref;

  const _FarmerSelectorChip({required this.ref});

  @override
  Widget build(BuildContext context) {
    final currentId = ref.watch(selectedFarmerIdProvider);
    final farmerAsync = ref.watch(currentFarmerProvider);
    final displayName = farmerAsync.when(
      data: (farmer) => farmer.name,
      loading: () => L10n.tr(context, 'loading'),
      error: (_, __) => currentId,
    );

    return PopupMenuButton<String>(
      onSelected: (value) {
        if (value == 'profile') {
          if (currentId == 'guest') {
            // Cannot view profile as guest, maybe go to login
            context.go('/login');
          } else {
            context.go('/farmer');
          }
        } else if (value == 'logout') {
          ref.read(sharedPreferencesProvider).remove('logged_in_user_id');
          ref.read(selectedFarmerIdProvider.notifier).set('guest');
          context.go('/login');
        }
      },
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      color: Theme.of(context).cardColor,
      offset: const Offset(0, 40),
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'profile',
          child: Row(
            children: [
              const Icon(Icons.person_outline_rounded, size: 18, color: Colors.white),
              const SizedBox(width: 10),
              Text(currentId == 'guest' ? L10n.tr(context, 'create_profile') : L10n.tr(context, 'view_profile'), style: const TextStyle(fontSize: 13)),
            ],
          ),
        ),
        PopupMenuItem(
          value: 'logout',
          child: Row(
            children: [
              const Icon(Icons.logout_rounded, size: 18, color: AgriAgentTheme.errorRed),
              const SizedBox(width: 10),
              Text(L10n.tr(context, 'logout'), style: const TextStyle(fontSize: 13, color: AgriAgentTheme.errorRed)),
            ],
          ),
        ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AgriAgentTheme.mossGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: AgriAgentTheme.mossGreen.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.person_rounded,
              size: 16,
              color: AgriAgentTheme.mossGreen,
            ),
            const SizedBox(width: 6),
            Text(
              currentId == 'guest' ? L10n.tr(context, 'guest') : displayName,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: AgriAgentTheme.mossGreen,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: AgriAgentTheme.mossGreen,
            ),
          ],
        ),
      ),
    );
  }
}

class _ClimateSummaryCard extends StatelessWidget {
  final WidgetRef ref;

  const _ClimateSummaryCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final climateAsync = ref.watch(currentClimateTrendProvider);

    return GlassCard(
      onTap: () => context.go('/climate'),
      child: climateAsync.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Row(
          children: [
            Icon(Icons.cloud_off_rounded, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(width: 10),
            Text(L10n.tr(context, 'climate_unavailable'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        data: (climate) {
          final forecast = climate.forecast;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.thermostat_rounded,
                      color: AgriAgentTheme.infoBlue, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    L10n.tr(context, 'climate_forecast'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_forward_ios_rounded,
                      size: 14, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.25)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniMetric(
                    label: L10n.tr(context, 'rainfall'),
                    value:
                        '${forecast.predictedRainfallMm.toStringAsFixed(0)} mm',
                    color: AgriAgentTheme.infoBlue,
                  ),
                  const SizedBox(width: 20),
                  _MiniMetric(
                    label: L10n.tr(context, 'temp'),
                    value:
                        '${forecast.predictedAvgTempCelsius.toStringAsFixed(1)}°C',
                    color: AgriAgentTheme.warningOrange,
                  ),
                  const SizedBox(width: 20),
                  _MiniMetric(
                    label: L10n.tr(context, 'drought_risk'),
                    value: forecast.droughtRisk,
                    color: AgriAgentTheme.severityColor(forecast.droughtRisk),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _ThreatSummaryCard extends StatelessWidget {
  final WidgetRef ref;

  const _ThreatSummaryCard({required this.ref});

  @override
  Widget build(BuildContext context) {
    final threatsAsync = ref.watch(currentThreatsProvider);

    return GlassCard(
      onTap: () => context.go('/threats'),
      child: threatsAsync.when(
        loading: () => const SizedBox(
          height: 80,
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        ),
        error: (e, _) => Row(
          children: [
            Icon(Icons.shield_outlined, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
            const SizedBox(width: 10),
            Text(L10n.tr(context, 'threat_unavailable'),
                style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        data: (threats) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: AgriAgentTheme.warningOrange, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    L10n.tr(context, 'active_threats'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const Spacer(),
                  ThreatBadge(
                    severity: threats.overallRiskLevel,
                    compact: true,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _MiniMetric(
                    label: L10n.tr(context, 'total'),
                    value: '${threats.activeThreats.length}',
                    color: AgriAgentTheme.severityColor(
                        threats.overallRiskLevel),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Text(
                      threats.advisory,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                            fontSize: 11,
                          ),
                    ),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MiniMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _GenerateReportCTA extends StatelessWidget {
  final VoidCallback onTap;

  const _GenerateReportCTA({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      onTap: onTap,
      showGradientBorder: true,
      accentColor: AgriAgentTheme.mossGreen,
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              gradient: AgriAgentTheme.primaryGradient,
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AgriAgentTheme.mossGreen.withOpacity(0.3),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: const Icon(Icons.auto_awesome_rounded,
                color: Colors.white, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.tr(context, 'generate_report'),
                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                ),
                const SizedBox(height: 4),
                Text(
                  L10n.tr(context, 'report_desc'),
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4),
                      ),
                ),
              ],
            ),
          ),
          const Icon(
            Icons.arrow_forward_rounded,
            color: AgriAgentTheme.mossGreen,
          ),
        ],
      ),
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: GlassCard(
        accentColor: AgriAgentTheme.errorRed,
        showGradientBorder: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline_rounded,
                color: AgriAgentTheme.errorRed, size: 48),
            const SizedBox(height: 16),
            Text(
              L10n.tr(context, 'failed_to_load_data'),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: Text(L10n.tr(context, 'retry')),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineIndicator extends StatefulWidget {
  final WidgetRef ref;
  const _OfflineIndicator({required this.ref});

  @override
  State<_OfflineIndicator> createState() => _OfflineIndicatorState();
}

class _OfflineIndicatorState extends State<_OfflineIndicator> {
  bool _isOffline = false;
  String? _lastUpdated;

  @override
  void initState() {
    super.initState();
    _checkStatus();
    Connectivity().onConnectivityChanged.listen((_) => _checkStatus());
  }

  Future<void> _checkStatus() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    final isOffline = connectivityResult.contains(ConnectivityResult.none);
    
    final prefs = widget.ref.read(sharedPreferencesProvider);
    final userId = widget.ref.read(selectedFarmerIdProvider);
    final cacheKey = 'cache_farmer_$userId';
    
    // Read actual cache timestamp
    final timestampStr = prefs.getString('${cacheKey}_timestamp');
    if (timestampStr != null) {
      try {
        final cachedAt = DateTime.parse(timestampStr);
        final diff = DateTime.now().difference(cachedAt);
        if (diff.inMinutes < 1) {
          _lastUpdated = 'Just now';
        } else if (diff.inMinutes < 60) {
          _lastUpdated = '${diff.inMinutes} min ago';
        } else if (diff.inHours < 24) {
          _lastUpdated = '${diff.inHours} hours ago';
        } else {
          _lastUpdated = '${diff.inDays} days ago';
        }
      } catch (_) {
        _lastUpdated = null;
      }
    }
    
    if (mounted) {
      setState(() {
        _isOffline = isOffline;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isOffline) return const SizedBox.shrink();
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AgriAgentTheme.warningOrange.withOpacity(0.15),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AgriAgentTheme.warningOrange.withOpacity(0.5)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.wifi_off_rounded, size: 14, color: AgriAgentTheme.warningOrange),
          const SizedBox(width: 6),
          Text(
            _lastUpdated != null ? L10n.tr(context, 'offline_last_update').replaceAll('%s', _lastUpdated!) : L10n.tr(context, 'offline'),
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: AgriAgentTheme.warningOrange,
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideX(begin: -0.1);
  }
}
