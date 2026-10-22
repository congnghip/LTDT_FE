import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../config/config_url.dart';

class ApiClient {
  final String baseUrl;

  ApiClient({String? baseUrl}) : baseUrl = baseUrl ?? Config_URL.baseUrl;

  Future<Map<String, String>> _buildHeaders(Map<String, String>? customHeaders) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };

    // Tự động gắn token JWT nếu đã lưu trong SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final token = prefs.getString('jwt_token');
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }

    if (customHeaders != null) {
      headers.addAll(customHeaders);
    }
    return headers;
  }

  Future<http.Response> get(String endpoint, {Map<String, String>? headers}) async {
    final requestHeaders = await _buildHeaders(headers);
    return http.get(
      Uri.parse('$baseUrl$endpoint'),
      headers: requestHeaders,
    );
  }

  Future<http.Response> post(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    final requestHeaders = await _buildHeaders(headers);
    return http.post(
      Uri.parse('$baseUrl$endpoint'),
      headers: requestHeaders,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> put(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    final requestHeaders = await _buildHeaders(headers);
    return http.put(
      Uri.parse('$baseUrl$endpoint'),
      headers: requestHeaders,
      body: jsonEncode(body),
    );
  }

  Future<http.Response> delete(String endpoint, {Map<String, String>? headers}) async {
    final requestHeaders = await _buildHeaders(headers);
    return http.delete(
      Uri.parse('$baseUrl$endpoint'),
      headers: requestHeaders,
    );
  }
}
