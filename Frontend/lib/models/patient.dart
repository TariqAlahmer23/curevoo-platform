
class Patient {
  const Patient(
    this.name,
    this.age,
    this.gender,
    this.phone,
    {
      this.id = '',
    }
  );

  final String id;
  final String name;
  final int age;
  final String gender;
  final String phone;
}

class PatientSummary {
  const PatientSummary({
    required this.id,
    required this.fullName,
    required this.age,
    required this.sex,
    required this.phone,
  });

  final String id;
  final String fullName;
  final int age;
  final String sex;
  final String phone;
}

enum DoctorConnectRequestAction {
  accept('ACCEPT'),
  reject('REJECT');

  const DoctorConnectRequestAction(this.apiValue);
  final String apiValue;
}

class PatientConnectRequest {
  const PatientConnectRequest({
    required this.id,
    required this.patientName,
    required this.patientPhone,
    this.patientAge,
    this.patientSex,
    this.requestedAt,
    this.status = 'PENDING',
  });

  final String id;
  final String patientName;
  final String patientPhone;
  final int? patientAge;
  final String? patientSex;
  final String? requestedAt;
  final String status;
}

class CreatePatientRequest {
  const CreatePatientRequest({
    required this.fullName,
    required this.phone,
    required this.age,
    required this.sex,
  });

  final String fullName;
  final String phone;
  final int age;
  final String sex;

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'phoneNumber': phone,
      'age': age,
      'sex': sex,
    };
  }
}

class UpdatePatientRequest {
  const UpdatePatientRequest({
    required this.fullName,
    required this.phone,
    required this.age,
    required this.sex,
  });

  final String fullName;
  final String phone;
  final int age;
  final String sex;

  Map<String, dynamic> toJson() {
    return {
      'fullName': fullName,
      'phoneNumber': phone,
      'age': age,
      'sex': sex,
    };
  }
}
