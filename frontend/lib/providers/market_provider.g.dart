// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'market_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Crop list used for market forecast requests.

@ProviderFor(SelectedCrops)
const selectedCropsProvider = SelectedCropsProvider._();

/// Crop list used for market forecast requests.
final class SelectedCropsProvider
    extends $NotifierProvider<SelectedCrops, List<String>> {
  /// Crop list used for market forecast requests.
  const SelectedCropsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'selectedCropsProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$selectedCropsHash();

  @$internal
  @override
  SelectedCrops create() => SelectedCrops();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<String> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<String>>(value),
    );
  }
}

String _$selectedCropsHash() => r'8759cabf0be8603b7c3574bb5252687dc72aadc8';

/// Crop list used for market forecast requests.

abstract class _$SelectedCrops extends $Notifier<List<String>> {
  List<String> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<String>, List<String>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<String>, List<String>>,
        List<String>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

/// Sort provider for market screen.

@ProviderFor(MarketSort)
const marketSortProvider = MarketSortProvider._();

/// Sort provider for market screen.
final class MarketSortProvider
    extends $NotifierProvider<MarketSort, MarketSortCriteria> {
  /// Sort provider for market screen.
  const MarketSortProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'marketSortProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$marketSortHash();

  @$internal
  @override
  MarketSort create() => MarketSort();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(MarketSortCriteria value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<MarketSortCriteria>(value),
    );
  }
}

String _$marketSortHash() => r'8c081a8116a53da9f8743ad51bdc0eb58a52cf0a';

/// Sort provider for market screen.

abstract class _$MarketSort extends $Notifier<MarketSortCriteria> {
  MarketSortCriteria build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<MarketSortCriteria, MarketSortCriteria>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<MarketSortCriteria, MarketSortCriteria>,
        MarketSortCriteria,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}

/// Fetches market forecast for the selected crops.

@ProviderFor(marketForecast)
const marketForecastProvider = MarketForecastProvider._();

/// Fetches market forecast for the selected crops.

final class MarketForecastProvider extends $FunctionalProvider<
        AsyncValue<MarketForecast>, MarketForecast, FutureOr<MarketForecast>>
    with $FutureModifier<MarketForecast>, $FutureProvider<MarketForecast> {
  /// Fetches market forecast for the selected crops.
  const MarketForecastProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'marketForecastProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$marketForecastHash();

  @$internal
  @override
  $FutureProviderElement<MarketForecast> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<MarketForecast> create(Ref ref) {
    return marketForecast(ref);
  }
}

String _$marketForecastHash() => r'b221b5307bbb95e401cd181d3eef62f28ba805e5';

/// Sorted predictions based on the selected sort criteria.

@ProviderFor(sortedPredictions)
const sortedPredictionsProvider = SortedPredictionsProvider._();

/// Sorted predictions based on the selected sort criteria.

final class SortedPredictionsProvider extends $FunctionalProvider<
        AsyncValue<List<CropPriceForecast>>,
        AsyncValue<List<CropPriceForecast>>,
        AsyncValue<List<CropPriceForecast>>>
    with $Provider<AsyncValue<List<CropPriceForecast>>> {
  /// Sorted predictions based on the selected sort criteria.
  const SortedPredictionsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'sortedPredictionsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$sortedPredictionsHash();

  @$internal
  @override
  $ProviderElement<AsyncValue<List<CropPriceForecast>>> $createElement(
          $ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AsyncValue<List<CropPriceForecast>> create(Ref ref) {
    return sortedPredictions(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AsyncValue<List<CropPriceForecast>> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride:
          $SyncValueProvider<AsyncValue<List<CropPriceForecast>>>(value),
    );
  }
}

String _$sortedPredictionsHash() => r'9b387bba81f402e94162cb2b517e706f9c88377b';
