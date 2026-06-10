import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/app_logger.dart';

/// Custom API exception with status code and message.
class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic data;

  const ApiException({
    this.statusCode,
    required this.message,
    this.data,
  });

  @override
  String toString() => 'ApiException($statusCode): $message';

  /// Friendly user-facing error message.
  String get userMessage {
    if (statusCode == null) return 'Network error. Please check your connection.';
    if (statusCode! >= 500) return 'Server error. Please try again later.';
    if (statusCode == 404) return 'Resource not found.';
    if (statusCode == 422) return 'Invalid request data.';
    return message;
  }
}

/// Singleton Dio instance configured for the AgriAgent backend.
class ApiClient {
  /// Base URL of the backend.
  static String get _baseUrl {
    return 'https://agriagent-backend-385185579211.us-central1.run.app';
  }

  late final Dio dio;

  ApiClient() {
    dio = Dio(
      BaseOptions(
        baseUrl: _baseUrl,
        connectTimeout: const Duration(seconds: 15),
        receiveTimeout: const Duration(seconds: 300),
        sendTimeout: const Duration(seconds: 15),
        headers: {
          'Content-Type': 'application/json',
          'Accept': 'application/json',
        },
      ),
    );

    // Logging in debug mode
    if (kDebugMode) {
      dio.interceptors.add(InterceptorsWrapper(
        onRequest: (options, handler) {
          AppTracker.info('REQ: [${options.method}] ${options.uri}');
          handler.next(options);
        },
        onResponse: (response, handler) {
          AppTracker.info('RES: [${response.statusCode}] ${response.requestOptions.path}');
          handler.next(response);
        },
      ));
      
      dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (o) => debugPrint(o.toString()),
      ));
    }

    // Error interceptor that wraps DioExceptions into ApiExceptions
    dio.interceptors.add(InterceptorsWrapper(
      onError: (error, handler) {
        AppTracker.error('API_ERR: ${error.requestOptions.uri} -> ${error.message}');
        final apiError = ApiException(
          statusCode: error.response?.statusCode,
          message: _extractErrorMessage(error),
          data: error.response?.data,
        );
        handler.reject(DioException(
          requestOptions: error.requestOptions,
          error: apiError,
          type: error.type,
          response: error.response,
        ));
      },
    ));
  }

  /// Extracts a readable error message from a DioException.
  String _extractErrorMessage(DioException error) {
    // Try to get detail from FastAPI error response
    final data = error.response?.data;
    if (data is Map<String, dynamic>) {
      if (data.containsKey('detail')) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          return detail.map((e) => e['msg'] ?? e.toString()).join(', ');
        }
      }
    }

    // Fallback messages by error type
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
        return 'Connection timed out';
      case DioExceptionType.receiveTimeout:
        return 'Server took too long to respond';
      case DioExceptionType.sendTimeout:
        return 'Request timed out while sending';
      case DioExceptionType.connectionError:
        return 'Cannot connect to server';
      case DioExceptionType.cancel:
        return 'Request was cancelled';
      default:
        return error.message ?? 'An unexpected error occurred';
    }
  }

  /// Performs a GET request and returns the response data.
  Future<T> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    required T Function(dynamic data) parser,
  }) async {
    try {
      final response = await dio.get(path, queryParameters: queryParameters);
      return parser(response.data);
    } on DioException catch (e) {
      throw e.error as ApiException;
    }
  }

  /// Performs a POST request and returns the response data.
  Future<T> post<T>(
    String path, {
    dynamic data,
    required T Function(dynamic data) parser,
  }) async {
    try {
      final response = await dio.post(path, data: data);
      return parser(response.data);
    } on DioException catch (e) {
      throw e.error as ApiException;
    }
  }

  /// Performs a PUT request and returns the response data.
  Future<T> put<T>(
    String path, {
    dynamic data,
    required T Function(dynamic data) parser,
  }) async {
    try {
      final response = await dio.put(path, data: data);
      return parser(response.data);
    } on DioException catch (e) {
      throw e.error as ApiException;
    }
  }
}

/// Global Riverpod provider for the API client singleton.
final apiClientProvider = Provider<ApiClient>((ref) => ApiClient());
