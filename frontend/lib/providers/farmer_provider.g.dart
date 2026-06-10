// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'farmer_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Currently selected farmer user ID.

@ProviderFor(SelectedFarmerId)
const selectedFarmerIdProvider = SelectedFarmerIdProvider._();

/// Currently selected farmer user ID.
final class SelectedFarmerIdProvider
    extends $NotifierProvider<SelectedFarmerId, String> {
  /// Currently selected farmer user ID.
  const SelectedFarmerIdProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'selectedFarmerIdProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$selectedFarmerIdHash();

  @$internal
  @override
  SelectedFarmerId create() => SelectedFarmerId();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(String value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<String>(value),
    );
  }
}

String _$selectedFarmerIdHash() => r'3733e217a03e138a794806972d0a2bb7e41afc2e';

/// Currently selected farmer user ID.

abstract class _$SelectedFarmerId extends $Notifier<String> {
  String build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<String, String>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<String, String>, String, Object?, Object?>;
    element.handleValue(ref, created);
  }
}

/// Fetches the farmer profile for a given user ID.

@ProviderFor(farmerProfile)
const farmerProfileProvider = FarmerProfileFamily._();

/// Fetches the farmer profile for a given user ID.

final class FarmerProfileProvider extends $FunctionalProvider<
        AsyncValue<FarmerProfile>, FarmerProfile, FutureOr<FarmerProfile>>
    with $FutureModifier<FarmerProfile>, $FutureProvider<FarmerProfile> {
  /// Fetches the farmer profile for a given user ID.
  const FarmerProfileProvider._(
      {required FarmerProfileFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'farmerProfileProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$farmerProfileHash();

  @override
  String toString() {
    return r'farmerProfileProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<FarmerProfile> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FarmerProfile> create(Ref ref) {
    final argument = this.argument as String;
    return farmerProfile(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is FarmerProfileProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$farmerProfileHash() => r'4dd627c46f390b7eec7f6e4edeb1a1134f135f16';

/// Fetches the farmer profile for a given user ID.

final class FarmerProfileFamily extends $Family
    with $FunctionalFamilyOverride<FutureOr<FarmerProfile>, String> {
  const FarmerProfileFamily._()
      : super(
          retry: null,
          name: r'farmerProfileProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// Fetches the farmer profile for a given user ID.

  FarmerProfileProvider call(
    String userId,
  ) =>
      FarmerProfileProvider._(argument: userId, from: this);

  @override
  String toString() => r'farmerProfileProvider';
}

/// Convenience provider that fetches the currently selected farmer.

@ProviderFor(currentFarmer)
const currentFarmerProvider = CurrentFarmerProvider._();

/// Convenience provider that fetches the currently selected farmer.

final class CurrentFarmerProvider extends $FunctionalProvider<
        AsyncValue<FarmerProfile>, FarmerProfile, FutureOr<FarmerProfile>>
    with $FutureModifier<FarmerProfile>, $FutureProvider<FarmerProfile> {
  /// Convenience provider that fetches the currently selected farmer.
  const CurrentFarmerProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'currentFarmerProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$currentFarmerHash();

  @$internal
  @override
  $FutureProviderElement<FarmerProfile> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FarmerProfile> create(Ref ref) {
    return currentFarmer(ref);
  }
}

String _$currentFarmerHash() => r'05fb3525e805ca281e1154f2a2ae6c893440ff90';
