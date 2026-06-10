import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../app/responsive.dart';
import '../app/theme.dart';
import '../widgets/edit_plot_dialog.dart';
import '../providers/farmer_provider.dart';
import '../widgets/glass_card.dart';
import '../widgets/crop_timeline.dart';
import '../widgets/shimmer_loading.dart';
import '../app/l10n/translations.dart';
import '../models/farmer_profile.dart';
import 'package:image_picker/image_picker.dart';
import '../services/farmer_api.dart';
import 'package:fl_chart/fl_chart.dart';

/// Farmer profile & rotation analysis screen.
class FarmerScreen extends ConsumerWidget {
  const FarmerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farmerAsync = ref.watch(currentFarmerProvider);

    return Scaffold(
      body: SafeArea(
        child: farmerAsync.when(
          loading: () => Padding(
            padding: context.responsivePadding,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 24),
                ShimmerLoading.box(width: 200, height: 28),
                const SizedBox(height: 24),
                ShimmerLoading.card(height: 180),
                const SizedBox(height: 16),
                ShimmerLoading.card(height: 200),
              ],
            ),
          ),
          error: (error, _) => Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AgriAgentTheme.errorRed, size: 48),
                const SizedBox(height: 16),
                Text('${L10n.tr(context, 'error_generic')}: $error',
                    style: Theme.of(context).textTheme.bodyMedium),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => ref.invalidate(currentFarmerProvider),
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(L10n.tr(context, 'retry')),
                ),
              ],
            ),
          ),
          data: (farmer) => CustomScrollView(
            slivers: [
              SliverAppBar(
                floating: true,
                backgroundColor: Colors.transparent,
                title: Text(L10n.tr(context, 'my_fields'), style: const TextStyle(fontWeight: FontWeight.bold)),
                actions: [
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: GestureDetector(
                      onTap: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.transparent,
                          builder: (ctx) => Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: _ProfileCard(farmer: farmer),
                          ),
                        );
                      },
                      child: Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          gradient: AgriAgentTheme.primaryGradient,
                          shape: BoxShape.circle,
                        ),
                        child: Center(
                          child: Text(
                            farmer.name.isNotEmpty ? farmer.name[0].toUpperCase() : '?',
                            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              SliverPadding(
                padding: context.responsivePadding,
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    if (farmer.plots.isNotEmpty)
                      ...farmer.plots.asMap().entries.map((entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 16),
                            child: _PlotCard(
                              plot: entry.value,
                              plotIndex: entry.key,
                              userId: farmer.userId,
                            ),
                          )),
                    const SizedBox(height: 32),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProfileCard extends ConsumerWidget {
  final FarmerProfile farmer;

  const _ProfileCard({required this.farmer});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GlassCard(
      child: Column(
        children: [
          Row(
            children: [
              // Avatar
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  gradient: AgriAgentTheme.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(
                    farmer.name.isNotEmpty
                        ? farmer.name[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      farmer.name,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      farmer.userId,
                      style: Theme.of(context)
                          .textTheme
                          .bodySmall
                          ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Divider(color: Theme.of(context).dividerColor),
          const SizedBox(height: 16),

          _InfoRow(
              icon: Icons.location_on_rounded,
              label: 'Location',
              value: '${farmer.location}, ${farmer.region}'),
          const SizedBox(height: 12),
          _InfoRow(
              icon: Icons.landscape_rounded,
              label: L10n.tr(context, 'farm_size'),
              value: L10n.formatFarmSize(context, farmer.plots.fold<double>(0.0, (s, p) => s + p.sizeHectares))),
          const SizedBox(height: 12),
          _InfoRow(
              icon: Icons.layers_rounded,
              label: 'Parcels',
              value: '${farmer.plots.length} plots'),
          const SizedBox(height: 12),
          _InfoRow(
              icon: Icons.calendar_today_rounded,
              label: 'Registered',
              value: farmer.createdAt),
          if (farmer.crops.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.grass_rounded, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                const SizedBox(width: 12),
                SizedBox(
                  width: 90,
                  child: Text(
                    'Crops',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  ),
                ),
                Expanded(
                  child: Wrap(
                    spacing: 6,
                    runSpacing: 4,
                    children: farmer.crops.map((crop) => Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: AgriAgentTheme.mossGreen.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        crop,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AgriAgentTheme.mossGreen,
                        ),
                      ),
                    )).toList(),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context); // Close bottom sheet
                context.push('/profile/edit');
              },
              icon: const Icon(Icons.edit_rounded, size: 18),
              label: Text(L10n.tr(context, 'edit_profile')),
              style: OutlinedButton.styleFrom(
                foregroundColor: AgriAgentTheme.mossGreen,
                side: BorderSide(color: AgriAgentTheme.mossGreen.withOpacity(0.4)),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PlotCard extends ConsumerStatefulWidget {
  final FarmPlot plot;
  final int plotIndex;
  final String userId;

  const _PlotCard({
    required this.plot,
    required this.plotIndex,
    required this.userId,
  });

  @override
  ConsumerState<_PlotCard> createState() => _PlotCardState();
}

class _PlotCardState extends ConsumerState<_PlotCard> {
  bool _isUploading = false;
  bool _isSyncing = false;
  bool _isScanningLcd = false;

  Future<void> _syncOpenMeteo() async {
    setState(() => _isSyncing = true);
    try {
      final api = ref.read(farmerApiProvider);
      final farmer = ref.read(currentFarmerProvider).value!;
      
      // We need a fallback coordinate if farmer location_geo is null, but for this demo let's assume Antalya
      double lat = 36.8969;
      double lon = 30.7133;
      
      if (farmer.locationGeo != null && farmer.locationGeo!['coordinates'] != null) {
        lon = farmer.locationGeo!['coordinates'][0];
        lat = farmer.locationGeo!['coordinates'][1];
      }
      
      final result = await api.syncOpenMeteoData(widget.plot.plotId, lat, lon);
      final data = result['data'] as Map<String, dynamic>;
      
      // Fetch historical trend
      final trendData = await api.getSensorTrend(widget.plot.plotId);
      
      if (mounted) {
        _showTrendDialog(data, trendData);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${L10n.tr(context, 'sync_error')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isSyncing = false);
    }
  }

  void _showTrendDialog(Map<String, dynamic> currentData, List<Map<String, dynamic>> trendData) {
    // Sort trend data chronologically (oldest first)
    final sorted = List<Map<String, dynamic>>.from(trendData);
    sorted.sort((a, b) {
      final aId = a['_id'] as Map<String, dynamic>;
      final bId = b['_id'] as Map<String, dynamic>;
      final aDate = DateTime(aId['year'] as int, aId['month'] as int, aId['day'] as int);
      final bDate = DateTime(bId['year'] as int, bId['month'] as int, bId['day'] as int);
      return aDate.compareTo(bDate);
    });

    final dayLabels = <String>[];
    for (final item in sorted) {
      final id = item['_id'] as Map<String, dynamic>;
      dayLabels.add('${id['day']}/${id['month']}');
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          height: MediaQuery.of(context).size.height * 0.75,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.satellite_alt_rounded, color: AgriAgentTheme.infoBlue),
                  const SizedBox(width: 8),
                  Expanded(child: Text(L10n.tr(context, 'satellite_data_title'), style: Theme.of(context).textTheme.titleLarge)),
                  IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatBox(context, 'Temperature', '${currentData['temperature']} °C'),
                  _buildStatBox(context, 'Humidity', '%${currentData['humidity']}'),
                  _buildStatBox(context, 'Soil Moisture', '%${currentData['soil_moisture']}'),
                ],
              ),
              const SizedBox(height: 24),
              Text(L10n.tr(context, 'soil_moisture_trend'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 12),
              Expanded(
                child: sorted.isEmpty
                  ? Center(child: Text(L10n.tr(context, 'no_historical_data')))
                  : LineChart(
                      LineChartData(
                        gridData: FlGridData(
                          show: true,
                          drawVerticalLine: false,
                          horizontalInterval: 5,
                          getDrawingHorizontalLine: (value) => FlLine(
                            color: Colors.grey.withOpacity(0.15),
                            strokeWidth: 1,
                          ),
                        ),
                        titlesData: FlTitlesData(
                          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 30,
                              interval: 1,
                              getTitlesWidget: (value, meta) {
                                final idx = value.toInt();
                                if (idx >= 0 && idx < dayLabels.length) {
                                  return Padding(
                                    padding: const EdgeInsets.only(top: 8),
                                    child: Text(dayLabels[idx], style: const TextStyle(fontSize: 10, color: Colors.grey)),
                                  );
                                }
                                return const SizedBox.shrink();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 40,
                              getTitlesWidget: (value, meta) {
                                return Text('%${value.toInt()}', style: const TextStyle(fontSize: 10, color: Colors.grey));
                              },
                            ),
                          ),
                        ),
                        borderData: FlBorderData(show: false),
                        lineBarsData: [
                          LineChartBarData(
                            spots: sorted.asMap().entries.map((e) {
                              return FlSpot(e.key.toDouble(), (e.value['avg_moisture'] as num).toDouble());
                            }).toList(),
                            isCurved: true,
                            color: AgriAgentTheme.mossGreen,
                            barWidth: 3,
                            isStrokeCapRound: true,
                            dotData: FlDotData(
                              show: true,
                              getDotPainter: (spot, percent, barData, index) =>
                                FlDotCirclePainter(radius: 4, color: AgriAgentTheme.mossGreen, strokeWidth: 2, strokeColor: Colors.white),
                            ),
                            belowBarData: BarAreaData(
                              show: true,
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [AgriAgentTheme.mossGreen.withOpacity(0.3), AgriAgentTheme.mossGreen.withOpacity(0.0)],
                              ),
                            ),
                          ),
                        ],
                        lineTouchData: LineTouchData(
                          touchTooltipData: LineTouchTooltipData(
                            getTooltipItems: (touchedSpots) {
                              return touchedSpots.map((spot) {
                                final idx = spot.x.toInt();
                                final label = idx < dayLabels.length ? dayLabels[idx] : '';
                                return LineTooltipItem(
                                  '$label\n%${spot.y.toStringAsFixed(1)}',
                                  const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                );
                              }).toList();
                            },
                          ),
                        ),
                      ),
                    ),
              ),
              const SizedBox(height: 12),
              Center(
                child: Text(
                  'Actual data from Open-Meteo satellite for the last 7 days',
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatBox(BuildContext context, String label, String value) {
    return Column(
      children: [
        Text(value, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AgriAgentTheme.mossGreen, fontWeight: FontWeight.bold)),
        Text(label, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }

  Future<void> _pickAndUpload() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file == null) return;

    setState(() => _isUploading = true);
    try {
      final api = ref.read(farmerApiProvider);
      await api.uploadSoilReport(widget.userId, widget.plotIndex, file.path);
      ref.invalidate(currentFarmerProvider);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(L10n.tr(context, 'soil_updated'))),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${L10n.tr(context, 'upload_error')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<void> _scanLcdScreen() async {
    final picker = ImagePicker();
    
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Scan Sensor Screen',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Take a photo of your budget LCD moisture/pH meter.',
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _SourceButton(
                  icon: Icons.camera_alt_rounded,
                  label: 'Camera',
                  onTap: () => Navigator.pop(ctx, ImageSource.camera),
                ),
                _SourceButton(
                  icon: Icons.photo_library_rounded,
                  label: 'Gallery',
                  onTap: () => Navigator.pop(ctx, ImageSource.gallery),
                ),
              ],
            ),
          ],
        ),
      ),
    );

    if (source == null) return;

    final file = await picker.pickImage(source: source);
    if (file == null) return;

    setState(() => _isScanningLcd = true);
    try {
      final api = ref.read(farmerApiProvider);
      final result = await api.scanLcdSensor(widget.plot.plotId, file.path);
      
      ref.invalidate(currentFarmerProvider);

      if (mounted) {
        final type = result['sensor_type'] as String;
        final value = result['value'] as num;
        final unit = result['unit'] as String;
        
        String typeStr = type == 'ph' ? 'pH Value' : (type == 'moisture' ? 'Soil Moisture' : 'Temperature');
        
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            icon: const Icon(Icons.check_circle_rounded, color: AgriAgentTheme.successGreen, size: 48),
            title: Text(L10n.tr(context, 'scan_successful')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'AI successfully analyzed the measurement on the sensor screen.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: AgriAgentTheme.mossGreen.withOpacity(0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AgriAgentTheme.mossGreen.withOpacity(0.2)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(typeStr, style: const TextStyle(fontWeight: FontWeight.bold)),
                      Text('$value $unit', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: AgriAgentTheme.mossGreen)),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: Text(L10n.tr(context, 'close'), style: const TextStyle(color: AgriAgentTheme.mossGreen)),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${L10n.tr(context, 'error_generic')}: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isScanningLcd = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.grass_rounded, color: AgriAgentTheme.mossGreen),
              const SizedBox(width: 8),
              Text(
                widget.plot.name,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 8),
              IconButton(
                icon: const Icon(Icons.edit_rounded, size: 16),
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) => EditPlotDialog(
                      plot: widget.plot,
                      plotIndex: widget.plotIndex,
                      userId: ref.read(currentFarmerProvider).value!.userId,
                    ),
                  );
                },
                tooltip: 'Edit Plot',
                style: IconButton.styleFrom(
                  foregroundColor: AgriAgentTheme.mossGreen,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(24, 24),
                ),
              ),
              const Spacer(),
              if (widget.plot.soilAnalysis != null && !_isUploading)
                TextButton.icon(
                  onPressed: _pickAndUpload,
                  icon: const Icon(Icons.upload_file_rounded, size: 16),
                  label: Text(L10n.tr(context, 'update_soil'), style: const TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(
                    foregroundColor: AgriAgentTheme.mossGreen,
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          _InfoRow(
              icon: Icons.landscape_rounded,
              label: L10n.tr(context, 'farm_size'),
              value: L10n.formatFarmSize(context, widget.plot.sizeHectares)),
          const SizedBox(height: 8),
          _InfoRow(
              icon: Icons.water_drop_rounded,
              label: L10n.tr(context, 'irrigation'),
              value: L10n.trSeverity(context, widget.plot.irrigationLevel)),
          const SizedBox(height: 8),
          _InfoRow(
              icon: Icons.real_estate_agent_rounded,
              label: 'Tenure',
              value: widget.plot.tenureType),
          const SizedBox(height: 16),
          Divider(color: Theme.of(context).dividerColor.withOpacity(0.5)),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              Text(
                'Sensors & Measurements',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onSurface.withOpacity(0.8),
                    ),
              ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  // Satellite Monitoring
                  if (!_isSyncing && !_isScanningLcd && !_isUploading)
                    InkWell(
                      onTap: _syncOpenMeteo,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AgriAgentTheme.infoBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.satellite_alt_rounded, size: 16, color: AgriAgentTheme.infoBlue),
                            const SizedBox(width: 6),
                            Text(L10n.tr(context, 'satellite_monitor'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AgriAgentTheme.infoBlue)),
                          ],
                        ),
                      ),
                    ),
                  // Scan Sensor
                  if (!_isScanningLcd && !_isSyncing && !_isUploading)
                    InkWell(
                      onTap: _scanLcdScreen,
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AgriAgentTheme.mossGreen.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.camera_alt_rounded, size: 16, color: AgriAgentTheme.mossGreen),
                            const SizedBox(width: 6),
                            Text(L10n.tr(context, 'scan_sensor'), style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: AgriAgentTheme.mossGreen)),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (_isScanningLcd)
            Padding(
              padding: const EdgeInsets.only(bottom: 24),
              child: Center(
                child: Column(
                  children: [
                    const CircularProgressIndicator(color: AgriAgentTheme.mossGreen),
                    const SizedBox(height: 12),
                    Text(
                      'AI is scanning the sensor screen...',
                      style: TextStyle(color: AgriAgentTheme.mossGreen, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
          if (_isUploading)
            Center(
              child: Column(
                children: [
                  const CircularProgressIndicator(),
                  const SizedBox(height: 12),
                  Text(
                    'AI is scanning your report...',
                    style: TextStyle(color: Theme.of(context).colorScheme.primary),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            )
          else if (widget.plot.soilAnalysis != null) ...[
            InkWell(
              onTap: _pickAndUpload,
              borderRadius: BorderRadius.circular(16),
              child: _SoilAnalysisCard(soil: widget.plot.soilAnalysis!),
            ),
            const SizedBox(height: 24),
          ] else ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.science_outlined, size: 40, color: Theme.of(context).colorScheme.primary.withOpacity(0.5)),
                  const SizedBox(height: 12),
                  Text(L10n.tr(context, 'no_soil_data'), style: const TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(L10n.tr(context, 'scan_lab_desc'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _pickAndUpload,
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: Text(L10n.tr(context, 'scan_lab_report')),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
          ],
          if (widget.plot.cropHistory.isNotEmpty) ...[
            Text(
              'Crop Rotation History',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            CropTimeline(history: widget.plot.cropHistory),
            const SizedBox(height: 16),
            _CropHistoryTable(history: widget.plot.cropHistory),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
        const SizedBox(width: 12),
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: Theme.of(context)
                .textTheme
                .bodyMedium
                ?.copyWith(fontWeight: FontWeight.w500),
          ),
        ),
      ],
    );
  }
}

class _SoilAnalysisCard extends StatelessWidget {
  final SoilAnalysis soil;
  final VoidCallback? onTap;

  const _SoilAnalysisCard({required this.soil, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AgriAgentTheme.cropLegume.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.science_rounded,
                    color: AgriAgentTheme.cropLegume, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    L10n.tr(context, 'soil_analysis'),
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  Text(
                    'Test date: ${soil.testDate}',
                    style: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3), fontSize: 11),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Soil metrics grid
          Wrap(
            spacing: 16,
            runSpacing: 12,
            children: [
              _SoilMetric(
                label: 'pH',
                value: soil.ph.toStringAsFixed(1),
                color: _phColor(soil.ph),
              ),
              _SoilMetric(
                label: 'Nitrogen',
                value: '${soil.nitrogenPpm.toStringAsFixed(0)} ppm',
                color: AgriAgentTheme.mossGreen,
              ),
              _SoilMetric(
                label: 'Phosphorus',
                value: '${soil.phosphorusPpm.toStringAsFixed(0)} ppm',
                color: AgriAgentTheme.infoBlue,
              ),
              _SoilMetric(
                label: 'Potassium',
                value: '${soil.potassiumPpm.toStringAsFixed(0)} ppm',
                color: AgriAgentTheme.harvestGold,
              ),
              _SoilMetric(
                label: 'Organic Matter',
                value: '${soil.organicMatterPercent.toStringAsFixed(1)}%',
                color: AgriAgentTheme.cropCereal,
              ),
              _SoilMetric(
                label: 'Salinity',
                value: '${soil.salinityDsM.toStringAsFixed(1)} dS/m',
                color: AgriAgentTheme.warningOrange,
              ),
              _SoilMetric(
                label: 'Texture',
                value: soil.texture,
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _phColor(double ph) {
    if (ph >= 6.0 && ph <= 7.5) return AgriAgentTheme.successGreen;
    if (ph >= 5.5 && ph <= 8.0) return AgriAgentTheme.harvestGold;
    return AgriAgentTheme.errorRed;
  }
}

class _SoilMetric extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SoilMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.7),
              fontWeight: FontWeight.w500,
            ),
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
      ),
    );
  }
}

class _CropHistoryTable extends StatelessWidget {
  final List history;

  const _CropHistoryTable({required this.history});

  @override
  Widget build(BuildContext context) {
    if (history.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(color: Theme.of(context).dividerColor),
        const SizedBox(height: 12),
        Text(
          'Yield & Profit History',
          style: Theme.of(context)
              .textTheme
              .labelMedium
              ?.copyWith(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
        ),
        const SizedBox(height: 12),
        ...history.map((entry) {
          final color = AgriAgentTheme.cropTypeColor(entry.crop);
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: color,
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 40,
                  child: Text(
                    '${entry.year}',
                    style: TextStyle(
                        fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.4)),
                  ),
                ),
                Expanded(
                  child: Text(
                    entry.crop,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: color,
                    ),
                  ),
                ),
                Text(
                  '${entry.yieldTonsPerHectare.toStringAsFixed(1)} t/ha',
                  style: TextStyle(
                      fontSize: 12, color: Theme.of(context).colorScheme.onSurface.withOpacity(0.55)),
                ),
                const SizedBox(width: 16),
                Text(
                  '₺${_formatProfit(entry.profit)}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: entry.profit >= 0
                        ? AgriAgentTheme.successGreen
                        : AgriAgentTheme.errorRed,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  String _formatProfit(double value) {
    if (value.abs() >= 1000000) {
      return '${(value / 1000000).toStringAsFixed(1)}M';
    }
    if (value.abs() >= 1000) {
      return '${(value / 1000).toStringAsFixed(0)}K';
    }
    return value.toStringAsFixed(0);
  }
}

class _SourceButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SourceButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: 100,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withOpacity(0.05),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 32, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
          ],
        ),
      ),
    );
  }
}

