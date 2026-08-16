import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'session_cookie_storage.dart';

class MainRepo {
  MainRepo({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 20),
    Map<String, String>? defaultHeaders,
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        defaultHeaders = {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
          ...?defaultHeaders,
        };

  final String baseUrl;
  final Duration timeout;
  final Map<String, String> defaultHeaders;

  final http.Client _client;
  final bool _ownsClient;

  static final _cookieStore = _SessionCookieStore(
    storage: SessionCookieStorage(),
  );

  Future<dynamic> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _send(
      method: 'GET',
      endpoint: endpoint,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<dynamic> post(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _send(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<dynamic> postMultipart(
    String endpoint, {
    Map<String, dynamic>? fields,
    List<MultipartFileData>? files,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _sendMultipart(
      method: 'POST',
      endpoint: endpoint,
      fields: fields,
      files: files,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<dynamic> put(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _send(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<dynamic> patch(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _send(
      method: 'PATCH',
      endpoint: endpoint,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<dynamic> delete(
    String endpoint, {
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) {
    return _send(
      method: 'DELETE',
      endpoint: endpoint,
      body: body,
      queryParameters: queryParameters,
      headers: headers,
    );
  }

  Future<dynamic> _send({
    required String method,
    required String endpoint,
    dynamic body,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final mergedHeaders = await _buildHeaders(
      uri,
      headers,
      method: method,
    );
    final encodedBody = _encodeBody(body);

    try {
      late http.Response response;

      switch (method) {
        case 'GET':
          response = await _client
              .get(uri, headers: mergedHeaders)
              .timeout(timeout);
          break;
        case 'POST':
          response = await _client
              .post(uri, headers: mergedHeaders, body: encodedBody)
              .timeout(timeout);
          break;
        case 'PUT':
          response = await _client
              .put(uri, headers: mergedHeaders, body: encodedBody)
              .timeout(timeout);
          break;
        case 'PATCH':
          response = await _client
              .patch(uri, headers: mergedHeaders, body: encodedBody)
              .timeout(timeout);
          break;
        case 'DELETE':
          response = await _client
              .delete(uri, headers: mergedHeaders, body: encodedBody)
              .timeout(timeout);
          break;
        default:
          throw ApiException(message: 'Unsupported HTTP method: $method');
      }

      return _handleResponse(uri, response);
    } on TimeoutException {
      throw ApiException(message: 'Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw ApiException(message: 'Network error: ${e.message}');
    } on FormatException catch (e) {
      throw ApiException(message: 'Invalid response format: ${e.message}');
    }
  }

  Future<dynamic> _sendMultipart({
    required String method,
    required String endpoint,
    Map<String, dynamic>? fields,
    List<MultipartFileData>? files,
    Map<String, dynamic>? queryParameters,
    Map<String, String>? headers,
  }) async {
    final uri = _buildUri(endpoint, queryParameters);
    final mergedHeaders = await _mergeMultipartHeaders(
      uri,
      headers,
      method: method,
    );
    final request = http.MultipartRequest(method, uri)
      ..headers.addAll(mergedHeaders);

    if (fields != null) {
      fields.forEach((key, value) {
        if (value == null) return;

        if (value is Iterable) {
          request.fields[key] = jsonEncode(
            value.where((item) => item != null).toList(),
          );
          return;
        }

        request.fields[key] = value.toString();
      });
    }

    if (files != null) {
      for (final file in files) {
        request.files.add(
          http.MultipartFile.fromBytes(
            file.field,
            file.bytes,
            filename: file.filename,
          ),
        );
      }
    }

    try {
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);
      return _handleResponse(uri, response);
    } on TimeoutException {
      throw ApiException(message: 'Request timed out. Please try again.');
    } on http.ClientException catch (e) {
      throw ApiException(message: 'Network error: ${e.message}');
    } on FormatException catch (e) {
      throw ApiException(message: 'Invalid response format: ${e.message}');
    }
  }

  Future<dynamic> _handleResponse(Uri uri, http.Response response) async {
    await _cookieStore.capture(uri, response.headers);

    final statusCode = response.statusCode;
    final responseBody = _decodeResponseBody(response.body);

    if (statusCode >= 200 && statusCode < 300) {
      return responseBody;
    }

    throw ApiException(
      message: _extractErrorMessage(responseBody) ?? 'Request failed.',
      statusCode: statusCode,
      data: responseBody,
    );
  }

  String? _encodeBody(dynamic body) {
    if (body == null) return null;
    if (body is String) return body;
    return jsonEncode(body);
  }

  dynamic _decodeResponseBody(String body) {
    if (body.isEmpty) return null;

    try {
      return jsonDecode(body);
    } catch (_) {
      return body;
    }
  }

  String? _extractErrorMessage(dynamic body) {
    if (body is Map<String, dynamic>) {
      final directMessage = body['message'] ?? body['detail'];
      if (directMessage is String && directMessage.trim().isNotEmpty) {
        return directMessage;
      }

      final nestedError = body['error'];
      if (nestedError is String && nestedError.trim().isNotEmpty) {
        return nestedError;
      }

      if (nestedError is Map) {
        final typedError = nestedError.map(
          (key, dynamic value) => MapEntry(key.toString(), value),
        );
        final nestedMessage = typedError['message'];
        final details = typedError['details'];

        if (nestedMessage is String && nestedMessage.trim().isNotEmpty) {
          final detailsMessage = _extractValidationDetails(details);
          if (detailsMessage == null) {
            return nestedMessage;
          }
          return '$nestedMessage: $detailsMessage';
        }
      }
    }

    if (body is String && body.trim().isNotEmpty) {
      return body;
    }

    return null;
  }

  String? _extractValidationDetails(dynamic details) {
    if (details is List) {
      final messages = details
          .map(_stringifyValidationDetail)
          .where((message) => message != null && message.trim().isNotEmpty)
          .cast<String>()
          .toList(growable: false);
      if (messages.isNotEmpty) {
        return messages.join(', ');
      }
    }

    final singleMessage = _stringifyValidationDetail(details);
    if (singleMessage != null && singleMessage.trim().isNotEmpty) {
      return singleMessage;
    }

    return null;
  }

  String? _stringifyValidationDetail(dynamic detail) {
    if (detail == null) return null;
    if (detail is String && detail.trim().isNotEmpty) {
      return detail.trim();
    }
    if (detail is Map) {
      final typedDetail = detail.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      final path = typedDetail['path'] ?? typedDetail['field'];
      final message = typedDetail['message'] ?? typedDetail['detail'];
      if (path is String &&
          path.trim().isNotEmpty &&
          message is String &&
          message.trim().isNotEmpty) {
        return '${path.trim()}: ${message.trim()}';
      }
      if (message is String && message.trim().isNotEmpty) {
        return message.trim();
      }
    }
    return null;
  }

  Future<Map<String, String>> _buildHeaders(
    Uri uri,
    Map<String, String>? headers,
    {required String method}
  ) async {
    final merged = {...defaultHeaders, ...?headers};
    final cookieHeader = await _cookieStore.cookieHeaderFor(uri);
    if (cookieHeader != null && cookieHeader.isNotEmpty) {
      merged['Cookie'] = cookieHeader;
    }
    if (_shouldAttachCsrfToken(method) && !_containsHeader(merged, 'x-csrf-token')) {
      final csrfToken = await _cookieStore.cookieValueFor(uri, 'csrf_token');
      if (csrfToken != null && csrfToken.isNotEmpty) {
        merged['x-csrf-token'] = csrfToken;
      }
    }
    return merged;
  }

  Future<Map<String, String>> _mergeMultipartHeaders(
    Uri uri,
    Map<String, String>? headers,
    {required String method}
  ) async {
    final merged = await _buildHeaders(uri, headers, method: method);
    final contentTypeKey = merged.keys.firstWhere(
      (key) => key.toLowerCase() == 'content-type',
      orElse: () => '',
    );

    if (contentTypeKey.isNotEmpty) {
      merged.remove(contentTypeKey);
    }

    return merged;
  }

  bool _shouldAttachCsrfToken(String method) {
    switch (method.toUpperCase()) {
      case 'POST':
      case 'PUT':
      case 'PATCH':
      case 'DELETE':
        return true;
      default:
        return false;
    }
  }

  bool _containsHeader(Map<String, String> headers, String headerName) {
    return headers.keys.any((key) => key.toLowerCase() == headerName.toLowerCase());
  }

  Uri _buildUri(String endpoint, Map<String, dynamic>? queryParameters) {
    final String normalizedEndpoint;
    if (endpoint.startsWith('http://') || endpoint.startsWith('https://')) {
      normalizedEndpoint = endpoint;
    } else {
      final base = baseUrl.endsWith('/')
          ? baseUrl.substring(0, baseUrl.length - 1)
          : baseUrl;
      final path = endpoint.startsWith('/') ? endpoint.substring(1) : endpoint;
      normalizedEndpoint = '$base/$path';
    }

    final uri = Uri.parse(normalizedEndpoint);
    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final query = <String, String>{};
    queryParameters.forEach((key, value) {
      if (value != null) {
        query[key] = value.toString();
      }
    });

    return uri.replace(queryParameters: query.isEmpty ? null : query);
  }

  void close() {
    if (_ownsClient) {
      _client.close();
    }
  }

  static Future<void> clearSessionCookies() {
    return _cookieStore.clear();
  }
}

class MultipartFileData {
  MultipartFileData({
    required this.field,
    required this.bytes,
    required this.filename,
  });

  final String field;
  final Uint8List bytes;
  final String filename;
}

class ApiException implements Exception {
  ApiException({
    required this.message,
    this.statusCode,
    this.data,
  });

  final String message;
  final int? statusCode;
  final dynamic data;

  @override
  String toString() {
    if (statusCode == null) return 'ApiException: $message';
    return 'ApiException($statusCode): $message';
  }
}

class _SessionCookieStore {
  _SessionCookieStore({required SessionCookieStorage storage})
      : _storage = storage;

  final SessionCookieStorage _storage;
  List<PersistedCookie>? _cache;

  Future<void> _ensureLoaded() async {
    _cache ??= await _storage.readCookies();
    _cache = _cache!
        .where((cookie) => cookie.name.isNotEmpty && !cookie.isExpired)
        .toList();
  }

  Future<String?> cookieHeaderFor(Uri uri) async {
    await _ensureLoaded();
    final matches = _cache!.where((cookie) => cookie.matches(uri)).toList();
    if (matches.isEmpty) return null;

    return matches.map((cookie) => '${cookie.name}=${cookie.value}').join('; ');
  }

  Future<String?> cookieValueFor(Uri uri, String cookieName) async {
    await _ensureLoaded();
    for (final cookie in _cache!) {
      if (cookie.matches(uri) && cookie.name == cookieName) {
        return cookie.value;
      }
    }
    return null;
  }

  Future<void> capture(Uri uri, Map<String, String> headers) async {
    final setCookieHeader = headers.entries
        .firstWhere(
          (entry) => entry.key.toLowerCase() == 'set-cookie',
          orElse: () => const MapEntry('', ''),
        )
        .value;

    if (setCookieHeader.isEmpty) return;

    await _ensureLoaded();

    for (final rawCookie in _splitSetCookieHeader(setCookieHeader)) {
      final parsedCookie = PersistedCookie.fromSetCookieHeader(rawCookie, uri);
      if (parsedCookie == null) continue;

      _cache!.removeWhere(
        (cookie) =>
            cookie.name == parsedCookie.name &&
            cookie.domain == parsedCookie.domain &&
            cookie.path == parsedCookie.path,
      );

      if (!parsedCookie.isExpired && parsedCookie.value.isNotEmpty) {
        _cache!.add(parsedCookie);
      }
    }

    await _storage.saveCookies(_cache!);
  }

  Future<void> clear() async {
    _cache = const [];
    await _storage.clearCookies();
  }

  List<String> _splitSetCookieHeader(String header) {
    final cookies = <String>[];
    final buffer = StringBuffer();
    var inExpiresAttribute = false;

    for (var i = 0; i < header.length; i++) {
      final char = header[i];
      if (char == ',') {
        final remainder = header.substring(i + 1);
        if (!inExpiresAttribute &&
            RegExp(r'^\s*[A-Za-z0-9_\-]+=') .hasMatch(remainder)) {
          cookies.add(buffer.toString().trim());
          buffer.clear();
          continue;
        }
      }

      buffer.write(char);

      final current = buffer.toString().toLowerCase();
      if (current.endsWith('expires=')) {
        inExpiresAttribute = true;
      } else if (inExpiresAttribute && char == ';') {
        inExpiresAttribute = false;
      }
    }

    final lastCookie = buffer.toString().trim();
    if (lastCookie.isNotEmpty) {
      cookies.add(lastCookie);
    }

    return cookies;
  }
}
