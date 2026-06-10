import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Service that fetches real crop/product images from Wikipedia.
///
/// Uses the Wikipedia REST API to get article thumbnails for crop names.
/// Results are cached in SharedPreferences for offline use and speed.
class CropImageService {
  static const _cachePrefix = 'crop_img_';
  static const _thumbWidth = 200;

  /// Wikipedia REST API endpoint for article summaries (includes thumbnail).
  static const _wikiBaseUrl = 'https://en.wikipedia.org/api/rest_v1/page/summary';

  /// Some crop names don't match Wikipedia article titles directly.
  /// This map provides the correct Wikipedia article title.
  static const Map<String, String> _wikiOverrides = {
    'corn': 'Maize',
    'rice': 'Rice',
    'bell pepper': 'Bell_pepper',
    'sweet potato': 'Sweet_potato',
    'green bean': 'Green_bean',
    'palm oil': 'Palm_oil',
    'sugar beet': 'Sugar_beet',
    'fava bean': 'Vicia_faba',
    'kidney bean': 'Kidney_bean',
    'black bean': 'Black_bean_(turtle_bean)',
    'mung bean': 'Mung_bean',
    'pigeon pea': 'Pigeon_pea',
    'pine nut': 'Pine_nut',
    'brazil nut': 'Brazil_nut',
    'bay leaf': 'Bay_leaf',
    'black pepper': 'Black_pepper',
    'dragon fruit': 'Pitaya',
    'passion fruit': 'Passionfruit',
    'sugar': 'Sugar',
    'cotton': 'Cotton',
    'wheat': 'Wheat',
    'barley': 'Barley',
    'oats': 'Oat',
    'rye': 'Rye',
    'sorghum': 'Sorghum',
    'millet': 'Millet',
    'buckwheat': 'Buckwheat',
    'quinoa': 'Quinoa',
    'tomato': 'Tomato',
    'potato': 'Potato',
    'onion': 'Onion',
    'garlic': 'Garlic',
    'carrot': 'Carrot',
    'cucumber': 'Cucumber',
    'pepper': 'Chili_pepper',
    'eggplant': 'Eggplant',
    'broccoli': 'Broccoli',
    'cabbage': 'Cabbage',
    'lettuce': 'Lettuce',
    'spinach': 'Spinach',
    'celery': 'Celery',
    'cauliflower': 'Cauliflower',
    'zucchini': 'Zucchini',
    'pumpkin': 'Pumpkin',
    'beet': 'Beetroot',
    'beetroot': 'Beetroot',
    'radish': 'Radish',
    'turnip': 'Turnip',
    'pea': 'Pea',
    'asparagus': 'Asparagus',
    'artichoke': 'Artichoke',
    'leek': 'Leek',
    'okra': 'Okra',
    'mushroom': 'Mushroom',
    'ginger': 'Ginger',
    'apple': 'Apple',
    'pear': 'Pear',
    'grape': 'Grape',
    'orange': 'Orange_(fruit)',
    'lemon': 'Lemon',
    'lime': 'Lime_(fruit)',
    'banana': 'Banana',
    'watermelon': 'Watermelon',
    'melon': 'Melon',
    'strawberry': 'Strawberry',
    'blueberry': 'Blueberry',
    'cherry': 'Cherry',
    'peach': 'Peach',
    'apricot': 'Apricot',
    'plum': 'Plum',
    'fig': 'Common_fig',
    'pomegranate': 'Pomegranate',
    'mango': 'Mango',
    'pineapple': 'Pineapple',
    'coconut': 'Coconut',
    'kiwi': 'Kiwifruit',
    'avocado': 'Avocado',
    'olive': 'Olive',
    'date': 'Date_palm',
    'persimmon': 'Persimmon',
    'quince': 'Quince',
    'raspberry': 'Raspberry',
    'blackberry': 'Blackberry',
    'cranberry': 'Cranberry',
    'mulberry': 'Mulberry',
    'currant': 'Currant',
    'gooseberry': 'Gooseberry',
    'papaya': 'Papaya',
    'guava': 'Guava',
    'lychee': 'Lychee',
    'almond': 'Almond',
    'walnut': 'Walnut',
    'hazelnut': 'Hazelnut',
    'pistachio': 'Pistachio',
    'peanut': 'Peanut',
    'cashew': 'Cashew',
    'chestnut': 'Chestnut',
    'sunflower': 'Sunflower',
    'soybean': 'Soybean',
    'rapeseed': 'Rapeseed',
    'canola': 'Canola',
    'sesame': 'Sesame',
    'lentil': 'Lentil',
    'chickpea': 'Chickpea',
    'bean': 'Bean',
    'tea': 'Tea',
    'coffee': 'Coffee',
    'cocoa': 'Cocoa_bean',
    'tobacco': 'Tobacco',
    'sugarcane': 'Sugarcane',
    'hemp': 'Hemp',
    'flax': 'Flax',
    'saffron': 'Saffron',
    'turmeric': 'Turmeric',
    'cinnamon': 'Cinnamon',
    'vanilla': 'Vanilla',
    'chili': 'Chili_pepper',
    'paprika': 'Paprika',
    'mint': 'Mentha',
    'basil': 'Basil',
    'oregano': 'Oregano',
    'thyme': 'Thyme',
    'rosemary': 'Rosemary',
    'parsley': 'Parsley',
    'dill': 'Dill',
    'fennel': 'Fennel',
    'cumin': 'Cumin',
    'coriander': 'Coriander',
    'squash': 'Squash_(plant)',
    'nectarine': 'Nectarine',
    'tangerine': 'Tangerine',
    'mandarin': 'Mandarin_orange',
    'grapefruit': 'Grapefruit',
    'clementine': 'Clementine',
    'honey': 'Honey',
  };

  /// In-memory cache so we don't re-read SharedPreferences on every build.
  static final Map<String, String?> _memCache = {};

  /// Get the image URL for a crop. Returns cached URL or null.
  static String? getCachedImageUrl(String cropName) {
    final key = cropName.toLowerCase().trim();
    return _memCache[key];
  }

  /// Load all cached image URLs from SharedPreferences into memory.
  static Future<void> loadCache(SharedPreferences prefs) async {
    final keys = prefs.getKeys().where((k) => k.startsWith(_cachePrefix));
    for (final k in keys) {
      final cropKey = k.substring(_cachePrefix.length);
      _memCache[cropKey] = prefs.getString(k);
    }
    debugPrint('CropImageService: loaded ${_memCache.length} cached images');
  }

  /// Batch-fetch images for a list of crop names.
  /// Fetches only crops that aren't already cached.
  static Future<void> fetchImages(
    List<String> cropNames,
    SharedPreferences prefs,
  ) async {
    final toFetch = <String>[];
    for (final name in cropNames) {
      final key = name.toLowerCase().trim();
      if (!_memCache.containsKey(key)) {
        toFetch.add(key);
      }
    }

    if (toFetch.isEmpty) return;
    debugPrint('CropImageService: fetching ${toFetch.length} images from Wikipedia');

    // Fetch in parallel, max 5 at a time to be polite
    final futures = <Future<void>>[];
    for (int i = 0; i < toFetch.length; i += 5) {
      final batch = toFetch.sublist(i, (i + 5).clamp(0, toFetch.length));
      for (final crop in batch) {
        futures.add(_fetchSingle(crop, prefs));
      }
      // Wait for this batch before starting the next
      await Future.wait(futures);
      futures.clear();
    }
  }

  static Future<void> _fetchSingle(String cropKey, SharedPreferences prefs) async {
    try {
      final wikiTitle = _wikiOverrides[cropKey] ??
          cropKey[0].toUpperCase() + cropKey.substring(1);
      
      final url = '$_wikiBaseUrl/$wikiTitle';
      final response = await http.get(
        Uri.parse(url),
        headers: {
          'User-Agent': 'AgriAgent/2.0 (Agricultural Advisory App; contact@agriagent.app)',
          'Accept': 'application/json',
        },
      ).timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final thumbnail = data['thumbnail'] as Map<String, dynamic>?;
        if (thumbnail != null) {
          String imageUrl = thumbnail['source'] as String;
          // Request a specific width for consistent sizing
          imageUrl = imageUrl.replaceAllMapped(
            RegExp(r'/(\d+)px-'),
            (m) => '/${_thumbWidth}px-',
          );
          _memCache[cropKey] = imageUrl;
          await prefs.setString('$_cachePrefix$cropKey', imageUrl);
          return;
        }
      }
      // Mark as "no image found" to avoid re-fetching
      _memCache[cropKey] = '';
    } catch (e) {
      debugPrint('CropImageService: failed to fetch image for $cropKey: $e');
      // Don't cache failures — retry next time
    }
  }
}
