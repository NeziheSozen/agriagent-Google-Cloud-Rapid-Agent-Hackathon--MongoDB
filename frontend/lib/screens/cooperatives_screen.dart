import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/farmer_provider.dart';
import '../services/farmer_api.dart';
import '../services/api_client.dart';
import '../app/theme.dart';
import '../app/l10n/translations.dart';
import '../widgets/glass_card.dart';
import '../providers/offline_queue_provider.dart';
import '../providers/cooperative_provider.dart';

class CooperativesScreen extends ConsumerStatefulWidget {
  const CooperativesScreen({super.key});

  @override
  ConsumerState<CooperativesScreen> createState() => _CooperativesScreenState();
}

class _CooperativesScreenState extends ConsumerState<CooperativesScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _coops = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchCoops();
    });
  }

  Future<void> _fetchCoops() async {
    setState(() => _isLoading = true);
    try {
      final farmer = ref.read(currentFarmerProvider).value;
      double lat = 36.8969;
      double lon = 30.7133;

      if (farmer?.locationGeo != null && farmer!.locationGeo!['coordinates'] != null) {
        lon = farmer.locationGeo!['coordinates'][0];
        lat = farmer.locationGeo!['coordinates'][1];
      }

      final api = ref.read(farmerApiProvider);
      final results = await api.getNearbyCooperatives(lat, lon);
      if (mounted) {
        setState(() => _coops = results);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${L10n.tr(context, 'error_generic')}: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showCreateCoopSheet(BuildContext context) {
    final nameController = TextEditingController();
    final regionController = TextEditingController();
    final descController = TextEditingController();
    bool isSubmitting = false;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(ctx).viewInsets.bottom,
                left: 24,
                right: 24,
                top: 24,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.tr(context, 'create_new_cooperative'), style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  TextField(
                    controller: nameController,
                    decoration: const InputDecoration(labelText: 'Cooperative Name', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: regionController,
                    decoration: const InputDecoration(labelText: 'Region / City', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: descController,
                    decoration: const InputDecoration(labelText: 'Description', border: OutlineInputBorder()),
                    maxLines: 3,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: isSubmitting ? null : () async {
                        if (nameController.text.isEmpty || regionController.text.isEmpty) return;
                        setModalState(() => isSubmitting = true);
                        try {
                          final farmer = ref.read(currentFarmerProvider).value;
                          await createCooperative(
                            ref,
                            name: nameController.text,
                            region: regionController.text,
                            description: descController.text,
                            coopType: 'collective',
                            adminId: farmer?.userId ?? 'unknown',
                            adminName: farmer?.name ?? 'Unknown Farmer',
                          );
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.tr(context, 'cooperative_created'))));
                            _fetchCoops();
                          }
                        } catch (e) {
                          if (ctx.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${L10n.tr(context, 'error_generic')}: $e')));
                          }
                        } finally {
                          setModalState(() => isSubmitting = false);
                        }
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AgriAgentTheme.mossGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      child: isSubmitting 
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : Text(L10n.tr(context, 'complete_setup')),
                    ),
                  ),
                  const SizedBox(height: 24),
                ],
              ),
            );
          }
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(L10n.tr(context, 'community_cooperatives')),
        actions: [
          Consumer(
            builder: (context, ref, child) {
              final queue = ref.watch(offlineQueueProvider);
              if (queue.isEmpty) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AgriAgentTheme.warningOrange,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.cloud_off, size: 14, color: Colors.white),
                        const SizedBox(width: 4),
                        Text('${queue.length} Pending', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _fetchCoops,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateCoopSheet(context),
        icon: const Icon(Icons.add),
        label: Text(L10n.tr(context, 'create_cooperative')),
        backgroundColor: AgriAgentTheme.mossGreen,
        foregroundColor: Colors.white,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _coops.isEmpty
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.handshake_outlined, size: 64, color: Colors.grey),
                        const SizedBox(height: 16),
                        Text(L10n.tr(context, 'no_coops_found'), textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(L10n.tr(context, 'no_coops_desc'), textAlign: TextAlign.center, style: const TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                )
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _coops.length,
                  itemBuilder: (context, index) {
                    final coop = _coops[index];
                    final dist = coop['dist'] != null ? coop['dist']['calculated'] as double : 0.0;
                    return GlassCard(
                      child: ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: AgriAgentTheme.mossGreen,
                          child: Icon(Icons.handshake_rounded, color: Colors.white),
                        ),
                        title: Text(coop['name'] ?? 'Unknown Cooperative', style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(coop['description'] ?? ''),
                            const SizedBox(height: 4),
                            Text('${L10n.tr(context, 'distance_km')}: ${(dist / 1000).toStringAsFixed(1)} km', style: const TextStyle(color: AgriAgentTheme.infoBlue)),
                          ],
                        ),
                        trailing: OutlinedButton(
                          onPressed: () {
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(L10n.tr(context, 'join_request_sent'))));
                          },
                          child: Text(L10n.tr(context, 'join')),
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
