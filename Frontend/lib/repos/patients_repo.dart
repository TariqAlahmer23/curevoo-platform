import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/models/nsclc_last_result.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';

class PatientsRepo {
  PatientsRepo({
    required MainRepo mainRepo,
    this.createPatientEndpoint = '/registration/doctor/created-patient',
    this.getPatientsEndpoint = '/api/doctor/patients',
    this.updatePatientEndpoint = '/api/doctor/patients/{patientId}',
    this.getConnectRequestsEndpoint =
        '/api/registration/doctor/connect-requests',
    this.respondConnectRequestEndpoint =
        '/api/registration/doctor/connect-requests/{requestId}/respond',
    this.getLastNsclcResultEndpoint = '/api/ai/nsclc/last-result/{patientId}',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String createPatientEndpoint;
  final String getPatientsEndpoint;
  final String updatePatientEndpoint;
  final String getConnectRequestsEndpoint;
  final String respondConnectRequestEndpoint;
  final String getLastNsclcResultEndpoint;

  Future<List<PatientSummary>> fetchPatients(String token) async {
    final response = await _mainRepo.get(
      _resolveGetPatientsEndpoint(),
      headers: _authHeaders(token),
    );
    final entries = _toPatientList(response);
    return entries.map(_parsePatient).toList(growable: false);
  }

  Future<Map<String, dynamic>> createPatient(
    String token,
    CreatePatientRequest request,
  ) async {
    final response = await _mainRepo.post(
      createPatientEndpoint,
      headers: _authHeaders(token),
      body: request.toJson(),
    );
    return _parseCreatedPatientResponse(response);
  }

  Future<List<PatientConnectRequest>> fetchConnectRequests(String token) async {
    final response = await _mainRepo.get(
      _resolveGetConnectRequestsEndpoint(),
      headers: _authHeaders(token),
    );
    final entries = _toConnectRequestList(response);
    return entries.map(_parseConnectRequest).toList(growable: false);
  }

  Future<void> respondToConnectRequest(
    String token, {
    required String requestId,
    required DoctorConnectRequestAction action,
  }) async {
    await _mainRepo.post(
      _resolveConnectRequestEndpoint(respondConnectRequestEndpoint, requestId),
      headers: _authHeaders(token),
      body: {'action': action.apiValue},
    );
  }

  Future<void> updatePatient(
    String token,
    String patientId,
    UpdatePatientRequest request,
  ) async {
    await _mainRepo.put(
      _resolvePatientEndpoint(updatePatientEndpoint, patientId),
      headers: _authHeaders(token),
      body: request.toJson(),
    );
  }

  Future<void> deletePatient(String token, String patientId) async {
    await _mainRepo.delete(
      _resolvePatientEndpoint(updatePatientEndpoint, patientId),
      headers: _authHeaders(token),
    );
  }

  Future<NsclcLastResult> fetchLastNsclcResult(
    String token,
    String patientId,
  ) async {
    final response = await _mainRepo.get(
      _resolvePatientEndpoint(getLastNsclcResultEndpoint, patientId),
      headers: _authHeaders(token),
    );
    final data = _toMap(response);
    return NsclcLastResult.fromMap(data);
  }

  PatientSummary parsePatientSummary(Map<String, dynamic> source) {
    return _parsePatient(source);
  }

  void close() {
    _mainRepo.close();
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

  String _resolveGetPatientsEndpoint() {
    return _normalizeApiEndpoint(getPatientsEndpoint);
  }

  String _resolveGetConnectRequestsEndpoint() {
    return _normalizeApiEndpoint(getConnectRequestsEndpoint);
  }

  String _resolvePatientEndpoint(String template, String patientId) {
    final resolved = template.replaceFirst('{patientId}', patientId);
    return _normalizeApiEndpoint(resolved);
  }

  String _resolveConnectRequestEndpoint(String template, String requestId) {
    final resolved = template.replaceFirst('{requestId}', requestId);
    return _normalizeApiEndpoint(resolved);
  }

  String _normalizeApiEndpoint(String endpoint) {
    final normalizedBase = _mainRepo.baseUrl.toLowerCase().trim();
    final normalizedEndpoint = endpoint.toLowerCase().trim();

    if (normalizedBase.endsWith('/api') &&
        normalizedEndpoint.startsWith('/api/')) {
      return endpoint.substring(4);
    }
    return endpoint;
  }

  List<Map<String, dynamic>> _toPatientList(dynamic value) {
    if (value is List) {
      return value.whereType<dynamic>().map(_toMap).toList(growable: false);
    }

    final map = _toMap(value);
    final dynamic nestedData = map['data'];
    final dynamic source = map['patients'] ?? map['items'] ?? nestedData ?? map;

    if (source is List) {
      return source.whereType<dynamic>().map(_toMap).toList(growable: false);
    }

    if (source is Map<String, dynamic>) {
      final nestedList =
          source['patients'] ?? source['items'] ?? source['data'];
      if (nestedList is List) {
        return nestedList
            .whereType<dynamic>()
            .map(_toMap)
            .toList(growable: false);
      }
    }

    throw ApiException(message: 'Could not parse patients list response.');
  }

  List<Map<String, dynamic>> _toConnectRequestList(dynamic value) {
    if (value is List) {
      return value.whereType<dynamic>().map(_toMap).toList(growable: false);
    }

    final map = _toMap(value);
    final dynamic nestedData = map['data'];
    final dynamic source =
        map['connectRequests'] ??
        map['requests'] ??
        map['items'] ??
        nestedData ??
        map;

    if (source is List) {
      return source.whereType<dynamic>().map(_toMap).toList(growable: false);
    }

    if (source is Map<String, dynamic>) {
      final nestedList =
          source['connectRequests'] ??
          source['requests'] ??
          source['items'] ??
          source['data'];
      if (nestedList is List) {
        return nestedList
            .whereType<dynamic>()
            .map(_toMap)
            .toList(growable: false);
      }
    }

    throw ApiException(
      message: 'Could not parse patient connection requests response.',
    );
  }

  PatientSummary _parsePatient(Map<String, dynamic> source) {
    return PatientSummary(
      id:
          _readString(source, [
            'patientUserId',
            'createdPatientId',
            'patientId',
            'id',
            '_id',
          ]) ??
          '',
      fullName:
          _readString(source, ['fullName', 'name', 'patientName']) ?? 'Patient',
      age: _readInt(source, ['age']) ?? 0,
      sex: _readString(source, ['sex', 'gender']) ?? 'MALE',
      phone: _readString(source, ['phoneNumber', 'phone', 'mobile']) ?? '-',
    );
  }

  PatientConnectRequest _parseConnectRequest(Map<String, dynamic> source) {
    final patientSource =
        _toMapOrNull(source['patient']) ??
        _toMapOrNull(source['patientInfo']) ??
        const <String, dynamic>{};
    final patientProfileSource =
        _toMapOrNull(patientSource['patientProfile']) ??
        const <String, dynamic>{};
    return PatientConnectRequest(
      id:
          _readString(source, ['requestId', 'connectRequestId', 'id', '_id']) ??
          '',
      patientName:
          _readString(source, ['patientName', 'fullName', 'name']) ??
          _readString(patientProfileSource, ['fullName', 'name']) ??
          _readString(patientSource, ['fullName', 'name', 'patientName']) ??
          'Patient',
      patientPhone:
          _readString(source, ['phoneNumber', 'phone', 'mobile']) ??
          _readString(patientSource, ['phoneNumber', 'phone', 'mobile']) ??
          '-',
      patientAge:
          _readInt(source, ['age']) ?? _readInt(patientSource, ['age']),
      patientSex:
          _readString(source, ['sex', 'gender']) ??
          _readString(patientSource, ['sex', 'gender']),
      requestedAt: _readString(source, ['requestedAt', 'createdAt', 'date']),
      status: (_readString(source, ['status']) ?? 'PENDING').toUpperCase(),
    );
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

  Map<String, dynamic>? _toMapOrNull(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  Map<String, dynamic> _parseCreatedPatientResponse(dynamic data) {
    final responseMap = _toMap(data);
    final ok = responseMap['ok'];
    if (ok is bool && !ok) {
      throw ApiException(
        message: 'Server returned an unsuccessful create patient response.',
      );
    }

    final nestedData = responseMap['data'];
    if (nestedData is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Could not parse create patient response data.',
      );
    }

    final createdPatient = nestedData['createdPatient'];
    if (createdPatient is! Map<String, dynamic>) {
      throw ApiException(
        message: 'Could not find created patient in response.',
      );
    }

    return createdPatient;
  }
}
