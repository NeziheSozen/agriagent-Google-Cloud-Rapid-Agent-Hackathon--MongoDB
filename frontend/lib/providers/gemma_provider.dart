import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

part 'gemma_provider.g.dart';

enum GemmaState {
  notDownloaded,
  downloading,
  ready,
  error,
}

class GemmaStateModel {
  final GemmaState state;
  final double progress;
  final String? errorMessage;

  GemmaStateModel({
    required this.state,
    this.progress = 0.0,
    this.errorMessage,
  });

  GemmaStateModel copyWith({
    GemmaState? state,
    double? progress,
    String? errorMessage,
  }) {
    return GemmaStateModel(
      state: state ?? this.state,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }
}

/// Hugging Face model URL for Gemma 4 E2B (instruction-tuned, LiteRT-LM format)
/// On-device optimized: multimodal, 128K context, Apache 2.0 license
const _modelUrl =
    'https://huggingface.co/litert-community/gemma-4-E2B-it-litert-lm/resolve/main/gemma-4-E2B-it.litertlm';

@Riverpod(keepAlive: true)
class GemmaNotifier extends _$GemmaNotifier {
  InferenceChat? _chat;

  @override
  GemmaStateModel build() {
    Future.microtask(() => _checkInitialState());
    return GemmaStateModel(state: GemmaState.notDownloaded);
  }

  Future<void> _checkInitialState() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDownloaded = prefs.getBool('gemma_downloaded') ?? false;

      if (isDownloaded) {
        try {
          // Get active model and create a chat session
          final model = await FlutterGemma.getActiveModel(maxTokens: 512);
          _chat = await model.createChat(temperature: 0.7, topK: 40);
          state = state.copyWith(state: GemmaState.ready, progress: 1.0);
        } catch (e) {
          // Model file might be corrupted or missing, reset state
          state = state.copyWith(state: GemmaState.notDownloaded);
          await prefs.setBool('gemma_downloaded', false);
        }
      }
    } catch (e) {
      state = state.copyWith(state: GemmaState.error, errorMessage: e.toString());
    }
  }

  Future<void> downloadModel() async {
    if (state.state == GemmaState.downloading || state.state == GemmaState.ready) return;

    state = state.copyWith(state: GemmaState.downloading, progress: 0.0, errorMessage: null);

    try {
      // Install model from Hugging Face with progress tracking
      await FlutterGemma.installModel(
        modelType: ModelType.gemmaIt, // Works with Gemma 4 E2B .litertlm format
      )
      .fromNetwork(_modelUrl)
      .withProgress((progress) {
        // progress is 0-100 int
        state = state.copyWith(progress: progress / 100.0);
      })
      .install();

      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('gemma_downloaded', true);

      // Initialize the model for inference
      final model = await FlutterGemma.getActiveModel(maxTokens: 512);
      _chat = await model.createChat(temperature: 0.7, topK: 40);

      state = state.copyWith(state: GemmaState.ready, progress: 1.0);
    } catch (e) {
      state = state.copyWith(state: GemmaState.error, errorMessage: e.toString());
    }
  }

  Future<String> generateResponse(String prompt) async {
    if (state.state != GemmaState.ready) {
      return "Model is not ready. Please download the model from Settings first.";
    }

    try {
      // Ensure we have an active chat instance
      if (_chat == null) {
        final model = await FlutterGemma.getActiveModel(maxTokens: 512);
        _chat = await model.createChat(temperature: 0.7, topK: 40);
      }

      // Add the user query
      await _chat!.addQuery(Message(text: prompt, isUser: true));

      // Collect the streamed response
      final buffer = StringBuffer();
      await for (final response in _chat!.generateChatResponseAsync()) {
        if (response is TextResponse) {
          buffer.write(response.token);
        }
      }

      final result = buffer.toString().trim();
      return result.isNotEmpty
          ? result
          : "Gemma (Offline): Sorry, could not generate a response. Please try again.";
    } catch (e) {
      // If chat session is broken, reset it
      _chat = null;
      return "Gemma (Offline): An error occurred — ${e.toString().length > 100 ? e.toString().substring(0, 100) : e.toString()}";
    }
  }
}
