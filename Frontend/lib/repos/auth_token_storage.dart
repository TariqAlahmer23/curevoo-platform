import 'dart:convert';

import 'package:curevoo_doctor/models/doctor.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStorage {
  AuthTokenStorage({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  static const String _tokenKey = 'auth_access_token';
  static const String _doctorKey = 'auth_doctor_profile';
  static const String _rememberMeKey = 'auth_remember_me';
  final FlutterSecureStorage _storage;

  Future<void> saveToken(String token) async {
    await _storage.write(key: _tokenKey, value: token);
  }

  Future<String?> readToken() async {
    return _storage.read(key: _tokenKey);
  }

  Future<void> saveDoctor(Doctor doctor) async {
    await _storage.write(key: _doctorKey, value: jsonEncode(doctor.toJson()));
  }

  Future<Doctor?> readDoctor() async {
    final rawValue = await _storage.read(key: _doctorKey);
    if (rawValue == null || rawValue.isEmpty) {
      return null;
    }

    try {
      final decoded = jsonDecode(rawValue);
      if (decoded is Map<String, dynamic>) {
        return Doctor.fromJson(decoded);
      }
      if (decoded is Map) {
        return Doctor.fromJson(
          decoded.map(
            (key, value) => MapEntry(key.toString(), value),
          ),
        );
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  Future<void> saveRememberMe(bool value) async {
    await _storage.write(key: _rememberMeKey, value: value ? '1' : '0');
  }

  Future<bool> readRememberMe() async {
    final rawValue = await _storage.read(key: _rememberMeKey);
    return rawValue == '1' || rawValue?.toLowerCase() == 'true';
  }

  Future<void> clearToken() async {
    await _storage.delete(key: _tokenKey);
  }

  Future<void> clearDoctor() async {
    await _storage.delete(key: _doctorKey);
  }
}
