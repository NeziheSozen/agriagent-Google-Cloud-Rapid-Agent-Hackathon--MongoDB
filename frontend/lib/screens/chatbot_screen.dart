import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_picker/image_picker.dart';

import '../app/theme.dart';
import '../providers/farmer_provider.dart';
import '../services/agent_api.dart';
import '../app/l10n/translations.dart';
import '../utils/app_logger.dart';
import '../providers/chat_provider.dart';
import '../providers/gemma_provider.dart';
import '../providers/shared_prefs_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChatbotScreen extends ConsumerStatefulWidget {
  const ChatbotScreen({super.key});

  @override
  ConsumerState<ChatbotScreen> createState() => _ChatbotScreenState();
}

class _ChatbotScreenState extends ConsumerState<ChatbotScreen> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  bool _isLoading = false;

  late final AudioRecorder _audioRecorder;
  late final FlutterTts _flutterTts;
  bool _isRecording = false;
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _audioRecorder = AudioRecorder();
    _flutterTts = FlutterTts();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    final locale = Localizations.localeOf(context);
    final langStr = '${locale.languageCode}-${locale.countryCode ?? (locale.languageCode == 'en' ? 'US' : locale.languageCode.toUpperCase())}';
    // Language will be set right before speaking to ensure it's awaited properly
    
    if (!_initialized) {
      _initialized = true;
      
      // We no longer add welcome message here automatically, 
      // the provider can start empty and we can show a welcome UI or add it if empty.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final userId = ref.read(selectedFarmerIdProvider);
        if (userId.isNotEmpty) {
          final messages = ref.read(chatProvider(userId));
          if (messages.isEmpty) {
            ref.read(chatProvider(userId).notifier).addMessage(ChatMessage(
              text: L10n.tr(context, 'welcome_msg') ?? 'Welcome',
              isUser: false,
            ));
          }
        }
      });
    }
  }
  
  @override
  void dispose() {
    _audioRecorder.dispose();
    _flutterTts.stop();
    _controller.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _speak(String text) async {
    try {
      final locale = Localizations.localeOf(context);
      final langStr = '${locale.languageCode}-${locale.countryCode ?? (locale.languageCode == 'en' ? 'US' : locale.languageCode.toUpperCase())}';
      await _flutterTts.setLanguage(langStr);
      await _flutterTts.speak(text);
    } catch (e) {
      debugPrint("TTS error: $e");
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _startRecording() async {
    final status = await Permission.microphone.request();
    if (status != PermissionStatus.granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.tr(context, 'mic_permission'))),
      );
      return;
    }
    
    AppTracker.info('Audio recording started');
    final dir = await getApplicationDocumentsDirectory();
    final path = '${dir.path}/voice_query.m4a';
    
    await _audioRecorder.start(
      const RecordConfig(encoder: AudioEncoder.aacLc),
      path: path,
    );
    
    setState(() {
      _isRecording = true;
    });
  }
  
  Future<void> _stopRecording() async {
    final path = await _audioRecorder.stop();
    setState(() {
      _isRecording = false;
    });
    
    if (path != null) {
      AppTracker.info('Audio recording stopped. Path: $path');
      _sendAudioMessage(path);
    } else {
      AppTracker.warn('Audio recording failed: no path returned');
    }
  }

  Future<void> _sendAudioMessage(String path) async {
    final userId = ref.read(selectedFarmerIdProvider);
    if (userId.isEmpty) return;

    final chatNotifier = ref.read(chatProvider(userId).notifier);
    chatNotifier.addMessage(ChatMessage(text: L10n.tr(context, 'voice_sent') ?? 'Voice message sent', isUser: true, isAudio: true));
    
    setState(() {
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final agentApi = ref.read(agentApiProvider);
      final reply = await agentApi.voiceChatWithAgent(userId, path);
      
      chatNotifier.addMessage(ChatMessage(text: reply, isUser: false));
      
      await _speak(reply);
    } catch (e) {
      chatNotifier.addMessage(ChatMessage(
        text: '${L10n.tr(context, 'connection_error') ?? 'Error'}\n\n(Hata Detayı: ${e.toString()})',
        isUser: false,
      ));
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery);
    if (file != null) {
      _sendImageMessage(file);
    }
  }

  Future<void> _sendImageMessage(XFile file) async {
    final path = file.path;
    final userId = ref.read(selectedFarmerIdProvider);
    if (userId.isEmpty) return;

    final chatNotifier = ref.read(chatProvider(userId).notifier);
    chatNotifier.addMessage(ChatMessage(
      text: L10n.tr(context, 'image_uploaded') ?? 'Görsel yüklendi', 
      isUser: true, 
      imagePath: path
    ));
    
    setState(() {
      _isLoading = true;
    });
    _scrollToBottom();

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        final reply = "Görsel kaydedildi ancak şu an internet bağlantınız yok. İnternet geldiğinde analiz edilmek üzere sıraya alındı.";
        chatNotifier.addMessage(ChatMessage(text: reply, isUser: false));
      } else {
        final agentApi = ref.read(agentApiProvider);
        final locale = Localizations.localeOf(context).languageCode;
        final response = await agentApi.scanPest(userId, file, locale);
        
        final diagnosis = response['local_threat_name'] ?? response['threat_name'] ?? 'Unknown';
        final recommendation = response['local_description'] ?? response['description'] ?? 'Consult expert';
        final urgency = response['severity'] ?? 'Unknown';
        
        final successMsg = L10n.tr(context, 'image_analyzed_success');
        final diagLabel = L10n.tr(context, 'diagnosis_label');
        final recLabel = L10n.tr(context, 'recommendation_label');
        final urgLabel = L10n.tr(context, 'urgency_label');
        final translatedUrgency = L10n.trSeverity(context, urgency);

        final reply = "$successMsg\n\n$diagLabel: $diagnosis\n\n$recLabel: $recommendation\n\n$urgLabel: $translatedUrgency";
        chatNotifier.addMessage(ChatMessage(text: reply, isUser: false));
        await _speak(reply);
      }
    } catch (e) {
      final errorMsg = L10n.tr(context, 'analysis_error');
      chatNotifier.addMessage(ChatMessage(text: "$errorMsg: $e", isUser: false));
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  Future<String> _buildOfflineContext(String userId) async {
    final prefs = ref.read(sharedPreferencesProvider);
    
    // Read farmer profile from cache to get dynamic location/region
    final farmerJson = prefs.getString('cache_farmer_$userId');
    
    // Extract location and region from cached farmer profile
    String location = '';
    String region = '';
    if (farmerJson != null) {
      try {
        final farmerData = jsonDecode(farmerJson) as Map<String, dynamic>;
        location = farmerData['location'] ?? '';
        region = farmerData['region'] ?? '';
      } catch (_) {}
    }
    
    // Use dynamic cache keys based on farmer's actual location
    final climateJson = location.isNotEmpty 
        ? prefs.getString('cache_climate_$location')
        : null;
    final threatJson = region.isNotEmpty 
        ? prefs.getString('cache_threat_$region')
        : null;
    final marketJson = prefs.getString('cache_market_forecast');
    
    String context = "You are an agricultural assistant. We are in offline mode. Here is the limited cached data available:\n";
    
    if (farmerJson != null) {
      context += "- Farmer Profile: $farmerJson\n";
    }
    if (climateJson != null) {
      context += "- Climate Status ($location): $climateJson\n";
    }
    if (threatJson != null) {
      context += "- Regional Threats ($region): $threatJson\n";
    }
    if (marketJson != null) {
      context += "- Market Status: $marketJson\n";
    }
    
    context += "\nBased on this information, answer the user's question. Provide a concise response.";
    return context;
  }

  Future<void> _sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    final userId = ref.read(selectedFarmerIdProvider);
    if (userId.isEmpty) return;

    final chatNotifier = ref.read(chatProvider(userId).notifier);

    chatNotifier.addMessage(ChatMessage(text: text, isUser: true));
    chatNotifier.addMessage(ChatMessage(text: '', isUser: false)); // Empty bot message to stream into
    
    setState(() {
      _isLoading = true;
    });
    _controller.clear();
    _scrollToBottom();
    
    AppTracker.info('Sending text message: $text');

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      final isOffline = connectivityResult.contains(ConnectivityResult.none);

      if (isOffline) {
        AppTracker.info('No internet detected. Using Offline Edge Agent (Gemma 4 E2B).');
        
        final contextStr = await _buildOfflineContext(userId);
        final enrichedPrompt = '$contextStr\n\nUser question: $text';
        
        final gemma = ref.read(gemmaProvider.notifier);
        final gemmaResponse = await gemma.generateResponse(enrichedPrompt);
        
        final formattedResponse = '[Gemma 4 - Offline]\n\n$gemmaResponse';
        chatNotifier.updateLastMessage(ChatMessage(text: formattedResponse, isUser: false));
        await _speak(gemmaResponse);
        
      } else {
        // Online Mode: use GCP AgriAgent backend
        final agentApi = ref.read(agentApiProvider);
        final stream = agentApi.streamChatWithAgent(userId, text);
        
        String finalSpokenText = '';
        
        await for (final chunk in stream) {
          final type = chunk['type'];
          final content = chunk['content'];
          
          
          final messages = ref.read(chatProvider(userId));
          if (messages.isEmpty) continue;
          final lastMsg = messages.last;

          if (type == 'thought') {
            AppTracker.info('AI Thought: $content');
          } else if (type == 'chunk') {
            chatNotifier.updateLastMessage(ChatMessage(text: lastMsg.text + content, isUser: false));
            finalSpokenText += content;
          } else if (type == 'message') {
            if (lastMsg.text.isEmpty || lastMsg.text.endsWith(']\n')) {
                chatNotifier.updateLastMessage(ChatMessage(text: lastMsg.text + content, isUser: false));
            } else {
                if (finalSpokenText.isEmpty) {
                  chatNotifier.updateLastMessage(ChatMessage(text: lastMsg.text + content, isUser: false));
                }
            }
            finalSpokenText = content; // for TTS
          } else if (type == 'error') {
            chatNotifier.updateLastMessage(ChatMessage(text: '${lastMsg.text}\n$content', isUser: false));
          }
          _scrollToBottom();
        }
        
        if (finalSpokenText.isNotEmpty) {
          AppTracker.info('Chatbot stream complete. Speaking: ${finalSpokenText.length} chars');
          await _speak(finalSpokenText);
        }
      }
    } catch (e) {
      AppTracker.error('Chatbot stream error: $e');
      final messages = ref.read(chatProvider(userId));
      if (messages.isNotEmpty) {
        chatNotifier.updateLastMessage(ChatMessage(
          text: L10n.tr(context, 'connection_error') ?? 'Sorry, I cannot connect right now.',
          isUser: false,
        ));
      }
    } finally {
      setState(() {
        _isLoading = false;
      });
      _scrollToBottom();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(L10n.tr(context, 'ai_assistant') ?? 'AI Assistant', style: TextStyle(color: Theme.of(context).colorScheme.primary)),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () {
              final userId = ref.read(selectedFarmerIdProvider);
              if (userId.isNotEmpty) {
                ref.read(chatProvider(userId).notifier).clearChat();
              }
            },
          ),
        ],
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Theme.of(context).colorScheme.onSurface),
          onPressed: () {
             _flutterTts.stop();
             context.go('/');
          },
        ),
      ),
      body: Consumer(
        builder: (context, ref, child) {
          final userId = ref.watch(selectedFarmerIdProvider);
          final messages = userId.isNotEmpty ? ref.watch(chatProvider(userId)) : [];
          
          return Column(
            children: [
              Expanded(
                child: ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index];
                    return _ChatBubble(message: msg)
                        .animate()
                        .slideY(begin: 0.5, end: 0, duration: 300.ms, curve: Curves.easeOutCubic)
                        .fadeIn(duration: 300.ms);
                  },
                ),
              ),
              if (_isLoading) _buildReasoningIndicator(context),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
            decoration: BoxDecoration(
              color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
              border: Border(top: BorderSide(color: Theme.of(context).dividerColor)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurface),
                    decoration: InputDecoration(
                      hintText: L10n.tr(context, 'type_message'),
                      hintStyle: TextStyle(color: Theme.of(context).colorScheme.onSurface.withOpacity(0.3)),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(24.0),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Theme.of(context).colorScheme.onSurface.withOpacity(0.05),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                const SizedBox(width: 4.0),
                IconButton(
                  icon: const Icon(Icons.add_photo_alternate_outlined),
                  color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
                  onPressed: _pickImage,
                ),
                const SizedBox(width: 4.0),
                GestureDetector(
                  onTap: () {
                    if (_isRecording) {
                      _stopRecording();
                    } else {
                      _startRecording();
                    }
                  },
                  child: CircleAvatar(
                    backgroundColor: _isRecording ? Colors.redAccent : Theme.of(context).colorScheme.onSurface.withOpacity(0.1),
                    child: Icon(_isRecording ? Icons.stop_rounded : Icons.mic, color: _isRecording ? Colors.white : Theme.of(context).colorScheme.onSurface),
                  ).animate(target: _isRecording ? 1 : 0).scale(end: const Offset(1.2, 1.2)),
                ),
                const SizedBox(width: 8.0),
                CircleAvatar(
                  backgroundColor: AgriAgentTheme.mossGreen,
                  child: IconButton(
                    icon: const Icon(Icons.send_rounded, color: Colors.white),
                    onPressed: _isLoading ? null : _sendMessage,
                  ).animate(target: _isLoading ? 1 : 0).scale(end: const Offset(0.8, 0.8)),
                ),
              ],
            ),
          ).animate().slideY(begin: 1, duration: 400.ms, curve: Curves.easeOutCubic),
        ],
      );
    }),
  );
}

  Widget _buildReasoningIndicator(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.psychology_rounded, color: AgriAgentTheme.mossGreen, size: 20)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .scale(begin: const Offset(0.9, 0.9), end: const Offset(1.1, 1.1), duration: 600.ms),
          const SizedBox(width: 8),
          Text(
            L10n.tr(context, 'agent_reasoning'),
            style: TextStyle(color: AgriAgentTheme.mossGreen.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 13),
          )
              .animate(onPlay: (c) => c.repeat())
              .shimmer(duration: 1500.ms, color: Colors.white),
        ],
      ),
    ).animate().fadeIn(duration: 300.ms).slideY(begin: 0.5);
  }
}

class _ChatBubble extends StatelessWidget {
  final ChatMessage message;

  const _ChatBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 6.0),
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
        decoration: BoxDecoration(
          color: message.isUser ? AgriAgentTheme.mossGreen : (Theme.of(context).cardTheme.color ?? Theme.of(context).cardColor),
          border: message.isUser ? null : Border.all(color: Theme.of(context).dividerColor.withOpacity(0.1)),
          borderRadius: BorderRadius.circular(16.0).copyWith(
            bottomRight: message.isUser ? const Radius.circular(4) : const Radius.circular(16.0),
            bottomLeft: !message.isUser ? const Radius.circular(4) : const Radius.circular(16.0),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.15),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.8,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (message.imagePath != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: kIsWeb
                      ? Image.network(
                          message.imagePath!,
                          width: 200,
                          fit: BoxFit.cover,
                        )
                      : Image.file(
                          File(message.imagePath!),
                          width: 200,
                          fit: BoxFit.cover,
                        ),
                ),
              ),
            Text(
              message.text,
              style: TextStyle(
                fontSize: 15.0, 
                color: message.isUser ? Colors.white : Theme.of(context).colorScheme.onSurface,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
