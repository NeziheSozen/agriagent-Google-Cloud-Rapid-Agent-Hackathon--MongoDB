// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'report_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Previous reports list for the current farmer.

@ProviderFor(previousReports)
const previousReportsProvider = PreviousReportsProvider._();

/// Previous reports list for the current farmer.

final class PreviousReportsProvider extends $FunctionalProvider<
        AsyncValue<List<StrategyReport>>,
        List<StrategyReport>,
        FutureOr<List<StrategyReport>>>
    with
        $FutureModifier<List<StrategyReport>>,
        $FutureProvider<List<StrategyReport>> {
  /// Previous reports list for the current farmer.
  const PreviousReportsProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'previousReportsProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$previousReportsHash();

  @$internal
  @override
  $FutureProviderElement<List<StrategyReport>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<List<StrategyReport>> create(Ref ref) {
    return previousReports(ref);
  }
}

String _$previousReportsHash() => r'2e96ae5c6076127350ad0dffe8d3e225f54d4245';

/// State for the report save operation.

@ProviderFor(saveReport)
const saveReportProvider = SaveReportFamily._();

/// State for the report save operation.

final class SaveReportProvider extends $FunctionalProvider<
        AsyncValue<Map<String, dynamic>>,
        Map<String, dynamic>,
        FutureOr<Map<String, dynamic>>>
    with
        $FutureModifier<Map<String, dynamic>>,
        $FutureProvider<Map<String, dynamic>> {
  /// State for the report save operation.
  const SaveReportProvider._(
      {required SaveReportFamily super.from,
      required StrategyReport super.argument})
      : super(
          retry: null,
          name: r'saveReportProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$saveReportHash();

  @override
  String toString() {
    return r'saveReportProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  $FutureProviderElement<Map<String, dynamic>> $createElement(
          $ProviderPointer pointer) =>
      $FutureProviderElement(pointer);

  @override
  FutureOr<Map<String, dynamic>> create(Ref ref) {
    final argument = this.argument as StrategyReport;
    return saveReport(
      ref,
      argument,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SaveReportProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$saveReportHash() => r'afb895e10a1390962eaa53fb6ee9b2a088d1f0c7';

/// State for the report save operation.

final class SaveReportFamily extends $Family
    with
        $FunctionalFamilyOverride<FutureOr<Map<String, dynamic>>,
            StrategyReport> {
  const SaveReportFamily._()
      : super(
          retry: null,
          name: r'saveReportProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: true,
        );

  /// State for the report save operation.

  SaveReportProvider call(
    StrategyReport report,
  ) =>
      SaveReportProvider._(argument: report, from: this);

  @override
  String toString() => r'saveReportProvider';
}

/// Tracks whether a report is currently being saved.

@ProviderFor(IsSavingReport)
const isSavingReportProvider = IsSavingReportProvider._();

/// Tracks whether a report is currently being saved.
final class IsSavingReportProvider
    extends $NotifierProvider<IsSavingReport, bool> {
  /// Tracks whether a report is currently being saved.
  const IsSavingReportProvider._()
      : super(
          from: null,
          argument: null,
          retry: null,
          name: r'isSavingReportProvider',
          isAutoDispose: true,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$isSavingReportHash();

  @$internal
  @override
  IsSavingReport create() => IsSavingReport();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isSavingReportHash() => r'6c6e954ad90321a5dea7873016491d0ff22bcf05';

/// Tracks whether a report is currently being saved.

abstract class _$IsSavingReport extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<bool, bool>, bool, Object?, Object?>;
    element.handleValue(ref, created);
  }
}
