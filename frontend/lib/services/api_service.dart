import 'package:shared_preferences/shared_preferences.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

String getApiBaseUrl() {
  // Using physical device on local network
  return 'http://172.20.10.6:8000/api/';
}

class ApiService {
  final Dio _dio = Dio(
    BaseOptions(
      baseUrl: getApiBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  final Dio _publicDio = Dio(
    BaseOptions(
      baseUrl: getApiBaseUrl(),
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
    ),
  );

  ApiService() {
    _dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final prefs = await SharedPreferences.getInstance();
          final token = prefs.getString('access_token');
          if (token != null) {
            options.headers['Authorization'] = 'Bearer $token';
          }
          return handler.next(options);
        },
      ),
    );
  }

  Future<Response> post(String path, dynamic data) async {
    return await _dio.post(path, data: data);
  }

  Future<Response> put(String path, dynamic data) async {
    return await _dio.put(path, data: data);
  }

  Future<Response> patch(String path, dynamic data) async {
    return await _dio.patch(path, data: data);
  }

  Future<Response> get(String path) async {
    return await _dio.get(path);
  }

  Future<Response> delete(String path, {dynamic data}) async {
    return await _dio.delete(path, data: data);
  }

  // For unauthenticated requests (register, login)
  Future<Response> postPublic(String path, dynamic data) async {
    return await _publicDio.post(path, data: data);
  }

  Future<Response> getPublic(String path) async {
    return await _publicDio.get(path);
  }
}
