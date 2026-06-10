// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'offline_queue_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(OfflineQueue)
const offlineQueueProvider = OfflineQueueProvider._();

final class OfflineQueueProvider
    extends $NotifierProvider<OfflineQueue, List<PendingJob>> {
  const OfflineQueueProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'offlineQueueProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$offlineQueueHash();

  @$internal
  @override
  OfflineQueue create() => OfflineQueue();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<PendingJob> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<PendingJob>>(value),
    );
  }
}

String _$offlineQueueHash() => r'01c147b6997daeabba556034149e47962f45b9a6';

abstract class _$OfflineQueue extends $Notifier<List<PendingJob>> {
  List<PendingJob> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<List<PendingJob>, List<PendingJob>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<PendingJob>, List<PendingJob>>,
        List<PendingJob>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
