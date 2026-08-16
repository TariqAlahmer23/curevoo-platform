import 'dart:convert';

import 'package:curevoo_doctor/repos/main_repo.dart';

class LatestTreatmentPlanRecord {
  const LatestTreatmentPlanRecord({
    required this.rawData,
  });

  final Map<String, dynamic> rawData;
}

class CreateTreatmentPlanRequest {
  const CreateTreatmentPlanRequest({
    this.patientId,
    this.patientUserId,
    required this.lungCancerType,
    required this.treatmentType,
    required this.commonMedicines,
    required this.additionalMedicines,
    required this.reviewPeriod,
    this.nextReviewDate,
  });

  final String? patientId;
  final String? patientUserId;
  final String lungCancerType;
  final String treatmentType;
  final List<String> commonMedicines;
  final String additionalMedicines;
  final String reviewPeriod;
  final DateTime? nextReviewDate;

  Map<String, dynamic> toJson() {
    return {
      if (patientId != null && patientId!.trim().isNotEmpty)
        'patientId': patientId!.trim(),
      if (patientUserId != null && patientUserId!.trim().isNotEmpty)
        'patientUserId': patientUserId!.trim(),
      'treatmentPlan': {
        'lungCancerType': lungCancerType.trim(),
        'treatmentType': treatmentType.trim(),
        'commonMedicines': commonMedicines,
        'additionalMedicines': additionalMedicines.trim(),
        'reviewPeriod': reviewPeriod.trim(),
        if (nextReviewDate != null)
          'nextReviewDate': _formatDate(nextReviewDate!),
      },
    };
  }

  String _formatDate(DateTime date) {
    final year = date.year.toString().padLeft(4, '0');
    final month = date.month.toString().padLeft(2, '0');
    final day = date.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }
}

class TreatmentPlanRepo {
  TreatmentPlanRepo({
    required MainRepo mainRepo,
    this.createTreatmentPlanEndpoint = '/api/care/doctor/treatment-plans',
    this.latestTreatmentPlanEndpoint =
        '/api/care/doctor/patients/{patientUserId}/treatment-plans/latest',
    this.allTreatmentPlansEndpoint =
        '/api/care/doctor/patients/{patientUserId}/treatment-plans/all',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String createTreatmentPlanEndpoint;
  final String latestTreatmentPlanEndpoint;
  final String allTreatmentPlansEndpoint;

  Future<Map<String, dynamic>> createTreatmentPlan(
    String token,
    CreateTreatmentPlanRequest request,
  ) async {
    final response = await _mainRepo.post(
      _normalizeApiEndpoint(createTreatmentPlanEndpoint),
      headers: _authHeaders(token),
      body: request.toJson(),
    );
    return _toMap(response);
  }

  Future<LatestTreatmentPlanRecord> fetchLatestTreatmentPlan(
    String token, {
    required String patientUserId,
  }) async {
    final response = await _mainRepo.get(
      _resolvePatientEndpoint(latestTreatmentPlanEndpoint, patientUserId),
      headers: _authHeaders(token),
    );

    return LatestTreatmentPlanRecord(
      rawData: _parseLatestTreatmentPlanResponse(response),
    );
  }

  Future<List<LatestTreatmentPlanRecord>> fetchAllTreatmentPlans(
    String token, {
    required String patientUserId,
  }) async {
    final response = await _mainRepo.get(
      _resolvePatientEndpoint(allTreatmentPlansEndpoint, patientUserId),
      headers: _authHeaders(token),
    );

    return _parseTreatmentPlansListResponse(
      response,
    ).map((record) => LatestTreatmentPlanRecord(rawData: record)).toList(
      growable: false,
    );
  }

  Map<String, String> _authHeaders(String token) {
    return {
      'Authorization': 'Bearer $token',
    };
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

  String _resolvePatientEndpoint(String endpoint, String patientUserId) {
    final resolved = endpoint.replaceFirst('{patientUserId}', patientUserId);
    return _normalizeApiEndpoint(resolved);
  }

  Map<String, dynamic> _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    if (value == null) return const <String, dynamic>{};
    throw ApiException(message: 'Unexpected response type from server.');
  }

  Map<String, dynamic> _parseLatestTreatmentPlanResponse(dynamic value) {
    final map = _toMap(value);
    if (map['ok'] == true) {
      final data = map['data'];
      final extracted = _extractTreatmentPlanRecord(data);
      if (extracted != null && extracted.isNotEmpty) {
        return extracted;
      }
    }

    final candidates = <dynamic>[
      map['treatmentPlan'],
      map['latestTreatmentPlan'],
      map['plan'],
      map['data'],
      map['item'],
      map,
    ];

    for (final candidate in candidates) {
      final parsed = _normalizeTreatmentPlanMap(candidate);
      if (parsed != null && parsed.isNotEmpty) {
        return parsed;
      }
    }

    throw ApiException(message: 'Could not parse latest treatment plan.');
  }

  List<Map<String, dynamic>> _parseTreatmentPlansListResponse(dynamic value) {
    if (value is Map) {
      final typedMap = _toMap(value);
      if (typedMap['ok'] == true && typedMap['data'] is List) {
        return (typedMap['data'] as List)
            .map(_extractTreatmentPlanRecord)
            .whereType<Map<String, dynamic>>()
            .where((record) => record.isNotEmpty)
            .toList(growable: false);
      }
    }

    if (value is List || value is String || value == null) {
      final normalized = _normalizeTreatmentPlanList(value);
      if (normalized != null) return normalized;
    }

    final map = _toMap(value);
    final candidates = <dynamic>[
      map['treatmentPlans'],
      map['plans'],
      map['allTreatmentPlans'],
      map['items'],
      map['results'],
      map['data'],
      map['list'],
      map,
    ];

    for (final candidate in candidates) {
      final parsed = _normalizeTreatmentPlanList(candidate);
      if (parsed != null) {
        return parsed;
      }
    }

    throw ApiException(message: 'Could not parse treatment plans list.');
  }

  Map<String, dynamic>? _extractTreatmentPlanRecord(dynamic value) {
    final source = _normalizeLooseMap(value);
    if (source == null || source.isEmpty) return null;

    final nestedPlan = _normalizeLooseMap(source['treatmentPlan']) ??
        _normalizeLooseMap(source['latestTreatmentPlan']) ??
        _normalizeLooseMap(source['plan']);

    if (nestedPlan != null && nestedPlan.isNotEmpty) {
      final merged = <String, dynamic>{...nestedPlan};
      _mergeMetadata(source, merged);
      return merged;
    }

    return _normalizeTreatmentPlanMap(source);
  }

  Map<String, dynamic>? _normalizeTreatmentPlanMap(dynamic value) {
    if (value == null) return null;

    if (value is Map<String, dynamic>) {
      final nestedCandidates = <dynamic>[
        value['treatmentPlan'],
        value['latestTreatmentPlan'],
        value['plan'],
        value['data'],
        value['item'],
      ];

      for (final candidate in nestedCandidates) {
        final nested = _normalizeTreatmentPlanMap(candidate);
        if (nested != null && nested.isNotEmpty) {
          final merged = <String, dynamic>{...nested};
          _mergeMetadata(value, merged);
          return merged;
        }
      }

      return value;
    }

    if (value is Map) {
      return _normalizeTreatmentPlanMap(
        value.map((key, dynamic value) => MapEntry(key.toString(), value)),
      );
    }

    return null;
  }

  Map<String, dynamic>? _normalizeLooseMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((key, dynamic value) => MapEntry(key.toString(), value));
    }
    return null;
  }

  List<Map<String, dynamic>>? _normalizeTreatmentPlanList(dynamic value) {
    if (value == null) return const [];

    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return const [];
      try {
        return _normalizeTreatmentPlanList(jsonDecode(trimmed));
      } catch (_) {
        return null;
      }
    }

    if (value is List) {
      return value
          .map(_normalizeTreatmentPlanMap)
          .whereType<Map<String, dynamic>>()
          .where((record) => record.isNotEmpty)
          .toList(growable: false);
    }

    if (value is Map<String, dynamic>) {
      final nestedCandidates = <dynamic>[
        value['treatmentPlans'],
        value['plans'],
        value['allTreatmentPlans'],
        value['items'],
        value['results'],
        value['data'],
        value['list'],
      ];

      for (final candidate in nestedCandidates) {
        final parsed = _normalizeTreatmentPlanList(candidate);
        if (parsed != null) {
          return parsed;
        }
      }
    }

    if (value is Map) {
      final typedMap = value.map(
        (key, dynamic value) => MapEntry(key.toString(), value),
      );
      return _normalizeTreatmentPlanList(typedMap);
    }

    final singleRecord = _normalizeTreatmentPlanMap(value);
    if (singleRecord != null && singleRecord.isNotEmpty) {
      return [singleRecord];
    }

    return null;
  }

  void _mergeMetadata(
    Map<String, dynamic> source,
    Map<String, dynamic> target,
  ) {
    const metadataKeys = {
      'id',
      '_id',
      'patientId',
      'patientUserId',
      'createdPatientId',
      'doctorId',
      'doctorUserId',
      'createdAt',
      'updatedAt',
    };

    for (final key in metadataKeys) {
      if (target.containsKey(key) && target[key] != null) {
        continue;
      }

      final value = source[key];
      if (value == null) continue;
      if (value is String && value.trim().isEmpty) continue;
      target[key] = value;
    }
  }

  void close() {
    _mainRepo.close();
  }
}
