import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../utils/app_logger.dart';
import '../utils/crop_translator.dart';

import '../models/market_forecast.dart';
import '../providers/farmer_provider.dart';
import '../services/market_api.dart';
import 'shared_prefs_provider.dart';
import 'locale_provider.dart';

part 'market_provider.g.dart';

/// Crop list used for market forecast requests.
@Riverpod(keepAlive: true)
class SelectedCrops extends _$SelectedCrops {
  @override
  List<String> build() {
    return ['wheat', 'barley', 'corn']; // Default fallback if no profile
  }

  void set(List<String> crops) => state = crops;
}

/// Sort criteria for market forecast display.
enum MarketSortCriteria {
  crop, price
}

/// Sort provider for market screen.
@Riverpod(keepAlive: true)
class MarketSort extends _$MarketSort {
  @override
  MarketSortCriteria build() => MarketSortCriteria.crop;

  void set(MarketSortCriteria criteria) => state = criteria;
}

class MarketSearchNotifier extends Notifier<String> {
  @override
  String build() => '';

  void set(String query) => state = query;
}

final marketSearchProvider = NotifierProvider<MarketSearchNotifier, String>(MarketSearchNotifier.new);

/// Fetches market forecast for the selected crops.
@riverpod
Future<MarketForecast> marketForecast(Ref ref) async {
  AppTracker.info('Provider build: market_provider.dart');

  // User feedback: "why should I only see what I harvest? I want to see all crops."
  // We will now request the full baseline of all Turkish wholesale commodities.
  List<String> crops = [
    'Tomato', 'Wheat', 'Corn', 'Cotton', 'Sunflower', 'Lettuce', 'Pepper', 'Green Bean',
    'Barley', 'Rice', 'Soybean', 'Canola', 'Potato', 'Eggplant', 'Cucumber',
    'Grape', 'Orange', 'Lemon', 'Chickpea', 'Lentil', 'Oat', 'Carrot', 'Onion',
    'Garlic', 'Cabbage', 'Spinach', 'Zucchini', 'Watermelon', 'Melon', 'Cherry',
    'Peach', 'Pear', 'Plum', 'Olive', 'Walnut', 'Hazelnut', 'Fig', 'Pomegranate',
    'Apricot', 'Sugar Beet', 'Strawberry', 'Banana', 'Raspberry', 'Asparagus',
    'Broccoli', 'Cauliflower', 'Celery', 'Pea', 'Radish', 'Artichoke', 'Leek',
    'Kiwi', 'Mango', 'Avocado', 'Pineapple', 'Blueberry', 'Blackberry', 'Almond',
    'Pistachio', 'Peanut', 'Chestnut', 'Sesame', 'Tea', 'Coffee', 'Cocoa'
  ];

  final api = ref.read(marketApiProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final cacheKey = 'cache_market_forecast';
  final farmer = ref.watch(currentFarmerProvider).value;

  try {
    final locStr = farmer?.location;
    var data = await api.getForecast(CropForecastRequest(
      crops: crops,
      location: locStr,
    ));
    
    // Cache it
    await prefs.setString(cacheKey, jsonEncode(data.toJson()));
    await prefs.setString('${cacheKey}_timestamp', DateTime.now().toIso8601String());
    return data;
  } catch (e) {
    AppTracker.warn('Failed to fetch market forecast, trying cache. Error: $e');
    final cached = prefs.getString(cacheKey);
    if (cached != null) {
      AppTracker.info('Using cached market data from: ${prefs.getString('${cacheKey}_timestamp')}');
      return MarketForecast.fromJson(jsonDecode(cached));
    }
    rethrow;
  }
}

/// Sorted predictions based on the selected sort criteria.
@riverpod
AsyncValue<List<CropPriceForecast>> sortedPredictions(Ref ref) {
  final forecastAsync = ref.watch(marketForecastProvider);
  final sort = ref.watch(marketSortProvider);
  final query = ref.watch(marketSearchProvider).toLowerCase();
  final locale = ref.watch(localeProvider)?.languageCode ?? 'en';

  return forecastAsync.whenData((forecast) {
    var list = List<CropPriceForecast>.from(forecast.predictions);
    
    if (query.isNotEmpty) {
      list = list.where((p) => CropTranslator.translate(p.crop, locale: locale).toLowerCase().contains(query)).toList();
    }

    switch (sort) {
      case MarketSortCriteria.crop:
        list.sort((a, b) => CropTranslator.translate(a.crop, locale: locale).compareTo(CropTranslator.translate(b.crop, locale: locale)));
        break;
      case MarketSortCriteria.price:
        list.sort((a, b) => b.priceTodayPerTon
            .compareTo(a.priceTodayPerTon));
        break;
    }
    return list;
  });
}
