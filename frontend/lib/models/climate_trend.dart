/// A single year's climate summary (historical data).
class YearlyClimateSummary {
  final int year;
  final double avgSpringRainfallMm;
  final double avgSummerTempCelsius;
  final int droughtDays;
  final int frostDays;

  const YearlyClimateSummary({
    required this.year,
    required this.avgSpringRainfallMm,
    required this.avgSummerTempCelsius,
    required this.droughtDays,
    required this.frostDays,
  });

  factory YearlyClimateSummary.fromJson(Map<String, dynamic> json) {
    return YearlyClimateSummary(
      year: json['year'] as int,
      avgSpringRainfallMm:
          (json['avg_spring_rainfall_mm'] as num).toDouble(),
      avgSummerTempCelsius:
          (json['avg_summer_temp_celsius'] as num).toDouble(),
      droughtDays: json['drought_days'] as int,
      frostDays: json['frost_days'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
        'year': year,
        'avg_spring_rainfall_mm': avgSpringRainfallMm,
        'avg_summer_temp_celsius': avgSummerTempCelsius,
        'drought_days': droughtDays,
        'frost_days': frostDays,
      };
}

/// Forecast for an upcoming season.
class FutureForecast {
  final String season;
  final double predictedRainfallMm;
  final double predictedAvgTempCelsius;
  final String droughtRisk;
  final String trendSummary;

  const FutureForecast({
    required this.season,
    required this.predictedRainfallMm,
    required this.predictedAvgTempCelsius,
    required this.droughtRisk,
    required this.trendSummary,
  });

  factory FutureForecast.fromJson(Map<String, dynamic> json) {
    return FutureForecast(
      season: json['season'] as String,
      predictedRainfallMm:
          (json['predicted_rainfall_mm'] as num).toDouble(),
      predictedAvgTempCelsius:
          (json['predicted_avg_temp_celsius'] as num).toDouble(),
      droughtRisk: json['drought_risk'] as String,
      trendSummary: json['trend_summary'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'season': season,
        'predicted_rainfall_mm': predictedRainfallMm,
        'predicted_avg_temp_celsius': predictedAvgTempCelsius,
        'drought_risk': droughtRisk,
        'trend_summary': trendSummary,
      };
}

/// Full climate trend report for a location.
class ClimateTrend {
  final String location;
  final String region;
  final List<YearlyClimateSummary> historical;
  final FutureForecast forecast;
  final String analysisNotes;

  const ClimateTrend({
    required this.location,
    required this.region,
    required this.historical,
    required this.forecast,
    required this.analysisNotes,
  });

  factory ClimateTrend.fromJson(Map<String, dynamic> json) {
    return ClimateTrend(
      location: json['location'] as String,
      region: json['region'] as String,
      historical: (json['historical'] as List<dynamic>)
          .map((e) =>
              YearlyClimateSummary.fromJson(e as Map<String, dynamic>))
          .toList(),
      forecast:
          FutureForecast.fromJson(json['forecast'] as Map<String, dynamic>),
      analysisNotes: json['analysis_notes'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
        'location': location,
        'region': region,
        'historical': historical.map((e) => e.toJson()).toList(),
        'forecast': forecast.toJson(),
        'analysis_notes': analysisNotes,
      };
}
