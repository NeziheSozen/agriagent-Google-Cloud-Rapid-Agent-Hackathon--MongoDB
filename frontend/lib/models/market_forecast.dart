/// Price forecast for a single crop.
class CropPriceForecast {
  final String crop;
  final String currency;
  final double priceTodayPerTon;
  final double price1WeekAgoPerTon;
  final double price1MonthAgoPerTon;
  final double price1YearAgoPerTon;

  const CropPriceForecast({
    required this.crop,
    required this.currency,
    required this.priceTodayPerTon,
    required this.price1WeekAgoPerTon,
    required this.price1MonthAgoPerTon,
    required this.price1YearAgoPerTon,
  });

  factory CropPriceForecast.fromJson(Map<String, dynamic> json) {
    final res = CropPriceForecast(
      crop: json['crop'] as String,
      currency: json['currency'] as String? ?? 'TRY',
      priceTodayPerTon: (json['price_today_per_ton'] as num?)?.toDouble() ?? 0.0,
      price1WeekAgoPerTon:
          (json['price_1_week_ago_per_ton'] as num?)?.toDouble() ?? 0.0,
      price1MonthAgoPerTon:
          (json['price_1_month_ago_per_ton'] as num?)?.toDouble() ?? 0.0,
      price1YearAgoPerTon:
          (json['price_1_year_ago_per_ton'] as num?)?.toDouble() ?? 0.0,
    );
    print('DEBUG PARSED: ${res.crop} -> ${res.priceTodayPerTon} (Raw: ${json['price_today_per_ton']} type: ${json['price_today_per_ton'].runtimeType})');
    return res;
  }

  Map<String, dynamic> toJson() => {
        'crop': crop,
        'currency': currency,
        'price_today_per_ton': priceTodayPerTon,
        'price_1_week_ago_per_ton': price1WeekAgoPerTon,
        'price_1_month_ago_per_ton': price1MonthAgoPerTon,
        'price_1_year_ago_per_ton': price1YearAgoPerTon,
      };
}

/// Market forecast response containing multiple crop predictions.
class MarketForecast {
  final String forecastDate;
  final String season;
  final List<CropPriceForecast> predictions;
  final List<String> dataSources;

  const MarketForecast({
    required this.forecastDate,
    required this.season,
    required this.predictions,
    required this.dataSources,
  });

  factory MarketForecast.fromJson(Map<String, dynamic> json) {
    return MarketForecast(
      forecastDate: json['forecast_date'] as String,
      season: json['season'] as String,
      predictions: (json['predictions'] as List<dynamic>)
          .map((e) =>
              CropPriceForecast.fromJson(e as Map<String, dynamic>))
          .toList(),
      dataSources: (json['data_sources'] as List<dynamic>)
          .map((e) => e as String)
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'forecast_date': forecastDate,
        'season': season,
        'predictions': predictions.map((e) => e.toJson()).toList(),
        'data_sources': dataSources,
      };
}

/// Request body for the market forecast endpoint.
class CropForecastRequest {
  final List<String> crops;
  final String? location;
  final String? country;

  const CropForecastRequest({
    required this.crops,
    this.location,
    this.country,
  });

  Map<String, dynamic> toJson() => {
        'crops': crops,
        if (location != null) 'location': location,
        if (country != null) 'country': country,
      };
}
