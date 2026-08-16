import 'dart:convert';
import 'dart:typed_data';

import 'package:curevoo_doctor/repos/main_repo.dart';

class PatientHistoryRecord {
  const PatientHistoryRecord({
    required this.rawData,
  });

  final Map<String, dynamic> rawData;
}

class MedicalHistoryQuestionAnswer {
  const MedicalHistoryQuestionAnswer({
    required this.question,
    required this.answer,
  });

  final String question;
  final String answer;

  Map<String, dynamic> toJson() {
    return {
      'question': question,
      'answer': answer,
    };
  }
}

class MedicalHistoryImageAttachment {
  const MedicalHistoryImageAttachment({
    required this.filename,
    required this.bytes,
  });

  final String filename;
  final Uint8List bytes;
}

class CreateMedicalHistoryRequest {
  const CreateMedicalHistoryRequest({
    required this.patientName,
    required this.patientPhone,
    required this.patientAge,
    required this.patientSex,
    required this.symptomDuration,
    required this.familyHistory,
    required this.previousTreatmentHistory,
    required this.shortnessOfBreath,
    required this.coughingBlood,
    required this.chestPain,
    required this.faintingOrSevereDizziness,
    required this.recentWeightLoss,
    required this.smoker,
    required this.profession,
    required this.hoarseness,
    required this.symptomSectionNotes,
    required this.customQuestionAnswers,
    required this.images,
  });

  final String patientName;
  final String patientPhone;
  final int patientAge;
  final String patientSex;
  final String symptomDuration;
  final String familyHistory;
  final String previousTreatmentHistory;
  final String shortnessOfBreath;
  final String coughingBlood;
  final String chestPain;
  final String faintingOrSevereDizziness;
  final String recentWeightLoss;
  final String smoker;
  final String profession;
  final String hoarseness;
  final String symptomSectionNotes;
  final List<MedicalHistoryQuestionAnswer> customQuestionAnswers;
  final List<MedicalHistoryImageAttachment> images;

  Map<String, dynamic> recordPayload() {
    return {
      'patientName': patientName,
      'patientPhone': patientPhone,
      'patientAge': patientAge,
      'patientSex': patientSex,
      'symptomDuration': symptomDuration,
      'familyHistory': familyHistory,
      'previousTreatmentHistory': previousTreatmentHistory,
      'shortnessOfBreath': _parseBooleanLike(shortnessOfBreath),
      'coughingBlood': _parseBooleanLike(coughingBlood),
      'chestPain': _parseBooleanLike(chestPain),
      'faintingOrSevereDizziness':
          _parseBooleanLike(faintingOrSevereDizziness),
      'recentWeightLoss': _parseBooleanLike(recentWeightLoss),
      'smoker': _parseBooleanLike(smoker),
      'profession': profession,
      'hoarseness': _parseBooleanLike(hoarseness),
      'symptomSectionNotes': symptomSectionNotes,
      'customQuestionAnswers':
          customQuestionAnswers.map((entry) => entry.toJson()).toList(),
    };
  }

  bool? _parseBooleanLike(String value) {
    switch (value.trim().toLowerCase()) {
      case 'yes':
      case 'true':
        return true;
      case 'no':
      case 'false':
        return false;
      default:
        return null;
    }
  }
}

class MedicalHistoryRepo {
  MedicalHistoryRepo({
    required MainRepo mainRepo,
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;

  Future<dynamic> createMedicalHistory(
    String token, {
    required String patientId,
    required CreateMedicalHistoryRequest request,
  }) {
    return _mainRepo.postMultipart(
      _resolveCreateMedicalHistoryEndpoint(patientId),
      headers: _authHeaders(token),
      fields: {
        'record': jsonEncode(request.recordPayload()),
      },
      files: request.images
          .map(
            (image) => MultipartFileData(
              field: 'images',
              bytes: image.bytes,
              filename: image.filename,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<PatientHistoryRecord> fetchLatestHistoryRecord(
    String token, {
    required String patientId,
  }) async {
    final response = await _mainRepo.get(
      _resolveHistoryRecordEndpoint(patientId),
      headers: _authHeaders(token),
    );

    return PatientHistoryRecord(
      rawData: _parseHistoryRecordResponse(response),
    );
  }

  Future<List<PatientHistoryRecord>> fetchAllHistoryRecords(
    String token, {
    required String patientId,
  }) async {
    final response = await _mainRepo.get(
      _resolveAllHistoryRecordsEndpoint(patientId),
      headers: _authHeaders(token),
    );

    return _parseHistoryRecordListResponse(
      response,
    ).map((record) => PatientHistoryRecord(rawData: record)).toList(
      growable: false,
    );
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
    };
  }

  String _resolveCreateMedicalHistoryEndpoint(String patientId) {
    return _resolveHistoryRecordEndpoint(patientId);
  }

  String _resolveHistoryRecordEndpoint(String patientId) {
    const endpoint = '/api/care/doctor/patients/{patientId}/history-record';
    return _resolvePatientHistoryEndpoint(endpoint, patientId);
  }

  String _resolveAllHistoryRecordsEndpoint(String patientId) {
    const endpoint =
        '/api/care/doctor/patients/{patientId}/history-records/all';
    return _resolvePatientHistoryEndpoint(endpoint, patientId);
  }

  String _resolvePatientHistoryEndpoint(String endpoint, String patientId) {
    final resolvedEndpoint = endpoint.replaceFirst('{patientId}', patientId);
    final normalizedBase = _mainRepo.baseUrl.toLowerCase().trim();
    final normalizedEndpoint = resolvedEndpoint.toLowerCase().trim();

    if (normalizedBase.endsWith('/api') &&
        normalizedEndpoint.startsWith('/api/')) {
      return resolvedEndpoint.substring(4);
    }

    return resolvedEndpoint;
  }

List<Map<String, dynamic>> _parseHistoryRecordListResponse(dynamic value) {
  if (value is List || value is String || value == null) {
    final normalized = _normalizeRecordList(value);
    if (normalized != null) return normalized;
  }

  final map = _toMap(value);
  
  // Check for the API response structure first
  if (map.containsKey('data') && map['ok'] == true) {
    final dataList = map['data'];
    final parsed = _normalizeRecordList(dataList);
    if (parsed != null) return parsed;
  }
  
  // Check if "data" is present without "ok" field
  if (map.containsKey('data')) {
    final dataList = map['data'];
    final parsed = _normalizeRecordList(dataList);
    if (parsed != null) return parsed;
  }
  
  // Fallback to other candidates
  final candidates = <dynamic>[
    map['records'],
    map['historyRecords'],
    map['allRecords'],
    map['items'],
    map['results'],
    map['list'],
    map['record'],
    map['historyRecord'],
  ];

  for (final candidate in candidates) {
    final parsed = _normalizeRecordList(candidate);
    if (parsed != null) {
      return parsed;
    }
  }

  final fallbackSingle = _normalizeRecordMap(value);
  if (fallbackSingle != null && fallbackSingle.isNotEmpty) {
    return [fallbackSingle];
  }

  throw ApiException(message: 'Could not parse patient history records.');
}
  Map<String, dynamic> _parseHistoryRecordResponse(dynamic value) {
    final map = _toMap(value);
    final candidates = <dynamic>[
      map['record'],
      map['historyRecord'],
      map['latestRecord'],
      map['data'],
      map['item'],
      map,
    ];

    for (final candidate in candidates) {
      final parsed = _normalizeRecordMap(candidate);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    }

    throw ApiException(message: 'Could not parse patient history record.');
  }

  List<Map<String, dynamic>>? _normalizeRecordList(dynamic value) {
    if (value == null) return const [];

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      try {
        final decoded = jsonDecode(trimmed);
        return _normalizeRecordList(decoded);
      } catch (_) {
        return null;
      }
    }

    if (value is List) {
      return value
          .map(_normalizeRecordMap)
          .whereType<Map<String, dynamic>>()
          .where((record) => record.isNotEmpty)
          .toList(growable: false);
    }

    if (value is Map<String, dynamic>) {
      final nestedCandidates = <dynamic>[
        value['records'],
        value['historyRecords'],
        value['allRecords'],
        value['items'],
        value['results'],
        value['data'],
        value['list'],
      ];

      for (final candidate in nestedCandidates) {
        final parsed = _normalizeRecordList(candidate);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    if (value is Map) {
      final typedMap = value.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      return _normalizeRecordList(typedMap);
    }

    final singleRecord = _normalizeRecordMap(value);
    if (singleRecord != null && singleRecord.isNotEmpty) {
      return [singleRecord];
    }

    return null;
  }

  Map<String, dynamic>? _normalizeRecordMap(dynamic value) {
    if (value == null) return null;

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      try {
        final decoded = jsonDecode(trimmed);
        return _normalizeRecordMap(decoded);
      } catch (_) {
        return {'value': trimmed};
      }
    }

    if (value is Map<String, dynamic>) return value;

    if (value is Map) {
      return value.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
    }

    return {'value': value};
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    throw ApiException(message: 'Unexpected response type from server.');
  }

  void close() {
    _mainRepo.close();
  }
}
