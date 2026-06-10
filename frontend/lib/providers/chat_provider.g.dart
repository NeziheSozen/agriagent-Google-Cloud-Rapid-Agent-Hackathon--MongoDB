// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(ChatNotifier)
const chatProvider = ChatNotifierFamily._();

final class ChatNotifierProvider
    extends $NotifierProvider<ChatNotifier, List<ChatMessage>> {
  const ChatNotifierProvider._(
      {required ChatNotifierFamily super.from, required String super.argument})
      : super(
          retry: null,
          name: r'chatProvider',
          isAutoDispose: false,
          dependencies: null,
          $allTransitiveDependencies: null,
        );

  @override
  String debugGetCreateSourceHash() => _$chatNotifierHash();

  @override
  String toString() {
    return r'chatProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ChatNotifier create() => ChatNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(List<ChatMessage> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<List<ChatMessage>>(value),
    );
  }

  @override
  bool operator ==(Object other) {
    return other is ChatNotifierProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$chatNotifierHash() => r'3f85aeadd8f72deea9966fa8191f80591808b943';

final class ChatNotifierFamily extends $Family
    with
        $ClassFamilyOverride<ChatNotifier, List<ChatMessage>, List<ChatMessage>,
            List<ChatMessage>, String> {
  const ChatNotifierFamily._()
      : super(
          retry: null,
          name: r'chatProvider',
          dependencies: null,
          $allTransitiveDependencies: null,
          isAutoDispose: false,
        );

  ChatNotifierProvider call(
    String farmerId,
  ) =>
      ChatNotifierProvider._(argument: farmerId, from: this);

  @override
  String toString() => r'chatProvider';
}

abstract class _$ChatNotifier extends $Notifier<List<ChatMessage>> {
  late final _$args = ref.$arg as String;
  String get farmerId => _$args;

  List<ChatMessage> build(
    String farmerId,
  );
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(
      _$args,
    );
    final ref = this.ref as $Ref<List<ChatMessage>, List<ChatMessage>>;
    final element = ref.element as $ClassProviderElement<
        AnyNotifier<List<ChatMessage>, List<ChatMessage>>,
        List<ChatMessage>,
        Object?,
        Object?>;
    element.handleValue(ref, created);
  }
}
