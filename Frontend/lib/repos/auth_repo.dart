import 'package:curevoo_doctor/models/doctor.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:flutter/foundation.dart';

class AuthResponse {
  AuthResponse({required this.doctor, this.token});

  final Doctor doctor;
  final String? token;
}

class AuthRepo {
  AuthRepo({
    required MainRepo mainRepo,
    this.loginEndpoint = '/auth/login',
    this.signupEndpoint = '/auth/register-doctor',
    this.validateEndpoint = '/auth/validate-token',
    this.refreshEndpoint = '/auth/refresh',
    this.logoutEndpoint = '/auth/logout',
    this.deleteAccountEndpoint = '/registration/delete-account',
    this.changePasswordEndpoint = '/registration/change-password',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String loginEndpoint;
  final String signupEndpoint;
  final String validateEndpoint;
  final String refreshEndpoint;
  final String logoutEndpoint;
  final String deleteAccountEndpoint;
  final String changePasswordEndpoint;

  Future<AuthResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _mainRepo.post(
      loginEndpoint,
      body: {'email': email, 'password': password},
    );

    return _parseAuthResponse(response);
  }

  Future<AuthResponse> signup(Map<String, dynamic> payload) async {
    final fields = Map<String, dynamic>.from(payload);
    final photoBytes = fields.remove('photoBytes');
    final photoName = fields.remove('photoName');

    final response = await _mainRepo.postMultipart(
      signupEndpoint,
      fields: fields,
      files:
          photoBytes is Uint8List && photoName is String && photoName.isNotEmpty
          ? [
              MultipartFileData(
                field: 'photo',
                bytes: photoBytes,
                filename: photoName,
              ),
            ]
          : null,
    );

    return _parseSignupResponse(response, fields);
  }

  Future<AuthResponse> validateToken(String token) async {
    try {
      final response = await _mainRepo.get(
        validateEndpoint,
        headers: _authHeaders(token),
      );
      return _parseValidationResponse(response, fallbackToken: token);
    } on ApiException catch (e) {
      if (e.statusCode == 404 || e.statusCode == 405) {
        final response = await _mainRepo.post(
          validateEndpoint,
          headers: _authHeaders(token),
          body: {'token': token},
        );
        return _parseValidationResponse(response, fallbackToken: token);
      }
      rethrow;
    }
  }

  Future<String> refreshAccessToken() async {
    final response = await _mainRepo.post(refreshEndpoint);
    final token = _extractToken(_toMap(response));
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Could not parse refreshed access token.');
    }
    return token;
  }

  Future<void> logout() async {
    await _mainRepo.post(logoutEndpoint);
  }

  Future<void> deleteAccount(String token) async {
    await _mainRepo.delete(deleteAccountEndpoint, headers: _authHeaders(token));
  }

  Future<void> changePassword(
    String token, {
    required String currentPassword,
    required String newPassword,
  }) async {
    await _mainRepo.post(
      changePasswordEndpoint,
      headers: _authHeaders(token),
      body: {'currentPassword': currentPassword, 'newPassword': newPassword},
    );
  }

  void close() {
    _mainRepo.close();
  }

  AuthResponse _parseAuthResponse(dynamic data, {String? fallbackToken}) {
    final Map<String, dynamic> map = _toMap(data);
    final token = _extractToken(map) ?? fallbackToken;
    final doctor = _extractDoctor(map);

    if (doctor == null) {
      throw ApiException(message: 'Could not parse doctor data from response.');
    }

    return AuthResponse(doctor: doctor, token: token);
  }

  AuthResponse _parseSignupResponse(
    dynamic data,
    Map<String, dynamic> submittedFields,
  ) {
    final fallbackDoctor = _doctorFromSignupFields(submittedFields);
    if (data is! Map) {
      return AuthResponse(doctor: fallbackDoctor);
    }

    final map = _toMap(data);
    return AuthResponse(
      doctor: _containsDoctorData(map)
          ? (_extractDoctor(map) ?? fallbackDoctor)
          : fallbackDoctor,
      token: _extractToken(map),
    );
  }

  Doctor _doctorFromSignupFields(Map<String, dynamic> fields) {
    return Doctor(
      id: _readString(fields, ['id', '_id', 'doctorId', 'userId']) ?? '',
      name: _readString(fields, ['name', 'fullName', 'username']) ?? 'Doctor',
      email: _readString(fields, ['email']) ?? '',
      phoneNumber:
          _readString(fields, ['phoneNumber', 'phone', 'mobile']) ?? '',
      age: _readInt(fields, ['age']) ?? 25,
      profile: DoctorProfile(
        specialization:
            _readString(fields, ['specialization', 'speciality']) ?? '',
        workPlace:
            _readString(fields, ['workPlace', 'workplace', 'hospital']) ?? '',
        languages: _readStringList(fields, 'languages'),
        location: _readString(fields, ['location', 'address']) ?? '',
        experience:
            _readString(fields, ['experience', 'yearsExperience']) ??
            (_readInt(fields, ['experience', 'yearsExperience'])?.toString() ??
                ''),
      ),
    );
  }

  bool _containsDoctorData(Map<String, dynamic> map) {
    if (map.keys.any(
      const [
        'doctor',
        'user',
        'profile',
        'id',
        '_id',
        'doctorId',
        'userId',
        'name',
        'fullName',
        'username',
        'email',
      ].contains,
    )) {
      return true;
    }

    final nestedData = map['data'];
    return nestedData is Map &&
        nestedData.keys.any(
          const [
            'doctor',
            'user',
            'profile',
            'id',
            '_id',
            'doctorId',
            'userId',
            'name',
            'fullName',
            'username',
            'email',
          ].contains,
        );
  }

  AuthResponse _parseValidationResponse(dynamic data, {String? fallbackToken}) {
    final Map<String, dynamic> map = _toMap(data);
    final token = _extractToken(map) ?? fallbackToken;
    final nestedData = map['data'];
    final valid = nestedData is Map<String, dynamic>
        ? nestedData['valid']
        : null;

    if (valid == false) {
      throw ApiException(message: 'Token is invalid or expired.');
    }

    final doctor = _extractDoctor(map) ?? _extractMinimalDoctor(map);
    if (doctor == null) {
      throw ApiException(message: 'Could not parse validation response.');
    }

    return AuthResponse(doctor: doctor, token: token);
  }

  Doctor? _extractDoctor(Map<String, dynamic> map) {
    final dynamic rootDoctor = map['doctor'] ?? map['user'] ?? map['profile'];
    final dynamic nestedData = map['data'];
    final dynamic nestedDoctor = nestedData is Map<String, dynamic>
        ? nestedData['doctor'] ?? nestedData['user'] ?? nestedData['profile']
        : null;
    final dynamic source = rootDoctor ?? nestedDoctor ?? map;

    if (source is! Map<String, dynamic>) {
      return null;
    }

    final profileMap = _extractProfile(source, nestedData);

    final name = _readString(source, ['name', 'fullName', 'username']) ?? '';
    final email = _readString(source, ['email']) ?? '';
    final phone = _readString(source, ['phoneNumber', 'phone', 'mobile']) ?? '';
    final age = _readInt(source, ['age']) ?? 25;

    return Doctor(
      id: _readString(source, ['id', '_id', 'doctorId', 'userId']) ?? '',
      name: name.isEmpty ? 'Doctor' : name,
      email: email,
      phoneNumber: phone,
      age: age,
      qrCode:
          _readString(source, ['qrCode', 'qr_code']) ??
          _readString(profileMap, ['qrCode', 'qr_code']) ??
          (nestedData is Map<String, dynamic>
              ? _readString(nestedData, ['qrString'])
              : null),
      bio: _readString(source, ['bio', 'about']),
      profile: DoctorProfile(
        specialization:
            _readString(profileMap, ['specialization', 'speciality']) ??
            _readString(source, ['specialization']) ??
            '',
        workPlace:
            _readString(profileMap, ['workPlace', 'workplace', 'hospital']) ??
            _readString(source, ['workPlace', 'workplace']) ??
            '',
        avatar: _readString(profileMap, [
          'avatar',
          'avatarUrl',
          'image',
          'photo',
          'photoUrl',
        ]),
        languages: _readStringList(profileMap, 'languages'),
        location: _readString(profileMap, ['location', 'address']) ?? '',
        experience:
            (_readInt(profileMap, ['experience', 'yearsExperience']) ??
                    _readInt(source, ['experience', 'yearsExperience']))
                ?.toString() ??
            _readString(profileMap, ['experience', 'yearsExperience']) ??
            '',
      ),
    );
  }

  Doctor? _extractMinimalDoctor(Map<String, dynamic> map) {
    final dynamic nestedData = map['data'];
    final dynamic user = nestedData is Map<String, dynamic>
        ? nestedData['user']
        : null;
    if (user is! Map<String, dynamic>) {
      return null;
    }

    final id = _readString(user, ['id', '_id', 'userId']) ?? '';
    if (id.isEmpty) {
      return null;
    }

    return Doctor(
      id: id,
      name: _readString(user, ['name', 'fullName', 'username']) ?? 'Doctor',
      email: _readString(user, ['email']) ?? '',
      phoneNumber: _readString(user, ['phoneNumber', 'phone', 'mobile']) ?? '',
      age: _readInt(user, ['age']) ?? 25,
      profile: DoctorProfile(
        specialization: '',
        workPlace: '',
        languages: const [],
        location: '',
        experience: '',
      ),
    );
  }

  Map<String, dynamic> _extractProfile(
    Map<String, dynamic> source,
    dynamic nestedData,
  ) {
    final candidates = <dynamic>[
      source['doctorProfile'],
      source['profile'],
      source['data'],
      nestedData is Map<String, dynamic> ? nestedData['doctorProfile'] : null,
      nestedData is Map<String, dynamic> ? nestedData['profile'] : null,
      nestedData is Map<String, dynamic> ? nestedData['user'] : null,
    ];

    for (final candidate in candidates) {
      if (candidate is Map<String, dynamic>) {
        final nestedDoctorProfile = candidate['doctorProfile'];
        if (nestedDoctorProfile is Map<String, dynamic>) {
          return nestedDoctorProfile;
        }
        return candidate;
      }
    }

    return <String, dynamic>{};
  }

  String? _extractToken(Map<String, dynamic> map) {
    final dynamic nestedData = map['data'];
    String? readFrom(Map<String, dynamic> source) {
      return _readString(source, [
        'token',
        'accessToken',
        'access_token',
        'jwt',
      ]);
    }

    final directToken = readFrom(map);
    if (directToken != null && directToken.isNotEmpty) return directToken;

    if (nestedData is Map<String, dynamic>) {
      final nestedToken = readFrom(nestedData);
      if (nestedToken != null && nestedToken.isNotEmpty) return nestedToken;
    }

    return null;
  }

  Map<String, String> _authHeaders(String token) {
    return {'Authorization': 'Bearer $token'};
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    throw ApiException(message: 'Unexpected response type from server.');
  }

  String? _readString(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
    }
    return null;
  }

  int? _readInt(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is int) return value;
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  List<String> _readStringList(Map<String, dynamic> map, String key) {
    final value = map[key];
    if (value is List) {
      return value
          .whereType<dynamic>()
          .map((e) => e.toString().trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();
    }
    return const [];
  }
}
