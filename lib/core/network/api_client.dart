// lib/core/network/api_client.dart
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:logger/logger.dart';
import '../errors/exceptions.dart';

class ApiClient {
  final String baseUrl;
  final Dio _dio;
  final Logger _logger = Logger();

  ApiClient({required this.baseUrl, Dio? dio}) : _dio = dio ?? Dio() {
    _dio.options.baseUrl = baseUrl;
    _dio.options.connectTimeout = const Duration(seconds: 15);
    _dio.options.receiveTimeout = const Duration(seconds: 15);
    _dio.options.headers = {'Content-Type': 'application/json'};

    // Add logging interceptor
    _dio.interceptors.add(
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        logPrint: (object) => _logger.d(object.toString()),
      ),
    );
  }

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) async {
    try {
      _logger.i('Making GET request to: $baseUrl$endpoint');

      final response = await _dio.get(
        endpoint,
        queryParameters: queryParameters,
      );

      _logger.i('Successfully received response from: $endpoint');
      _logger.d('Response data: ${response.data}');

      return response.data;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      _logger.e('Unknown error in GET $endpoint: $e');
      throw NetworkException('Unknown error: ${e.toString()}');
    }
  }

  Future<dynamic> post(String endpoint, {dynamic data}) async {
    try {
      _logger.i('Making POST request to: $baseUrl$endpoint');

      final response = await _dio.post(endpoint, data: data);

      _logger.i('Successfully received response from: $endpoint');

      return response.data;
    } on DioException catch (e) {
      _handleDioError(e);
    } catch (e) {
      _logger.e('Unknown error in POST $endpoint: $e');
      throw NetworkException('Unknown error: ${e.toString()}');
    }
  }

  Never _handleDioError(DioException e) {
    _logger.e('DioError: ${e.type} - ${e.message}');

    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        throw NetworkException('Connection timeout');
      case DioExceptionType.badResponse:
        final statusCode = e.response?.statusCode;
        if (statusCode == 400) {
          throw BadRequestException(
            e.response?.data.toString() ?? 'Bad request',
          );
        } else if (statusCode == 401 || statusCode == 403) {
          throw UnauthorizedException(
            e.response?.data.toString() ?? 'Unauthorized',
          );
        } else if (statusCode == 404) {
          throw NotFoundException(e.response?.data.toString() ?? 'Not found');
        } else {
          throw ServerException('Server error: $statusCode');
        }
      case DioExceptionType.cancel:
        throw NetworkException('Request canceled');
      case DioExceptionType.unknown:
      case DioExceptionType.badCertificate:
      case DioExceptionType.connectionError:
      default:
        if (e.error is SocketException) {
          throw NetworkException('No internet connection');
        }
        throw NetworkException('Network error: ${e.message}');
    }
  }
}
