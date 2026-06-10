import 'package:intl/intl.dart';
import 'currency_service.dart';

class CurrencyFormatter {
  static String formatNativePrice(double price, String currency) {
    final symbol = CurrencyService.getSymbol(currency);
    
    switch (currency.toUpperCase()) {
      case 'TRY':
        return NumberFormat.compactCurrency(locale: 'tr_TR', symbol: '₺', decimalDigits: 1).format(price);
      case 'EUR':
        return NumberFormat.compactCurrency(locale: 'nl_NL', symbol: '€', decimalDigits: 1).format(price);
      case 'GBP':
        return NumberFormat.compactCurrency(locale: 'en_GB', symbol: '£', decimalDigits: 1).format(price);
      case 'JPY':
        return NumberFormat.compactCurrency(locale: 'ja_JP', symbol: '¥', decimalDigits: 1).format(price);
      case 'KRW':
        return NumberFormat.compactCurrency(locale: 'ko_KR', symbol: '₩', decimalDigits: 1).format(price);
      case 'CNY':
        return NumberFormat.compactCurrency(locale: 'zh_CN', symbol: '¥', decimalDigits: 1).format(price);
      case 'INR':
        return NumberFormat.compactCurrency(locale: 'en_IN', symbol: '₹', decimalDigits: 1).format(price);
      case 'BRL':
        return NumberFormat.compactCurrency(locale: 'pt_BR', symbol: 'R\$', decimalDigits: 1).format(price);
      case 'USD':
      default:
        return NumberFormat.compactCurrency(locale: 'en_US', symbol: r'$', decimalDigits: 1).format(price);
    }
  }

  static String formatPricePerTon(double price, String currency) {
    return '${formatNativePrice(price, currency)}/t';
  }

  /// Convert a USD price to the user's local currency and format it.
  static String formatLocalPrice(double usdPrice, String targetCurrency) {
    final localPrice = CurrencyService.convert(usdPrice, targetCurrency);
    return formatNativePrice(localPrice, targetCurrency);
  }

  /// Convert a USD price to the user's local currency and format per ton.
  static String formatLocalPricePerTon(double usdPrice, String targetCurrency) {
    final localPrice = CurrencyService.convert(usdPrice, targetCurrency);
    return '${formatNativePrice(localPrice, targetCurrency)}/t';
  }
}
