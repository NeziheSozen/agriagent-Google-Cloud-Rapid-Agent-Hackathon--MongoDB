import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import '../models/strategy_report.dart';
import 'api_client.dart';

class AgentApi {
  final ApiClient _client;

  AgentApi(this._client);

  /// POST /agent/generate-report/{userId}?lang={langCode}
  Future<StrategyReport> generateReport(String userId, String langCode) {
    return _client.post(
      '/agent/generate-report/$userId?lang=$langCode',
      parser: (data) => StrategyReport.fromJson(data as Map<String, dynamic>),
    );
  }

  /// POST /agent/chat/{userId}
  Future<String> chatWithAgent(String userId, String message) async {
    final response = await _client.post(
      '/agent/chat/$userId',
      data: {'message': message},
      parser: (data) => (data as Map<String, dynamic>)['reply'] as String,
    );
    return response;
  }

  /// POST /agent/chat/stream/{userId}
  Stream<Map<String, dynamic>> streamChatWithAgent(String userId, String message) async* {
    final response = await _client.dio.post<ResponseBody>(
      '/agent/chat/stream/$userId',
      data: {'message': message},
      options: Options(responseType: ResponseType.stream),
    );

    final stream = response.data!.stream;
    
    await for (final rawData in stream) {
      final text = utf8.decode(rawData);
      final lines = text.split('\n');
      for (final line in lines) {
        if (line.startsWith('data: ')) {
          final dataStr = line.substring(6).trim();
          if (dataStr.isNotEmpty) {
            try {
              final json = jsonDecode(dataStr);
              yield json as Map<String, dynamic>;
            } catch (e) {
              // ignore parse errors for partial chunks
            }
          }
        }
      }
    }
  }

  /// POST /agent/voice-chat/{userId}
  Future<String> voiceChatWithAgent(String userId, String audioPath) async {
    final formData = FormData.fromMap({
      'file': await MultipartFile.fromFile(
        audioPath,
        filename: 'voice.m4a',
      ),
    });

    final response = await _client.post(
      '/agent/voice-chat/$userId',
      data: formData,
      parser: (data) => (data as Map<String, dynamic>)['reply'] as String,
    );
    return response;
  }

  /// POST /agent/scan-pest/{userId}
  Future<Map<String, dynamic>> scanPest(String userId, XFile imageFile, String langCode) async {
    MultipartFile filePart;
    if (kIsWeb) {
      final bytes = await imageFile.readAsBytes();
      filePart = MultipartFile.fromBytes(bytes, filename: imageFile.name.isNotEmpty ? imageFile.name : 'image.jpg');
    } else {
      filePart = await MultipartFile.fromFile(imageFile.path);
    }
    
    final formData = FormData.fromMap({
      'file': filePart,
    });

    return _client.post(
      '/agent/scan-pest/$userId?lang=$langCode',
      data: formData,
      parser: (data) => data as Map<String, dynamic>,
    );
  }

  /// GET /agent/logistics-advice/{crop}
  Future<String> getLogisticsAdvice(String crop) async {
    final response = await _client.get(
      '/agent/logistics-advice/$crop',
      parser: (data) => (data as Map<String, dynamic>)['advice'] as String,
    );
    return response;
  }
}

final agentApiProvider = Provider<AgentApi>((ref) {
  return AgentApi(ref.read(apiClientProvider));
});
