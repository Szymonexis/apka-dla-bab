import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Wyjątek z czytelnym dla użytkownika komunikatem (przychodzi z API po polsku).
class ApiException implements Exception {
  final int status;
  final String message;
  ApiException(this.status, this.message);

  @override
  String toString() => message;
}

/// Prosty klient HTTP - singleton `Api.i`.
class Api {
  Api._();
  static final Api i = Api._();

  static const _tokenKey = 'token';
  static const _baseUrlKey = 'baseUrl';
  static const _nameKey = 'displayName';

  /// 10.0.2.2 to localhost komputera widziany z emulatora Androida.
  String baseUrl = 'http://10.0.2.2:8080';
  String? token;
  String displayName = '';

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    baseUrl = prefs.getString(_baseUrlKey) ?? baseUrl;
    token = prefs.getString(_tokenKey);
    displayName = prefs.getString(_nameKey) ?? '';
  }

  bool get isLoggedIn => token != null;

  Future<void> setBaseUrl(String url) async {
    baseUrl = url.trim().replaceAll(RegExp(r'/+$'), '');
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_baseUrlKey, baseUrl);
  }

  Future<void> _saveSession(String newToken, String name) async {
    token = newToken;
    displayName = name;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, newToken);
    await prefs.setString(_nameKey, name);
  }

  Future<void> logout() async {
    token = null;
    displayName = '';
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
    await prefs.remove(_nameKey);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (token != null) 'Authorization': 'Bearer $token',
      };

  /// Nagłówki do ładowania obrazków przez Image.network.
  Map<String, String> get imageHeaders =>
      {if (token != null) 'Authorization': 'Bearer $token'};

  String fileUrl(String fileId) => '$baseUrl/api/files/$fileId';

  Uri _uri(String path, [Map<String, String>? query]) {
    final u = Uri.parse('$baseUrl$path');
    return query == null ? u : u.replace(queryParameters: query);
  }

  Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, String>? query}) async {
    final uri = _uri(path, query);
    final encoded = body == null ? null : jsonEncode(body);
    http.Response res;
    try {
      switch (method) {
        case 'GET':
          res = await http.get(uri, headers: _headers);
        case 'POST':
          res = await http.post(uri, headers: _headers, body: encoded);
        case 'PUT':
          res = await http.put(uri, headers: _headers, body: encoded);
        case 'DELETE':
          res = await http.delete(uri, headers: _headers);
        default:
          throw ArgumentError('unsupported method $method');
      }
    } on SocketException {
      throw ApiException(0, 'Brak połączenia z serwerem ($baseUrl)');
    } on http.ClientException {
      throw ApiException(0, 'Brak połączenia z serwerem ($baseUrl)');
    }
    return _decode(res);
  }

  dynamic _decode(http.Response res) {
    if (res.statusCode >= 400) {
      var message = 'Błąd serwera (${res.statusCode})';
      try {
        final decoded = jsonDecode(utf8.decode(res.bodyBytes));
        if (decoded is Map && decoded['error'] is String) {
          message = decoded['error'] as String;
        }
      } catch (_) {}
      throw ApiException(res.statusCode, message);
    }
    if (res.bodyBytes.isEmpty) return null;
    return jsonDecode(utf8.decode(res.bodyBytes));
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) =>
      _send('GET', path, query: query);
  Future<dynamic> post(String path, {Object? body}) =>
      _send('POST', path, body: body);
  Future<dynamic> put(String path, {Object? body}) =>
      _send('PUT', path, body: body);
  Future<dynamic> delete(String path) => _send('DELETE', path);

  /// Wysyła plik (zdjęcie paragonu / przepisu) i zwraca jego id.
  Future<String> uploadFile(File file) async {
    final req = http.MultipartRequest('POST', _uri('/api/files'));
    if (token != null) req.headers['Authorization'] = 'Bearer $token';
    req.files.add(await http.MultipartFile.fromPath('file', file.path));
    http.Response res;
    try {
      res = await http.Response.fromStream(await req.send());
    } on SocketException {
      throw ApiException(0, 'Brak połączenia z serwerem ($baseUrl)');
    }
    final decoded = _decode(res);
    return (decoded as Map<String, dynamic>)['id'] as String;
  }

  // --- Autoryzacja ---

  Future<void> login(String email, String password) async {
    final res = await post('/api/auth/login',
        body: {'email': email, 'password': password});
    final map = res as Map<String, dynamic>;
    await _saveSession(map['token'] as String,
        (map['user']?['displayName'] ?? '') as String);
  }

  Future<void> register(String email, String password, String name) async {
    final res = await post('/api/auth/register',
        body: {'email': email, 'password': password, 'displayName': name});
    final map = res as Map<String, dynamic>;
    await _saveSession(map['token'] as String,
        (map['user']?['displayName'] ?? '') as String);
  }
}
