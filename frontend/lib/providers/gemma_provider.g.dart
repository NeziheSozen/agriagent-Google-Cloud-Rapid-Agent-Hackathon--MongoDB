// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'gemma_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(GemmaNotifier)
const gemmaProvider = GemmaNotifierProvider._();

final class GemmaNotifierProvider
    extends $NotifierProvider<GemmaNotifier, GemmaStateModel> {
  const GemmaNotifierProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'gemmaProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$gemmaNotifierHash();

  @$internal
  @override
  GemmaNotifier create() => GemmaNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GemmaStateModel value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GemmaStateModel>(value),
    );
  }
}

String _$gemmaNotifierHash() => r'cb66d03e974f257a760a160226090aa7f994577f';

abstract class _$GemmaNotifier extends $Notifier<GemmaStateModel> {
  GemmaStateModel build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<GemmaStateModel, GemmaStateModel>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<GemmaStateModel, GemmaStateModel>,
        GemmaStateModel,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
