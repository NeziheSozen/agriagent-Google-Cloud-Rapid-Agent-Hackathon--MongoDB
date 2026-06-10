/// A single crop recommendation within a strategy report.
class CropOption {
  final int rank;
  final String crop;
  final double expectedYieldTonsPerHectare;
  final double estimatedRevenue;
  final double estimatedCost;
  final double estimatedProfit;
  final double riskScore;
  final List<String> riskFactors;
  final String rotationBenefit;

  const CropOption({
    required this.rank,
    required this.crop,
    required this.expectedYieldTonsPerHectare,
    required this.estimatedRevenue,
    required this.estimatedCost,
    required this.estimatedProfit,
    required this.riskScore,
    required this.riskFactors,
    required this.rotationBenefit,
  });

  factory CropOption.fromJson(Map<String, dynamic> json) {
    return CropOption(
      rank: json['rank'] as int,
      crop: json['crop'] as String,
      expectedYieldTonsPerHectare:
          (json['expected_yield_tons_per_hectare'] as num).toDouble(),
      estimatedRevenue:
          (json['estimated_revenue'] as num).toDouble(),
      estimatedCost:
          (json['estimated_cost'] as num).toDouble(),
      estimatedProfit:
          (json['estimated_profit'] as num).toDouble(),
      riskScore: (json['risk_score'] as num).toDouble(),
      riskFactors: (json['risk_factors'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
      rotationBenefit: json['rotation_benefit'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'rank': rank,
        'crop': crop,
        'expected_yield_tons_per_hectare': expectedYieldTonsPerHectare,
        'estimated_revenue': estimatedRevenue,
        'estimated_cost': estimatedCost,
        'estimated_profit': estimatedProfit,
        'risk_score': riskScore,
        'risk_factors': riskFactors,
        'rotation_benefit': rotationBenefit,
      };
}

/// Full strategy report produced by the AgriAgent advisory engine.
class StrategyReport {
  final String userId;
  final String currencySymbol;
  final String season;
  final String farmSummary;
  final String rotationAnalysis;
  final String climateAssessment;
  final String threatAssessment;
  final String marketOutlook;
  final String sustainabilityAnalysis;
  final String insuranceRecommendations;
  final List<CropOption> recommendations;
  final String finalRecommendation;
  final String createdAt;

  const StrategyReport({
    required this.userId,
    required this.currencySymbol,
    required this.season,
    required this.farmSummary,
    required this.rotationAnalysis,
    required this.climateAssessment,
    required this.threatAssessment,
    required this.marketOutlook,
    this.sustainabilityAnalysis = '',
    this.insuranceRecommendations = '',
    required this.recommendations,
    required this.finalRecommendation,
    required this.createdAt,
  });

  factory StrategyReport.fromJson(Map<String, dynamic> json) {
    return StrategyReport(
      userId: json['user_id'] as String,
      currencySymbol: json['currency_symbol'] as String? ?? '\$',
      season: json['season'] as String,
      farmSummary: json['farm_summary'] as String,
      rotationAnalysis: json['rotation_analysis'] as String,
      climateAssessment: json['climate_assessment'] as String,
      threatAssessment: json['threat_assessment'] as String,
      marketOutlook: json['market_outlook'] as String,
      sustainabilityAnalysis: (json['sustainability_analysis'] as String?) ?? '',
      insuranceRecommendations: (json['insurance_recommendations'] as String?) ?? '',
      recommendations: (json['recommendations'] as List<dynamic>)
          .map((e) => CropOption.fromJson(e as Map<String, dynamic>))
          .toList(),
      finalRecommendation: json['final_recommendation'] as String,
      createdAt: json['created_at'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'user_id': userId,
      'currency_symbol': currencySymbol,
        'season': season,
        'farm_summary': farmSummary,
        'rotation_analysis': rotationAnalysis,
        'climate_assessment': climateAssessment,
        'threat_assessment': threatAssessment,
        'market_outlook': marketOutlook,
        'sustainability_analysis': sustainabilityAnalysis,
        'insurance_recommendations': insuranceRecommendations,
        'recommendations': recommendations.map((e) => e.toJson()).toList(),
        'final_recommendation': finalRecommendation,
        'created_at': createdAt,
      };
}
