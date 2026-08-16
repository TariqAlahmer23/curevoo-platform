import 'package:curevoo_doctor/models/doctor_available_time.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';

class DoctorAvailableTimesRepo {
  DoctorAvailableTimesRepo({
    required MainRepo mainRepo,
    this.endpoint = '/doctor/available-times',
    this.dayEndpoint = '/doctor/available-times/day',
  }) : _mainRepo = mainRepo;

  final MainRepo _mainRepo;
  final String endpoint;
  final String dayEndpoint;

  Future<List<DoctorAvailableTime>> fetchAvailableTimes(String token) async {
    final response = await _mainRepo.get(
      endpoint,
      headers: _authHeaders(token),
    );
    final data = _extractDataList(response);
    return data.map(_parseDay).toList(growable: false);
  }

  Future<List<String>> fetchAvailableTimesForDay(
    String token, {
    required String date,
  }) async {
    final response = await _mainRepo.get(
      dayEndpoint,
      headers: _authHeaders(token),
      queryParameters: {'date': date},
    );
    return _parseAvailableSlotsForDay(response);
  }

  Future<void> updateAvailableTime(
    String token,
    DoctorAvailableTime availableTime,
  ) async {
    await _mainRepo.put(
      endpoint,
      headers: _authHeaders(token),
      body: availableTime.toRequestBody(),
    );
  }

  void close() {
    _mainRepo.close();
  }

  Map<String, String> _authHeaders(String token) {
    return {'Authorization': 'Bearer $token'};
  }

  List<Map<String, dynamic>> _extractDataList(dynamic response) {
    if (response is List) {
      return response
          .whereType<Map>()
          .map(
            (item) => item.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    }

    if (response is Map) {
      final map = response.map((key, value) => MapEntry(key.toString(), value));
      final data = map['data'];
      if (data is List) {
        return data
            .whereType<Map>()
            .map(
              (item) =>
                  item.map((key, value) => MapEntry(key.toString(), value)),
            )
            .toList(growable: false);
      }
    }

    return const [];
  }

  DoctorAvailableTime _parseDay(Map<String, dynamic> json) {
    final dayOfWeek = _readInt(json['dayOfWeek']);
    if (dayOfWeek == null) {
      throw ApiException(
        message: 'Invalid available-time item: missing dayOfWeek.',
      );
    }

    return DoctorAvailableTime(
      dayOfWeek: dayOfWeek,
      from: _readNullableTime(json['from'] ?? json['startTime']),
      to: _readNullableTime(json['to'] ?? json['endTime']),
      isOn: _readBool(json['isOn']) ?? false,
    );
  }

  int? _readInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value.trim());
    return null;
  }

  bool? _readBool(dynamic value) {
    if (value is bool) return value;
    if (value is num) return value != 0;
    if (value is String) {
      final normalized = value.trim().toLowerCase();
      if (normalized == 'true' || normalized == '1') return true;
      if (normalized == 'false' || normalized == '0') return false;
    }
    return null;
  }

  String? _readNullableTime(dynamic value) {
    if (value == null) return null;
    if (value is String) {
      final normalized = value.trim();
      if (normalized.isEmpty) return null;
      return normalized.length >= 5 ? normalized.substring(0, 5) : normalized;
    }
    return value.toString();
  }

  List<String> _parseAvailableSlotsForDay(dynamic response) {
    final directSlots = _readSlotList(response);
    if (directSlots.isNotEmpty) return directSlots;

    if (response is! Map) return const [];
    final map = response.map((key, value) => MapEntry(key.toString(), value));
    final data = map['data'];
    final dataMap = data is Map
        ? data.map((key, value) => MapEntry(key.toString(), value))
        : map;
    final availability =
        dataMap['availability'] ??
        dataMap['availableTime'] ??
        dataMap['doctorAvailableTime'];
    final dayMap = availability is Map
        ? {
            ...dataMap,
            ...availability.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          }
        : dataMap;

    for (final key in const [
      'availableTimes',
      'availableSlots',
      'slots',
      'times',
      'freeTimes',
      'freeSlots',
      'available',
    ]) {
      final slots = _readSlotList(dayMap[key]);
      if (slots.isNotEmpty) return slots;
    }

    final isOn = _readBool(dayMap['isOn']);
    if (isOn == false) return const [];

    final from = _readNullableTime(dayMap['from'] ?? dayMap['startTime']);
    final to = _readNullableTime(dayMap['to'] ?? dayMap['endTime']);
    final bookedTimes = <String>{
      ..._readTimeSlotList(dayMap['bookedTimes']).map(_normalizeTimeForCompare),
      ..._readTimeSlotList(dayMap['bookedSlots']).map(_normalizeTimeForCompare),
      ..._readTimeSlotList(
        dayMap['bookedAppointments'],
      ).map(_normalizeTimeForCompare),
      ..._readTimeSlotList(
        dayMap['appointments'],
      ).map(_normalizeTimeForCompare),
    };

    final fromMinutes = _toMinutes(from);
    final toMinutes = _toMinutes(to);
    if (fromMinutes == null || toMinutes == null || fromMinutes >= toMinutes) {
      return const [];
    }

    final slots = <String>[];
    for (var minutes = fromMinutes; minutes < toMinutes; minutes += 60) {
      final apiTime = _formatApiTime(minutes);
      if (!bookedTimes.contains(apiTime)) {
        slots.add(_formatDisplayTime(minutes));
      }
    }
    return slots;
  }

  List<String> _readSlotList(dynamic value) {
    if (value is! List) return const [];

    final slots = <String>[];
    for (final item in value) {
      final slot = _readAvailableSlot(item);
      if (slot != null) slots.add(slot);
    }
    return slots;
  }

  List<String> _readTimeSlotList(dynamic value) {
    if (value is! List) return const [];

    final slots = <String>[];
    for (final item in value) {
      final slot = _readTimeSlot(item);
      if (slot != null) slots.add(slot);
    }
    return slots;
  }

  String? _readAvailableSlot(dynamic item) {
    if (item is String && item.trim().isNotEmpty) {
      return _normalizeDisplayTime(item);
    }

    if (item is! Map) return null;
    final map = item.map((key, value) => MapEntry(key.toString(), value));
    final isBooked = _readBool(map['isBooked'] ?? map['booked']) ?? false;
    final isAvailable =
        _readBool(map['isAvailable'] ?? map['available'] ?? map['free']) ??
        true;
    final status = (map['status']?.toString() ?? '').trim().toUpperCase();
    if (!isAvailable ||
        isBooked ||
        status == 'BOOKED' ||
        status == 'RESERVED' ||
        status == 'UNAVAILABLE') {
      return null;
    }

    final time = _readNullableTime(
      map['time'] ??
          map['slot'] ??
          map['appointmentTime'] ??
          map['start'] ??
          map['from'] ??
          map['startTime'],
    );
    if (time == null || time.trim().isEmpty) return null;
    return _normalizeDisplayTime(time);
  }

  String? _readTimeSlot(dynamic item) {
    if (item is String && item.trim().isNotEmpty) return item.trim();
    if (item is! Map) return null;

    final map = item.map((key, value) => MapEntry(key.toString(), value));
    return _readNullableTime(
      map['time'] ??
          map['slot'] ??
          map['appointmentTime'] ??
          map['start'] ??
          map['from'] ??
          map['startTime'],
    );
  }

  int? _toMinutes(String? hhmm) {
    if (hhmm == null) return null;
    final parts = hhmm.split(':');
    if (parts.length < 2) return null;
    final hour = int.tryParse(parts[0]);
    final minute = int.tryParse(parts[1]);
    if (hour == null || minute == null) return null;
    if (hour < 0 || hour > 23 || minute < 0 || minute > 59) return null;
    return hour * 60 + minute;
  }

  String _formatApiTime(int minutes) {
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    return '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}';
  }

  String _formatDisplayTime(int minutes) {
    final hour24 = minutes ~/ 60;
    final minute = minutes % 60;
    final period = hour24 >= 12 ? 'PM' : 'AM';
    final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
    return '${hour12.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')} $period';
  }

  String _normalizeDisplayTime(String value) {
    final minutes = _toMinutes(value.trim());
    return minutes == null ? value.trim() : _formatDisplayTime(minutes);
  }

  String _normalizeTimeForCompare(String value) {
    final minutes = _toMinutes(value.trim());
    return minutes == null ? value.trim() : _formatApiTime(minutes);
  }
}
