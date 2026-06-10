import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import '../app/theme.dart';
import '../models/farmer_profile.dart';
import '../widgets/glass_card.dart';
import '../app/l10n/translations.dart';

final urgencyProvider = FutureProvider.family<List<dynamic>, String>((ref, userId) async {
  if (userId.isEmpty || userId == 'guest') return [];
  final url = Uri.parse('https://agriagent-backend-385185579211.us-central1.run.app/agent/urgency/$userId');
  try {
    final response = await http.get(url);
    if (response.statusCode == 200) {
      return jsonDecode(utf8.decode(response.bodyBytes)) as List<dynamic>;
    }
  } catch (e) {
    debugPrint('Failed to load urgency radar: $e');
  }
  return [];
});

class UrgencyRadarCard extends ConsumerWidget {
  final FarmerProfile farmer;

  const UrgencyRadarCard({super.key, required this.farmer});

  Color _parseColor(String? colorStr) {
    if (colorStr == null) return Colors.grey;
    if (colorStr.startsWith('#')) {
      try {
        return Color(int.parse(colorStr.substring(1, 7), radix: 16) + 0xFF000000);
      } catch (e) {
        return Colors.blue;
      }
    }
    switch (colorStr.toLowerCase()) {
      case 'red': return Colors.redAccent;
      case 'orange': return Colors.orange;
      case 'green': return Colors.green;
      case 'warningorange': return AgriAgentTheme.warningOrange;
      default: return Colors.blue;
    }
  }

  IconData _parseIcon(String? iconStr) {
    switch (iconStr) {
      case 'warning_amber_rounded': return Icons.warning_amber_rounded;
      case 'water_drop_outlined': return Icons.water_drop_outlined;
      case 'bolt': return Icons.bolt;
      case 'check_circle_outline': return Icons.check_circle_outline;
      case 'pest_control': return Icons.pest_control;
      case 'thermostat': return Icons.thermostat;
      default: return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (farmer.plots.isEmpty) return const SizedBox.shrink();

    final urgencyAsyncValue = ref.watch(urgencyProvider(farmer.userId));

    return GlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.radar, color: Colors.redAccent, size: 24),
              const SizedBox(width: 8),
              Text(
                L10n.tr(context, 'radar_title') ?? "Risk ve Aciliyet Radarı",
                style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withOpacity(0.5)),
                ),
                child: Text(
                  L10n.tr(context, 'radar_badge') ?? "Gerçek Zamanlı Yapay Zeka",
                  style: const TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            L10n.tr(context, 'radar_subtitle') ?? "Tarlalarınızın meteorolojik ve biyolojik güncel durumu:",
            style: const TextStyle(fontSize: 13, color: Colors.grey),
          ),
          const SizedBox(height: 12),
          urgencyAsyncValue.when(
            data: (urgentData) {
              if (urgentData.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(L10n.tr(context, 'radar_no_threat') ?? "Şu an analiz edilecek bir tehdit bulunmuyor.", style: const TextStyle(color: Colors.grey)),
                );
              }
              // Sort by score descending
              urgentData.sort((a, b) => ((b['score'] ?? 0) as int).compareTo((a['score'] ?? 0) as int));

              return ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: urgentData.length,
                separatorBuilder: (_, __) => const Divider(),
                itemBuilder: (context, index) {
                  final data = urgentData[index];
                  final plotId = data['plot_id'];
                  final plot = farmer.plots.firstWhere((p) => p.plotId == plotId, orElse: () => farmer.plots.first);
                  final score = data['score'] ?? 0;
                  final reason = data['reason'] ?? L10n.tr(context, 'radar_analyzed') ?? 'Analiz edildi';
                  final color = _parseColor(data['color']);
                  final icon = _parseIcon(data['icon']);

                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: CircleAvatar(
                      backgroundColor: color.withOpacity(0.1),
                      child: Icon(icon, color: color),
                    ),
                    title: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(plot.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          "${L10n.tr(context, 'radar_score') ?? 'Skor'}: $score/100",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: color,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                    subtitle: Padding(
                      padding: const EdgeInsets.only(top: 4.0),
                      child: Text(
                        reason,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                    trailing: const Icon(Icons.chevron_right, color: Colors.grey),
                  );
                },
              );
            },
            loading: () => Center(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    const CircularProgressIndicator(strokeWidth: 2),
                    const SizedBox(height: 8),
                    Text(L10n.tr(context, 'radar_loading') ?? "Gerçek verilerle Yapay Zeka analizi yapılıyor...", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                  ],
                ),
              ),
            ),
            error: (err, stack) => Text('${L10n.tr(context, 'radar_error') ?? "Veri yüklenemedi:"} $err', style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}
