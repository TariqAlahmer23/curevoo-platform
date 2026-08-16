import 'package:equatable/equatable.dart';

class DoctorAppointmentItem extends Equatable {
  const DoctorAppointmentItem({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    required this.reason,
    required this.status,
    required this.appointmentDate,
    required this.appointmentTime,
    this.patientId,
    this.patientType,
    this.notes,
  });

  final String id;
  final String? patientId;
  final String? patientType;
  final String patientName;
  final String patientPhone;
  final String reason;
  final String status;
  final String appointmentDate;
  final String appointmentTime;
  final String? notes;

  @override
  List<Object?> get props => [
    id,
    patientId,
    patientType,
    patientName,
    patientPhone,
    reason,
    status,
    appointmentDate,
    appointmentTime,
    notes,
  ];
}
