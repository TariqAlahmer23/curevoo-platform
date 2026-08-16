import 'package:curevoo_doctor/models/create_patient_appointment_request.dart';
import 'package:curevoo_doctor/models/doctor_appointment_item.dart';
import 'package:curevoo_doctor/models/doctor_booked_slot.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';

class PatientAppointmentsRepo {
  PatientAppointmentsRepo({
    required MainRepo mainRepo,
    this.createEndpoint = '/doctor/appointments',
    this.listEndpoint = '/doctor/appointments',
    this.acceptedEndpoint = '/doctor/appointments/accepted',
    this.createdEndpoint = '/doctor/appointments/created',
    this.canceledEndpoint = '/doctor/appointments/canceled',
    this.pendingEndpoint = '/doctor/appointments/pending',
    this.upcomingEndpoint = '/doctor/appointments/upcoming',
    this.bookedSlotsEndpoint = '/doctor/appointments/booked-slots',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String createEndpoint;
  final String listEndpoint;
  final String acceptedEndpoint;
  final String createdEndpoint;
  final String canceledEndpoint;
  final String pendingEndpoint;
  final String upcomingEndpoint;
  final String bookedSlotsEndpoint;

  Future<void> createAppointmentRequest(
    String token,
    CreatePatientAppointmentRequest request,
  ) async {
    await _mainRepo.post(
      createEndpoint,
      headers: {'Authorization': 'Bearer $token'},
      body: request.toJson(),
    );
  }

  Future<void> updateAppointment(
    String token, {
    required String appointmentId,
    required UpdatePatientAppointmentRequest request,
  }) async {
    await _mainRepo.put(
      '$createEndpoint/$appointmentId',
      headers: {'Authorization': 'Bearer $token'},
      body: request.toJson(),
    );
  }

  Future<void> deleteAppointment(
    String token, {
    required String appointmentId,
  }) async {
    await _mainRepo.delete(
      '$createEndpoint/$appointmentId',
      headers: {'Authorization': 'Bearer $token'},
    );
  }

  Future<void> respondToPendingAppointment(
    String token, {
    required String appointmentId,
    required String action,
  }) async {
    await _mainRepo.post(
      '$createEndpoint/$appointmentId/respond',
      headers: {'Authorization': 'Bearer $token'},
      body: {'action': action},
    );
  }

  Future<List<DoctorAppointmentItem>> fetchAppointments(
    String token, {
    required String status,
  }) async {
    final response = await _mainRepo.get(
      listEndpoint,
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: {'status': status},
    );
    return _parseAppointments(response);
  }

  Future<List<DoctorAppointmentItem>> fetchAcceptedAppointments(
    String token,
  ) async {
    final response = await _mainRepo.get(
      acceptedEndpoint,
      headers: {'Authorization': 'Bearer $token'},
    );
    return _parseAppointments(response);
  }

  Future<List<DoctorAppointmentItem>> fetchCreatedAppointments(
    String token,
  ) async {
    final response = await _mainRepo.get(
      createdEndpoint,
      headers: {'Authorization': 'Bearer $token'},
    );
    return _parseAppointments(response);
  }

  Future<List<DoctorAppointmentItem>> fetchCanceledAppointments(
    String token,
  ) async {
    final response = await _mainRepo.get(
      canceledEndpoint,
      headers: {'Authorization': 'Bearer $token'},
    );
    return _parseAppointments(response);
  }

  Future<List<DoctorAppointmentItem>> fetchPendingAppointments(
    String token,
  ) async {
    final response = await _mainRepo.get(
      pendingEndpoint,
      headers: {'Authorization': 'Bearer $token'},
    );
    return _parseAppointments(response);
  }

  Future<List<DoctorAppointmentItem>> fetchUpcomingAppointments(
    String token,
  ) async {
    final response = await _mainRepo.get(
      upcomingEndpoint,
      headers: {'Authorization': 'Bearer $token'},
    );
    return _parseAppointments(response);
  }

  Future<List<DoctorBookedSlot>> fetchBookedSlotsByRange(
    String token, {
    required String fromDate,
    required String toDate,
  }) async {
    final response = await _mainRepo.get(
      bookedSlotsEndpoint,
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: {'from': fromDate, 'to': toDate},
    );
    return _parseBookedSlots(response);
  }

  Future<List<DoctorBookedSlot>> fetchBookedSlotsByDate(
    String token, {
    required String date,
  }) async {
    final response = await _mainRepo.get(
      bookedSlotsEndpoint,
      headers: {'Authorization': 'Bearer $token'},
      queryParameters: {'date': date},
    );
    return _parseBookedSlots(response);
  }

  void close() {
    _mainRepo.close();
  }

  List<DoctorAppointmentItem> _parseAppointments(dynamic response) {
    final list = _extractList(response);
    return list
        .map(_parseItem)
        .whereType<DoctorAppointmentItem>()
        .toList(growable: false);
  }

  List<Map<String, dynamic>> _extractList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }

    if (response is! Map) return const [];

    final map = response.map((k, v) => MapEntry(k.toString(), v));
    final candidates = <dynamic>[
      map['data'],
      map['appointments'],
      map['items'],
      map['result'],
    ];

    for (final candidate in candidates) {
      if (candidate is List) {
        return candidate
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
      }
      if (candidate is Map) {
        final nested = candidate.map((k, v) => MapEntry(k.toString(), v));
        final nestedList =
            nested['items'] ?? nested['appointments'] ?? nested['data'];
        if (nestedList is List) {
          return nestedList
              .whereType<Map>()
              .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
              .toList(growable: false);
        }
      }
    }

    return const [];
  }

  DoctorAppointmentItem? _parseItem(Map<String, dynamic> json) {
    final patientMap = _toMap(json['patient']) ?? _toMap(json['patientInfo']);
    final patientName =
        _readString(json, ['patientName', 'name']) ??
        _readString(patientMap, ['name', 'fullName']) ??
        'Unknown';
    final patientPhone =
        _readString(json, ['patientPhone', 'phone']) ??
        _readString(patientMap, ['phone', 'phoneNumber']) ??
        '-';

    final reason =
        _readString(json, ['reason', 'appointmentType', 'type']) ?? '-';
    final status = (_readString(json, ['status']) ?? 'PENDING').toUpperCase();
    final date = _readString(json, ['appointmentDate', 'date']) ?? '';
    final time = _readString(json, ['appointmentTime', 'time']) ?? '';

    return DoctorAppointmentItem(
      id: _readString(json, ['id', '_id', 'appointmentId']) ?? '',
      patientId:
          _readString(json, ['patientId']) ??
          _readString(patientMap, ['id', '_id', 'patientId']),
      patientType: _readString(json, ['patientType']),
      patientName: patientName,
      patientPhone: patientPhone,
      reason: reason,
      status: status,
      appointmentDate: date,
      appointmentTime: time,
      notes: _readString(json, ['notes']),
    );
  }

  Map<String, dynamic>? _toMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return null;
  }

  String? _readString(Map<String, dynamic>? map, List<String> keys) {
    if (map == null) return null;
    for (final key in keys) {
      final value = map[key];
      if (value is String && value.trim().isNotEmpty) {
        return value.trim();
      }
      if (value is num) return value.toString();
    }
    return null;
  }

  List<DoctorBookedSlot> _parseBookedSlots(dynamic response) {
    final list = _extractBookedSlotsList(response);
    return list
        .map(_parseBookedSlotItem)
        .whereType<DoctorBookedSlot>()
        .toList(growable: false);
  }

  DoctorBookedSlot? _parseBookedSlotItem(Map<String, dynamic> json) {
    final appointmentDate =
        _readString(json, ['appointmentDate', 'date', 'day']) ?? '';
    final appointmentTime =
        _readString(json, ['appointmentTime', 'time', 'slot']) ?? '';

    if (appointmentDate.isEmpty || appointmentTime.isEmpty) return null;

    final status = (_readString(json, ['status']) ?? 'BOOKED').toUpperCase();
    return DoctorBookedSlot(
      appointmentDate: appointmentDate,
      appointmentTime: appointmentTime,
      status: status,
      patientName: _readString(json, ['patientName', 'name']),
      reason: _readString(json, ['reason', 'appointmentType', 'type']),
    );
  }

  List<Map<String, dynamic>> _extractBookedSlotsList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }

    if (response is! Map) return const [];
    final map = response.map((k, v) => MapEntry(k.toString(), v));

    final directBookedSlots = map['bookedSlots'];
    if (directBookedSlots is List) {
      return directBookedSlots
          .whereType<Map>()
          .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
          .toList(growable: false);
    }

    final data = map['data'];
    if (data is Map) {
      final typedData = data.map((k, v) => MapEntry(k.toString(), v));
      final nestedBookedSlots = typedData['bookedSlots'];
      if (nestedBookedSlots is List) {
        return nestedBookedSlots
            .whereType<Map>()
            .map((item) => item.map((k, v) => MapEntry(k.toString(), v)))
            .toList(growable: false);
      }
    }

    return _extractList(response);
  }
}
