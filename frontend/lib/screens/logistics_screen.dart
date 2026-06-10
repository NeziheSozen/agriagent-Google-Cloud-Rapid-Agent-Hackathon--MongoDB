import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../app/theme.dart';
import '../widgets/glass_card.dart';
import '../services/agent_api.dart';

class LogisticsScreen extends ConsumerStatefulWidget {
  const LogisticsScreen({super.key});

  @override
  ConsumerState<LogisticsScreen> createState() => _LogisticsScreenState();
}

class _LogisticsScreenState extends ConsumerState<LogisticsScreen> {
  final List<Map<String, dynamic>> _carriers = [
    {
      "name": "Soğuk Zincir Lojistik",
      "type": "Soğutmalı Kamyon",
      "capacity": "15 Ton",
      "speed": "Hızlı",
      "cost": "Yüksek",
      "recommendedFor": ["Domates", "Biber", "Çilek"],
      "rating": 4.8
    },
    {
      "name": "Bölgesel Nakliyat",
      "type": "Standart Kamyon",
      "capacity": "20 Ton",
      "speed": "Orta",
      "cost": "Orta",
      "recommendedFor": ["Patates", "Soğan"],
      "rating": 4.2
    },
    {
      "name": "Anadolu Tır Filosu",
      "type": "Büyük Tır",
      "capacity": "30 Ton",
      "speed": "Yavaş",
      "cost": "Düşük",
      "recommendedFor": ["Buğday", "Arpa", "Mısır"],
      "rating": 4.5
    },
    {
      "name": "Hızlı Ekspres Kamyonet",
      "type": "Açık Kasa Kamyonet",
      "capacity": "5 Ton",
      "speed": "Çok Hızlı",
      "cost": "Orta",
      "recommendedFor": ["Küçük Parti Hasat", "Günlük Sebze"],
      "rating": 4.9
    }
  ];

  String _selectedCrop = "Domates";
  final List<String> _myCrops = ["Domates", "Buğday", "Patates"];

  bool _isAnalyzing = false;
  String _aiAnalysis = "Yapay zeka analizini görmek için bir ürün seçin.";

  @override
  void initState() {
    super.initState();
    // Run initial analysis
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _analyzeCrop(_selectedCrop);
    });
  }

  void _analyzeCrop(String crop) async {
    setState(() {
      _selectedCrop = crop;
      _isAnalyzing = true;
    });

    try {
      final advice = await ref.read(agentApiProvider).getLogisticsAdvice(crop);
      if (!mounted) return;
      setState(() {
        _aiAnalysis = advice;
        _isAnalyzing = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _aiAnalysis = "Analiz sırasında bir hata oluştu: \$e";
        _isAnalyzing = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // Sort carriers: put recommended ones first
    final sortedCarriers = List<Map<String, dynamic>>.from(_carriers);
    sortedCarriers.sort((a, b) {
      final aRec = (a["recommendedFor"] as List).contains(_selectedCrop) ? 1 : 0;
      final bRec = (b["recommendedFor"] as List).contains(_selectedCrop) ? 1 : 0;
      return bRec.compareTo(aRec);
    });

    return Scaffold(
      appBar: AppBar(
        title: const Text("Taşıyıcı ve Araç Seçim Kataloğu"),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                const Text("Hangi mahsulü taşıyacaksınız?", style: TextStyle(fontSize: 16)),
                const SizedBox(width: 16),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCrop,
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    items: _myCrops.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) {
                      if (val != null && val != _selectedCrop) {
                        _analyzeCrop(val);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          if (_isAnalyzing)
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Center(
                child: Column(
                  children: [
                    CircularProgressIndicator(),
                    SizedBox(height: 8),
                    Text("Yapay Zeka lojistik ağını analiz ediyor..."),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              child: GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.auto_awesome, color: AgriAgentTheme.mossGreen, size: 28),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text("AI Lojistik Analizi", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                            const SizedBox(height: 8),
                            Text(_aiAnalysis, style: const TextStyle(fontSize: 14)),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 8),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16.0),
            child: Text("Bölgenizdeki Taşıyıcılar", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              itemCount: sortedCarriers.length,
              itemBuilder: (context, index) {
                final carrier = sortedCarriers[index];
                final isRecommended = (carrier["recommendedFor"] as List).contains(_selectedCrop);

                return Padding(
                  padding: const EdgeInsets.only(bottom: 12.0),
                  child: GlassCard(
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                carrier["type"].contains("Soğutmalı") ? Icons.ac_unit : Icons.local_shipping,
                                color: AgriAgentTheme.infoBlue,
                                size: 28,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  carrier["name"],
                                  style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                                ),
                              ),
                              Row(
                                children: [
                                  const Icon(Icons.star, color: AgriAgentTheme.harvestGold, size: 18),
                                  Text(" ${carrier["rating"]}", style: const TextStyle(fontWeight: FontWeight.bold)),
                                ],
                              )
                            ],
                          ),
                          if (isRecommended) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                              decoration: BoxDecoration(
                                color: AgriAgentTheme.successGreen.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: AgriAgentTheme.successGreen),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(Icons.psychology_rounded, color: AgriAgentTheme.successGreen, size: 16),
                                  const SizedBox(width: 6),
                                  Text("Yapay Zeka Önerisi: $_selectedCrop için en uygun", style: const TextStyle(color: AgriAgentTheme.successGreen, fontSize: 12, fontWeight: FontWeight.bold)),
                                ],
                              ),
                            ),
                          ],
                          const SizedBox(height: 16),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              _buildInfoCol("Kapasite", carrier["capacity"]),
                              _buildInfoCol("Hız", carrier["speed"]),
                              _buildInfoCol("Maliyet", carrier["cost"]),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }

  Widget _buildInfoCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }
}
