import 'package:equatable/equatable.dart';

class DoctorAvailableTime extends Equatable {
  const DoctorAvailableTime({
    required this.dayOfWeek,
    required this.from,
    required this.to,
    required this.isOn,
  });

  final int dayOfWeek;
  final String? from;
  final String? to;
  final bool isOn;

  DoctorAvailableTime copyWith({
    int? dayOfWeek,
    String? from,
    String? to,
    bool? isOn,
    bool clearFrom = false,
    bool clearTo = false,
  }) {
    return DoctorAvailableTime(
      dayOfWeek: dayOfWeek ?? this.dayOfWeek,
      from: clearFrom ? null : (from ?? this.from),
      to: clearTo ? null : (to ?? this.to),
      isOn: isOn ?? this.isOn,
    );
  }

  Map<String, dynamic> toRequestBody() {
    final body = <String, dynamic>{
      'dayOfWeek': dayOfWeek,
      'isOn': isOn,
    };

    if (from != null) body['from'] = from;
    if (to != null) body['to'] = to;

    return body;
  }

  @override
  List<Object?> get props => [dayOfWeek, from, to, isOn];
}
