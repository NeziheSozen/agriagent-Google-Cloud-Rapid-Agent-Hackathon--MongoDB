import 'dart:io' show Platform;
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_gemma/flutter_gemma.dart';

import 'package:wakelock_plus/wakelock_plus.dart';

import 'app/app.dart';
import 'providers/shared_prefs_provider.dart';
import 'providers/farmer_provider.dart';
import 'providers/locale_provider.dart';
import 'utils/app_logger.dart';
import 'services/push_notification_service.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await FlutterGemma.initialize();
  WakelockPlus.enable();
  AppTracker.info('Initializing application...');
  
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);
  } catch (e) {
    AppTracker.warn('Firebase initialization skipped (flutterfire configure run required): $e');
  }
  
  final prefs = await SharedPreferences.getInstance();
  
  // Check if user is already logged in
  final savedUserId = prefs.getString('logged_in_user_id');
  bool isLoggedIn = savedUserId != null && savedUserId.isNotEmpty;
  
  // Validate that saved user still exists on server
  if (isLoggedIn) {
    try {
      String baseUrl = 'https://agriagent-backend-385185579211.us-central1.run.app';
      final dio = Dio(BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 5),
      ));
      await dio.get('/profile/$savedUserId');
    } catch (e) {
      // User doesn't exist anymore or server unreachable
      await prefs.remove('logged_in_user_id');
      isLoggedIn = false;
    }
  }
  
  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        if (isLoggedIn)
          selectedFarmerIdProvider.overrideWithValue(savedUserId!),
      ],
      child: AgriAgentApp(
        initialLocation: isLoggedIn ? '/' : '/login',
      ),
    ),
  );
}
