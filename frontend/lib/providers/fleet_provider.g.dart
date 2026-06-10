// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'fleet_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches fleet schedule for the current farmer's cooperative.

@ProviderFor(fleet)
const fleetProvider = FleetProvider._();

/// Fetches fleet schedule for the current farmer's cooperative.

final class FleetProvider extends $FunctionalProvider<
        AsyncValue<FleetSchedule?>, FleetSchedule?, FutureOr<FleetSchedule?>>
    with $FutureModifier<FleetSchedule?>, $FutureProvider<FleetSchedule?> {
  /// Fetches fleet schedule for the current farmer's cooperative.
  const FleetProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'fleetProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$fleetHash();

  @$internal
  @override
  $FutureProviderElement<FleetSchedule?> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<FleetSchedule?> create(Ref ref) {
    return fleet(ref);
  }
}

String _$fleetHash() => r'9a2bd7aeacf47476c5b91696c95a63a292bf663c';
