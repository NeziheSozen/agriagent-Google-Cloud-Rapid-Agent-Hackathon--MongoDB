import 'dart:convert';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:shared_preferences/shared_preferences.dart';

part 'chat_provider.g.dart';

class ChatMessage {
  final String text;
  final bool isUser;
  final bool isAudio;
  final String? imagePath;

  ChatMessage({required this.text, required this.isUser, this.isAudio = false, this.imagePath});

  Map<String, dynamic> toJson() => {
        'text': text,
        'isUser': isUser,
        'isAudio': isAudio,
        'imagePath': imagePath,
      };

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
        text: json['text'] as String,
        isUser: json['isUser'] as bool,
        isAudio: json['isAudio'] as bool? ?? false,
        imagePath: json['imagePath'] as String?,
      );
}

@Riverpod(keepAlive: true)
class ChatNotifier extends _$ChatNotifier {
  @override
  List<ChatMessage> build(String farmerId) {
    _loadHistory(farmerId);
    return [];
  }

  Future<void> _loadHistory(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString('chat_history_$id');
    if (data != null) {
      final List<dynamic> jsonList = jsonDecode(data);
      state = jsonList.map((e) => ChatMessage.fromJson(e as Map<String, dynamic>)).toList();
    }
  }

  Future<void> _saveHistory(List<ChatMessage> messages) async {
    final prefs = await SharedPreferences.getInstance();
    final jsonList = messages.map((m) => m.toJson()).toList();
    await prefs.setString('chat_history_$farmerId', jsonEncode(jsonList));
  }

  void addMessage(ChatMessage msg) {
    state = [...state, msg];
    _saveHistory(state);
  }

  void updateLastMessage(ChatMessage msg) {
    if (state.isEmpty) return;
    final newState = List<ChatMessage>.from(state);
    newState[newState.length - 1] = msg;
    state = newState;
    _saveHistory(state);
  }

  void clearChat() {
    state = [];
    _saveHistory(state);
  }
}
