// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'climate_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches climate trends for a given location and language.

@ProviderFor(climateTrend)
const climateTrendProvider = ClimateTrendFamily._();

/// Fetches climate trends for a given location.

final class ClimateTrendProvider extends $FunctionalProvider<
        AsyncValue<ClimateTrend>, ClimateTrend, FutureOr<ClimateTrend>>
    with $FutureModifier<ClimateTrend>, $FutureProvider<ClimateTrend> {
  /// Fetches climate trends for a given location.
  const ClimateTrendProvider._(
      {required ClimateTrendFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'climateTrendProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$climateTrendHash();

  @override
  String toString() {
    return r'climateTrendProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<ClimateTrend> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ClimateTrend> create(Ref ref) {
    final argument = this.argument as String;
    return climateTrend(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ClimateTrendProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$climateTrendHash() => r'58078607ad4ce9f947b3fdc5a668a15b551895cc';

/// Fetches climate trends for a given location.

final class ClimateTrendFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<ClimateTrend>, String> {
  const ClimateTrendFamily._()
      : super(
          retry: null,
          name: r'climateTrendProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetches climate trends for a given location.

  ClimateTrendProvider call(
    String location,
  ) =>
      ClimateTrendProvider._(argument: location, from: this);

  @override
  String toString() => r'climateTrendProvider';
}

/// Climate trends for the current farmer's location.

@ProviderFor(currentClimateTrend)
const currentClimateTrendProvider = CurrentClimateTrendProvider._();

/// Climate trends for the current farmer's location.

final class CurrentClimateTrendProvider extends $FunctionalProvider<
        AsyncValue<ClimateTrend>, ClimateTrend, FutureOr<ClimateTrend>>
    with $FutureModifier<ClimateTrend>, $FutureProvider<ClimateTrend> {
  /// Climate trends for the current farmer's location.
  const CurrentClimateTrendProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentClimateTrendProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentClimateTrendHash();

  @$internal
  @override
  $FutureProviderElement<ClimateTrend> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<ClimateTrend> create(Ref ref) {
    return currentClimateTrend(ref);
  }
}

String _$currentClimateTrendHash() =>
    r'eb10e207f177da13209fdd21bcab3c541fa9f4ec';
