import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../session_store.dart';

/// Base URL for the SPECTERRA backend.
///
/// Defaults to the live VPS. Override at build/run time with:
/// `flutter run --dart-define=API_BASE_URL=http://192.168.1.5:3000/api/v1`
///
/// Platform defaults (only when no --dart-define is given):
/// * All platforms → https://crm.nextradev.com/api/v1 (live VPS)
abstract final class ApiConfig {
  /// Live VPS backend. Override with
  /// `--dart-define=API_BASE_URL=<url>` for local dev.
  static const String _vpsUrl = 'https://crm.nextradev.com/api/v1';

  static const String _defaultLocal = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: '',
  );

  static String get baseUrl {
    if (_defaultLocal.isNotEmpty) return _normalized(_defaultLocal);
    return _vpsUrl;
  }

  static String _normalized(String value) =>
      value.endsWith('/') ? value.substring(0, value.length - 1) : value;

  static Duration get timeout => const Duration(seconds: 15);
  static Duration get uploadTimeout => const Duration(seconds: 120);

  static String resolveMediaUrl(String value, {String? apiBaseUrl}) {
    final trimmed = value.trim();
    if (trimmed.isEmpty) return '';
    final uri = Uri.tryParse(trimmed);
    if (uri == null) return trimmed;
    if (uri.hasScheme) return uri.toString();
    final api = Uri.parse(apiBaseUrl ?? baseUrl);
    final origin = Uri(
      scheme: api.scheme,
      userInfo: api.userInfo,
      host: api.host,
      port: api.hasPort ? api.port : null,
    );
    return origin
        .resolve(trimmed.startsWith('/') ? trimmed : '/$trimmed')
        .toString();
  }
}

/// Thin HTTP client used by every repository.
///
/// Throws [ApiException] with a user-facing message on failure.
class ApiClient {
  ApiClient({http.Client? httpClient, String? baseUrl})
    : _http = httpClient ?? http.Client(),
      _baseUrl = baseUrl ?? ApiConfig.baseUrl;

  final http.Client _http;
  final String _baseUrl;

  String? _token;
  String? _refreshToken;
  Future<bool>? _refreshing;
  String? get token => _token;
  String? get refreshToken => _refreshToken;
  bool get hasToken => _token != null && _token!.isNotEmpty;

  void setToken(String? token) => _token = token;
  void setRefreshToken(String? token) => _refreshToken = token;
  String resolveMediaUrl(String value) =>
      ApiConfig.resolveMediaUrl(value, apiBaseUrl: _baseUrl);
  void clearToken() {
    _token = null;
    _refreshToken = null;
  }

  Uri uri(String path, [Map<String, String>? query]) {
    final normalized = path.startsWith('/') ? path : '/$path';
    final base = Uri.parse('$_baseUrl$normalized');
    if (query == null || query.isEmpty) return base;
    return base.replace(queryParameters: {...base.queryParameters, ...query});
  }

  Map<String, String> _headers({bool json = true}) {
    final headers = <String, String>{
      'Accept': 'application/json',
      if (json) 'Content-Type': 'application/json',
    };
    if (hasToken) headers['Authorization'] = 'Bearer $_token';
    return headers;
  }

  Future<dynamic> get(String path, {Map<String, String>? query}) async {
    return _decode(
      await _sendWithRefresh(
        path,
        (headers) => _http.get(uri(path, query), headers: headers),
        json: false,
      ),
    );
  }

  Future<dynamic> post(String path, {Object? body}) async {
    return _decode(
      await _sendWithRefresh(
        path,
        (headers) => _http.post(
          uri(path),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
      ),
    );
  }

  Future<dynamic> put(String path, {Object? body}) async {
    return _decode(
      await _sendWithRefresh(
        path,
        (headers) => _http.put(
          uri(path),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
      ),
    );
  }

  Future<dynamic> patch(String path, {Object? body}) async {
    return _decode(
      await _sendWithRefresh(
        path,
        (headers) => _http.patch(
          uri(path),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
      ),
    );
  }

  Future<dynamic> delete(String path, {Object? body}) async {
    return _decode(
      await _sendWithRefresh(
        path,
        (headers) => _http.delete(
          uri(path),
          headers: headers,
          body: body == null ? null : jsonEncode(body),
        ),
      ),
    );
  }

  Future<http.Response> _sendWithRefresh(
    String path,
    Future<http.Response> Function(Map<String, String>) send, {
    bool json = true,
    Duration? timeout,
  }) async {
    final requestTimeout = timeout ?? ApiConfig.timeout;
    var response = await send(
      _headers(json: json),
    ).timeout(requestTimeout);
    if (response.statusCode == 401 &&
        _refreshToken != null &&
        !path.endsWith('/auth/refresh')) {
      final refreshed = await (_refreshing ??= _refresh());
      _refreshing = null;
      if (refreshed) {
        response = await send(
          _headers(json: json),
        ).timeout(requestTimeout);
      }
    }
    return response;
  }

  Future<bool> _refresh() async {
    try {
      final response = await _http
          .post(
            uri('/auth/refresh'),
            headers: {
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'refreshToken': _refreshToken}),
          )
          .timeout(ApiConfig.timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) return false;
      final decoded = response.body.isEmpty ? null : jsonDecode(response.body);
      final access = _findToken(decoded, const [
        'accessToken',
        'access_token',
        'token',
      ]);
      if (access == null) return false;
      _token = access;
      _refreshToken =
          _findToken(decoded, const ['refreshToken', 'refresh_token']) ??
          _refreshToken;
      await SessionStore.instance.updateTokens(
        token: access,
        refreshToken: _refreshToken,
      );
      return true;
    } catch (_) {
      return false;
    }
  }

  String? _findToken(dynamic value, List<String> keys) {
    if (value is! Map) return null;
    for (final key in keys) {
      final candidate = value[key];
      if (candidate is String && candidate.isNotEmpty) return candidate;
    }
    for (final key in const ['data', 'tokens', 'auth']) {
      final found = _findToken(value[key], keys);
      if (found != null) return found;
    }
    return null;
  }

  /// Multipart upload for `POST /work-photos` (field `photo` + text fields).
  /// Uses [http.MultipartRequest] so JPEG/PNG/WEBP bytes can stream with the
  /// bearer token attached.
  Future<dynamic> uploadMultipart(
    String path, {
    required String fileField,
    required String fileName,
    required List<int> fileBytes,
    String? contentType,
    Map<String, String> fields = const {},
  }) async {
    return _decode(
      await _sendWithRefresh(
        path,
        (headers) async {
          final request = http.MultipartRequest('POST', uri(path))
            ..headers.addAll(headers)
            ..fields.addAll(fields)
            ..files.add(
              http.MultipartFile.fromBytes(
                fileField,
                fileBytes,
                filename: fileName,
                contentType: contentType == null
                    ? null
                    : MediaType.parse(contentType),
              ),
            );
          return http.Response.fromStream(await _http.send(request));
        },
        json: false,
        timeout: ApiConfig.uploadTimeout,
      ),
    );
  }

  Future<dynamic> uploadMultipartBatch(
    String path, {
    required String fileField,
    required List<http.MultipartFile> files,
    Map<String, String> fields = const {},
  }) async {
    return _decode(
      await _sendWithRefresh(
        path,
        (headers) async {
          final request = http.MultipartRequest('POST', uri(path))
            ..headers.addAll(headers)
            ..fields.addAll(fields)
            ..files.addAll(files);
          return http.Response.fromStream(await _http.send(request));
        },
        json: false,
        timeout: ApiConfig.uploadTimeout,
      ),
    );
  }

  dynamic _decode(http.Response response) {
    dynamic data;
    try {
      data = response.body.isEmpty ? null : jsonDecode(response.body);
    } catch (_) {
      data = response.body;
    }
    if (response.statusCode >= 200 && response.statusCode < 300) {
      return data;
    }
    final message = _errorMessage(data, response.statusCode);
    throw ApiException(message, statusCode: response.statusCode);
  }

  String _errorMessage(dynamic data, int status) {
    if (data is Map<String, dynamic>) {
      String? validationDetails(dynamic value) {
        if (value is List && value.isNotEmpty) {
          return value.map((item) => item.toString()).join(', ');
        }
        if (value is String && value.trim().isNotEmpty) return value.trim();
        if (value is Map) {
          final details = value.entries
              .map((entry) {
                final message = validationDetails(entry.value);
                return message == null || message.isEmpty
                    ? null
                    : '${entry.key}: $message';
              })
              .whereType<String>()
              .toList();
          if (details.isNotEmpty) return details.join(', ');
        }
        return null;
      }

      final errors = data['errors'] ?? data['validationErrors'];
      final details = validationDetails(errors);
      for (final key in ['message', 'error', 'msg']) {
        final value = data[key];
        if (value is String && value.trim().isNotEmpty) {
          if (details != null &&
              value.trim().toLowerCase().contains('validation')) {
            return '${value.trim()}: $details';
          }
          return value.trim();
        }
        if (value is List && value.isNotEmpty) {
          return value.map((item) => item.toString()).join(', ');
        }
      }
      if (details != null) return details;
    }
    if (data is String && data.trim().isNotEmpty && data.length < 200) {
      return data.trim();
    }
    return switch (status) {
      400 => 'Invalid request. Please check your input.',
      401 => 'Invalid credentials. Please try again.',
      403 => 'You do not have access to this.',
      404 => 'Not found.',
      409 => 'This already exists.',
      422 => 'Please check your input and try again.',
      >= 500 => 'Server error. Please try again in a moment.',
      _ => 'Something went wrong. Please try again.',
    };
  }

  void close() => _http.close();
}

/// User-facing HTTP failure.
class ApiException implements Exception {
  const ApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  bool get isUnauthorized => statusCode == 401;
  bool get isNetworkError => statusCode == null;

  @override
  String toString() => message;
}
