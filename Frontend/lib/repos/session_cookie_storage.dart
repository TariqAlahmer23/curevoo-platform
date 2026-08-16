import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class SessionCookieStorage {
  SessionCookieStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _cookiesKey = 'auth_session_cookies';
  final FlutterSecureStorage _storage;

  Future<List<PersistedCookie>> readCookies() async {
    final rawValue = await _storage.read(key: _cookiesKey);
    if (rawValue == null || rawValue.isEmpty) {
      return const [];
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is! List) {
        return const [];
      }

      return decoded
          .whereType<Map>()
          .map(
            (entry) => PersistedCookie.fromJson(
              entry.map(
                (key, value) => MapEntry(key.toString(), value),
              ),
            ),
          )
          .toList();
    } catch (_) {
      return const [];
    }
  }

  Future<void> saveCookies(List<PersistedCookie> cookies) async {
    await _storage.write(
      key: _cookiesKey,
      value: jsonEncode(cookies.map((cookie) => cookie.toJson()).toList()),
    );
  }

  Future<void> clearCookies() async {
    await _storage.delete(key: _cookiesKey);
  }
}

class PersistedCookie {
  const PersistedCookie({
    required this.name,
    required this.value,
    required this.domain,
    required this.path,
    required this.isSecure,
    this.expiresAt,
  });

  final String name;
  final String value;
  final String domain;
  final String path;
  final bool isSecure;
  final DateTime? expiresAt;

  bool get isExpired =>
      expiresAt != null && !expiresAt!.isAfter(DateTime.now().toUtc());

  bool matches(Uri uri) {
    if (isExpired) return false;
    if (isSecure && uri.scheme.toLowerCase() != 'https') return false;

    final host = uri.host.toLowerCase();
    final normalizedDomain = domain.startsWith('.')
        ? domain.substring(1).toLowerCase()
        : domain.toLowerCase();

    if (host != normalizedDomain && !host.endsWith('.$normalizedDomain')) {
      return false;
    }

    final requestPath = uri.path.isEmpty ? '/' : uri.path;
    return requestPath.startsWith(path);
  }

  PersistedCookie copyWith({
    String? value,
    String? domain,
    String? path,
    bool? isSecure,
    DateTime? expiresAt,
  }) {
    return PersistedCookie(
      name: name,
      value: value ?? this.value,
      domain: domain ?? this.domain,
      path: path ?? this.path,
      isSecure: isSecure ?? this.isSecure,
      expiresAt: expiresAt ?? this.expiresAt,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'value': value,
      'domain': domain,
      'path': path,
      'isSecure': isSecure,
      'expiresAt': expiresAt?.toIso8601String(),
    };
  }

  factory PersistedCookie.fromJson(Map<String, dynamic> json) {
    return PersistedCookie(
      name: (json['name'] ?? '').toString(),
      value: (json['value'] ?? '').toString(),
      domain: (json['domain'] ?? '').toString(),
      path: (json['path'] ?? '/').toString(),
      isSecure: json['isSecure'] == true,
      expiresAt: json['expiresAt'] is String
          ? DateTime.tryParse(json['expiresAt'] as String)?.toUtc()
          : null,
    );
  }

  static PersistedCookie? fromSetCookieHeader(String header, Uri uri) {
    final parts = header
        .split(';')
        .map((part) => part.trim())
        .where((part) => part.isNotEmpty)
        .toList();

    if (parts.isEmpty) return null;

    final nameValueSeparator = parts.first.indexOf('=');
    if (nameValueSeparator <= 0) return null;

    final name = parts.first.substring(0, nameValueSeparator).trim();
    final value = parts.first.substring(nameValueSeparator + 1).trim();
    if (name.isEmpty) return null;

    var domain = uri.host;
    var path = _defaultPathFor(uri);
    var isSecure = false;
    DateTime? expiresAt;
    var shouldDelete = false;

    for (final attribute in parts.skip(1)) {
      final separator = attribute.indexOf('=');
      final attributeName = (separator == -1
              ? attribute
              : attribute.substring(0, separator))
          .trim()
          .toLowerCase();
      final attributeValue =
          separator == -1 ? '' : attribute.substring(separator + 1).trim();

      switch (attributeName) {
        case 'domain':
          if (attributeValue.isNotEmpty) {
            domain = attributeValue.toLowerCase();
          }
          break;
        case 'path':
          if (attributeValue.isNotEmpty) {
            path = attributeValue;
          }
          break;
        case 'secure':
          isSecure = true;
          break;
        case 'max-age':
          final seconds = int.tryParse(attributeValue);
          if (seconds != null) {
            if (seconds <= 0) {
              shouldDelete = true;
            } else {
              expiresAt = DateTime.now().toUtc().add(Duration(seconds: seconds));
            }
          }
          break;
        case 'expires':
          final parsed = DateTime.tryParse(attributeValue)?.toUtc();
          if (parsed != null) {
            expiresAt = parsed;
            shouldDelete = !parsed.isAfter(DateTime.now().toUtc());
          }
          break;
      }
    }

    if (shouldDelete || value.isEmpty) {
      return PersistedCookie(
        name: name,
        value: '',
        domain: domain,
        path: path,
        isSecure: isSecure,
        expiresAt: DateTime.fromMillisecondsSinceEpoch(0, isUtc: true),
      );
    }

    return PersistedCookie(
      name: name,
      value: value,
      domain: domain,
      path: path,
      isSecure: isSecure,
      expiresAt: expiresAt,
    );
  }

  static String _defaultPathFor(Uri uri) {
    final path = uri.path;
    if (path.isEmpty || !path.startsWith('/')) return '/';
    final separator = path.lastIndexOf('/');
    if (separator <= 0) return '/';
    return path.substring(0, separator);
  }
}
