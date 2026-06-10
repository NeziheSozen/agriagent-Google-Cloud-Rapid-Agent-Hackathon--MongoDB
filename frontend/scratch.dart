import 'dart:convert';

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
    return CropPriceForecast(
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
  }
}

void main() {
  final jsonStr = '{"crop":"Tomato","currency":"TRY","price_today_per_ton":6796.0,"price_1_week_ago_per_ton":6674.0,"price_1_month_ago_per_ton":6781.0,"price_1_year_ago_per_ton":4189.0}';
  final json = jsonDecode(jsonStr);
  final obj = CropPriceForecast.fromJson(json);
  print('Price today: ${obj.priceTodayPerTon}');
}
