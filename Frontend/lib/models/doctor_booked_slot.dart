import 'package:equatable/equatable.dart';

class DoctorBookedSlot extends Equatable {
  const DoctorBookedSlot({
    required this.appointmentDate,
    required this.appointmentTime,
    required this.status,
    this.patientName,
    this.reason,
  });

  final String appointmentDate;
  final String appointmentTime;
  final String status;
  final String? patientName;
  final String? reason;

  @override
  List<Object?> get props => [
    appointmentDate,
    appointmentTime,
    status,
    patientName,
    reason,
  ];
}
