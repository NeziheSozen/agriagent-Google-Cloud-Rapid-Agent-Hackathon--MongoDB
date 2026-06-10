/// Currency conversion service.
///
/// Maps country names to currency codes and provides
/// approximate exchange rates from USD for display purposes.
class CurrencyService {
  // Country → ISO 4217 currency code
  static const Map<String, String> _countryCurrency = {
    'Turkey': 'TRY',
    'United States': 'USD',
    'Germany': 'EUR',
    'France': 'EUR',
    'Italy': 'EUR',
    'Spain': 'EUR',
    'Netherlands': 'EUR',
    'Belgium': 'EUR',
    'Austria': 'EUR',
    'Portugal': 'EUR',
    'Greece': 'EUR',
    'Ireland': 'EUR',
    'Finland': 'EUR',
    'United Kingdom': 'GBP',
    'Japan': 'JPY',
    'South Korea': 'KRW',
    'China': 'CNY',
    'India': 'INR',
    'Brazil': 'BRL',
    'Mexico': 'MXN',
    'Canada': 'CAD',
    'Australia': 'AUD',
    'Russia': 'RUB',
    'Egypt': 'EGP',
    'South Africa': 'ZAR',
    'Nigeria': 'NGN',
    'Kenya': 'KES',
    'Indonesia': 'IDR',
    'Thailand': 'THB',
    'Vietnam': 'VND',
    'Pakistan': 'PKR',
    'Bangladesh': 'BDT',
    'Argentina': 'ARS',
    'Colombia': 'COP',
    'Chile': 'CLP',
    'Peru': 'PEN',
    'Morocco': 'MAD',
    'Tunisia': 'TND',
    'Ukraine': 'UAH',
    'Poland': 'PLN',
    'Romania': 'RON',
    'Hungary': 'HUF',
    'Czech Republic': 'CZK',
    'Sweden': 'SEK',
    'Norway': 'NOK',
    'Denmark': 'DKK',
    'Switzerland': 'CHF',
    'Israel': 'ILS',
    'Saudi Arabia': 'SAR',
    'UAE': 'AED',
    'Iran': 'IRR',
    'Iraq': 'IQD',
    'Philippines': 'PHP',
    'Malaysia': 'MYR',
    'New Zealand': 'NZD',
    'Ethiopia': 'ETB',
    'Tanzania': 'TZS',
    'Ghana': 'GHS',
  };

  // Approximate USD → local currency exchange rates (June 2026 estimates)
  // These are ballpark figures for display; not for financial transactions.
  static const Map<String, double> _usdRates = {
    'USD': 1.0,
    'TRY': 38.5,
    'EUR': 0.92,
    'GBP': 0.79,
    'JPY': 155.0,
    'KRW': 1380.0,
    'CNY': 7.25,
    'INR': 84.0,
    'BRL': 5.1,
    'MXN': 17.5,
    'CAD': 1.37,
    'AUD': 1.55,
    'RUB': 92.0,
    'EGP': 48.0,
    'ZAR': 18.5,
    'NGN': 1550.0,
    'KES': 153.0,
    'IDR': 15800.0,
    'THB': 35.5,
    'VND': 25000.0,
    'PKR': 280.0,
    'BDT': 110.0,
    'ARS': 900.0,
    'COP': 4100.0,
    'CLP': 940.0,
    'PEN': 3.75,
    'MAD': 10.0,
    'TND': 3.15,
    'UAH': 41.0,
    'PLN': 4.05,
    'RON': 4.6,
    'HUF': 365.0,
    'CZK': 23.0,
    'SEK': 10.8,
    'NOK': 10.9,
    'DKK': 6.9,
    'CHF': 0.89,
    'ILS': 3.65,
    'SAR': 3.75,
    'AED': 3.67,
    'IRR': 42000.0,
    'IQD': 1310.0,
    'PHP': 56.5,
    'MYR': 4.7,
    'NZD': 1.68,
    'ETB': 57.0,
    'TZS': 2550.0,
    'GHS': 15.0,
  };

  // Currency → symbol
  static const Map<String, String> _currencySymbols = {
    'USD': r'$',
    'TRY': '₺',
    'EUR': '€',
    'GBP': '£',
    'JPY': '¥',
    'KRW': '₩',
    'CNY': '¥',
    'INR': '₹',
    'BRL': 'R\$',
    'RUB': '₽',
    'PLN': 'zł',
    'CHF': 'CHF',
    'SEK': 'kr',
    'NOK': 'kr',
    'DKK': 'kr',
    'HUF': 'Ft',
    'CZK': 'Kč',
    'THB': '฿',
    'PHP': '₱',
    'ILS': '₪',
    'SAR': 'SAR',
    'AED': 'AED',
  };

  /// Get the currency code for a given country name.
  static String currencyForCountry(String country) {
    return _countryCurrency[country] ?? 'USD';
  }

  /// Get the exchange rate from USD to the target currency.
  static double getRate(String currencyCode) {
    return _usdRates[currencyCode] ?? 1.0;
  }

  /// Convert a USD amount to the target currency.
  static double convert(double usdAmount, String targetCurrency) {
    return usdAmount * getRate(targetCurrency);
  }

  /// Get the currency symbol for a given currency code.
  static String getSymbol(String currencyCode) {
    return _currencySymbols[currencyCode] ?? currencyCode;
  }

  /// Extract the country name from a location string like "Antalya, Turkey"
  static String extractCountry(String location) {
    final parts = location.split(',');
    if (parts.length >= 2) {
      return parts.last.trim();
    }
    return location.trim();
  }

  /// Determine whether to use decimal digits for a currency.
  /// High-value currencies (USD, EUR, GBP) use 0 decimals for per-ton prices.
  /// Low-value currencies also use 0 decimals since amounts are large.
  static int decimalDigits(String currencyCode) {
    return 0;
  }
}
