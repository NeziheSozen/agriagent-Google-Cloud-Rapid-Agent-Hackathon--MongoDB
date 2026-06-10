// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'threat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches regional threats for the given region.

@ProviderFor(threat)
const threatProvider = ThreatFamily._();

/// Fetches regional threats for the given region.

final class ThreatProvider extends $FunctionalProvider<
        AsyncValue<RegionalThreats>, RegionalThreats, FutureOr<RegionalThreats>>
    with $FutureModifier<RegionalThreats>, $FutureProvider<RegionalThreats> {
  /// Fetches regional threats for the given region.
  const ThreatProvider._(
      {required ThreatFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'threatProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$threatHash();

  @override
  String toString() {
    return r'threatProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<RegionalThreats> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RegionalThreats> create(Ref ref) {
    final argument = this.argument as String;
    return threat(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ThreatProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$threatHash() => r'e911e60470c60893d50b04470f83a6635c90dfe2';

/// Fetches regional threats for the given region.

final class ThreatFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<RegionalThreats>, String> {
  const ThreatFamily._()
      : super(
          retry: null,
          name: r'threatProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetches regional threats for the given region.

  ThreatProvider call(
    String region,
  ) =>
      ThreatProvider._(argument: region, from: this);

  @override
  String toString() => r'threatProvider';
}

/// Regional threats for the current farmer's region.

@ProviderFor(currentThreats)
const currentThreatsProvider = CurrentThreatsProvider._();

/// Regional threats for the current farmer's region.

final class CurrentThreatsProvider extends $FunctionalProvider<
        AsyncValue<RegionalThreats>, RegionalThreats, FutureOr<RegionalThreats>>
    with $FutureModifier<RegionalThreats>, $FutureProvider<RegionalThreats> {
  /// Regional threats for the current farmer's region.
  const CurrentThreatsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentThreatsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentThreatsHash();

  @$internal
  @override
  $FutureProviderElement<RegionalThreats> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<RegionalThreats> create(Ref ref) {
    return currentThreats(ref);
  }
}

String _$currentThreatsHash() => r'47db877cddca4a1c5581ddd3e29970b8494da1ed';
