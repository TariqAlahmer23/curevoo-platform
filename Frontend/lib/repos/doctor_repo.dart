import 'package:curevoo_doctor/models/doctor.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:flutter/foundation.dart';

class DoctorRepo {
  DoctorRepo({
    required MainRepo mainRepo,
    this.profileEndpoint = '/doctor/profile',
    this.photoEndpoint = '/doctor/photo',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String profileEndpoint;
  final String photoEndpoint;

  Future<Doctor> getProfile(String token) async {
    final response = await _mainRepo.get(
      profileEndpoint,
      headers: _authHeaders(token),
    );
    return _parseDoctorResponse(response);
  }

  Future<Doctor> updateProfile(
    String token,
    Map<String, dynamic> payload,
  ) async {
    final response = await _mainRepo.put(
      profileEndpoint,
      headers: _authHeaders(token),
      body: payload,
    );
    return _parseDoctorResponse(response);
  }

  Future<Doctor> uploadPhoto(
    String token, {
    required Uint8List photoBytes,
    required String photoName,
  }) async {
    final response = await _mainRepo.postMultipart(
      photoEndpoint,
      headers: _authHeaders(token),
      files: [
        MultipartFileData(
          field: 'photo',
          bytes: photoBytes,
          filename: photoName,
        ),
      ],
    );
    return _parseDoctorResponse(response);
  }

  void close() {
    _mainRepo.close();
  }

  Doctor _parseDoctorResponse(dynamic data) {
    final map = _toMap(data);
    final nestedData = map['data'];
    final source =
        map['doctor'] ??
        map['profile'] ??
        map['user'] ??
        (nestedData is Map<String, dynamic>
            ? nestedData['doctor'] ?? nestedData['profile'] ?? nestedData['user']
            : null) ??
        (nestedData is Map<String, dynamic> ? nestedData : map);

    if (source is! Map<String, dynamic>) {
      throw ApiException(message: 'Could not parse doctor profile response.');
    }

    return Doctor(
      id: _readString(source, ['id', '_id', 'doctorId', 'userId']) ?? '',
      name:
          _readString(source, ['fullName', 'name', 'username']) ?? 'Doctor',
      email: _readString(source, ['email']) ?? '',
      phoneNumber:
          _readString(source, ['phoneNumber', 'phone', 'mobile']) ?? '',
      age: _readInt(source, ['age']) ?? 25,
      qrCode: _readString(source, ['qrCode', 'qr_code']),
      bio: _readString(source, ['bio', 'about']),
      profile: DoctorProfile(
        specialization: _readString(
              source,
              ['specialization', 'speciality'],
            ) ??
            '',
        workPlace:
            _readString(source, ['workingAt', 'workPlace', 'workplace']) ?? '',
        avatar: _readString(
          source,
          ['avatar', 'avatarUrl', 'image', 'photo', 'photoUrl'],
        ),
        languages: _readStringList(source, 'languages'),
        location: _readString(source, ['location', 'address']) ?? '',
        experience:
            (_readInt(source, ['experience', 'yearsExperience']))
                ?.toString() ??
            _readString(source, ['experience', 'yearsExperience']) ??
            '',
        qualifications:
            _readString(source, ['qualifications', 'qualification']) ?? '',
        consultationFee: _readDouble(source, ['consultationFee']),
      ),
    );
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
    };
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
      if (value is num) return value.toInt();
      if (value is String) {
        final parsed = int.tryParse(value);
        if (parsed != null) return parsed;
      }
    }
    return null;
  }

  double? _readDouble(Map<String, dynamic> map, List<String> keys) {
    for (final key in keys) {
      final value = map[key];
      if (value is double) return value;
      if (value is num) return value.toDouble();
      if (value is String) {
        final parsed = double.tryParse(value);
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
