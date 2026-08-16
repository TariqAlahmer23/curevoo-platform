class CreatePatientAppointmentRequest {
  const CreatePatientAppointmentRequest({
    required this.patientId,
    required this.patientType,
    required this.appointmentDate,
    required this.appointmentTime,
    required this.reason,
    required this.notes,
  });

  final String patientId;
  final String patientType;
  final String appointmentDate;
  final String appointmentTime;
  final String reason;
  final String notes;

  Map<String, dynamic> toJson() {
    return {
      'patientId': patientId,
      'patientType': patientType,
      'appointmentDate': appointmentDate,
      'appointmentTime': appointmentTime,
      'reason': reason,
      'notes': notes,
    };
  }
}

class UpdatePatientAppointmentRequest {
  const UpdatePatientAppointmentRequest({
    required this.appointmentDate,
    required this.appointmentTime,
    required this.reason,
    required this.notes,
  });

  final String appointmentDate;
  final String appointmentTime;
  final String reason;
  final String notes;

  Map<String, dynamic> toJson() {
    return {
      'appointmentDate': appointmentDate,
      'appointmentTime': appointmentTime,
      'reason': reason,
      'notes': notes,
    };
  }
}
