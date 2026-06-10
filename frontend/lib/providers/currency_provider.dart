import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../utils/currency_service.dart';
import 'farmer_provider.dart';

/// Provides the user's local currency code based on their country.
/// Falls back to USD if no farmer profile is loaded.
final userCurrencyProvider = Provider<String>((ref) {
  try {
    final farmerAsync = ref.watch(currentFarmerProvider);
    return farmerAsync.when(
      data: (farmer) {
        final country = CurrencyService.extractCountry(farmer.location);
        return CurrencyService.currencyForCountry(country);
      },
      loading: () => 'USD',
      error: (_, __) => 'USD',
    );
  } catch (_) {
    return 'USD';
  }
});
