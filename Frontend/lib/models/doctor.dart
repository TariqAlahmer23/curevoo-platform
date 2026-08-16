// ignore_for_file: unused_local_variable, avoid_print

class Doctor {
  final String id;
  final String name;
  final String email;
  final String phoneNumber;
  final int age;
  final String? qrCode; // Nullable QR code
  final String? bio; // Doctor's biography
  final DoctorProfile profile; // Added profile field

  Doctor({
    required this.id,
    required this.name,
    required this.email,
    required this.phoneNumber,
    required this.age,
    this.qrCode, // Optional parameter
    this.bio, // Optional bio parameter
    DoctorProfile? profile, // Optional profile parameter
  }) : profile =
           profile ??
           DoctorProfile(
             specialization: '',
             workPlace: '',
             languages: [],
             location: '',
             experience: '',
           ); // Default profile if not provided

  // Factory constructor for creating a Doctor from JSON/map
  factory Doctor.fromJson(Map<String, dynamic> json) {
    return Doctor(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String,
      phoneNumber: json['phoneNumber'] as String,
      age: json['age'] as int,
      qrCode: json['qrCode'] as String?,
      bio: json['bio'] as String?, // Add bio to JSON parsing
      profile: json['profile'] != null
          ? DoctorProfile.fromJson(json['profile'] as Map<String, dynamic>)
          : DoctorProfile(
              specialization: '',
              workPlace: '',
              languages: [],
              location: '',
              experience: '',
            ), // Use default profile if not provided
    );
  }

  // Convert Doctor to JSON/map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phoneNumber': phoneNumber,
      'age': age,
      'qrCode': qrCode,
      'bio': bio, // Add bio to JSON output
      'profile': profile.toJson(),
    };
  }

  // Copy with method for immutability
  Doctor copyWith({
    String? id,
    String? name,
    String? email,
    String? phoneNumber,
    int? age,
    String? qrCode,
    String? bio, // Add bio to copyWith
    DoctorProfile? profile,
  }) {
    return Doctor(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      age: age ?? this.age,
      qrCode: qrCode ?? this.qrCode,
      bio: bio ?? this.bio, // Add bio to copyWith
      profile: profile ?? this.profile,
    );
  }

  @override
  String toString() {
    return 'Doctor(id: $id, name: $name, email: $email, phoneNumber: $phoneNumber, age: $age, '
        'qrCode: $qrCode, bio: $bio, profile: $profile)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Doctor &&
        other.id == id &&
        other.name == name &&
        other.email == email &&
        other.phoneNumber == phoneNumber &&
        other.age == age &&
        other.qrCode == qrCode &&
        other.bio == bio && // Add bio to equality check
        other.profile == profile;
  }

  @override
  int get hashCode {
    return Object.hash(id, name, email, phoneNumber, age, qrCode, bio, profile);
  }
}

class DoctorProfile {
  final String specialization;
  final String
  workPlace; // Changed from worken_at to workPlace for better naming
  final String? avatar; // URL or path to avatar image
  final List<String> languages;
  final String location;
  final String experience; // Could be "5 years" or similar format
  final String qualifications;
  final double? consultationFee;

  const DoctorProfile({
    required this.specialization,
    required this.workPlace,
    this.avatar,
    required this.languages,
    required this.location,
    required this.experience,
    this.qualifications = '',
    this.consultationFee,
  });

  // Factory constructor for creating from JSON
  factory DoctorProfile.fromJson(Map<String, dynamic> json) {
    return DoctorProfile(
      specialization:
          json['specialization'] ?? json['speciality'] ?? 'General Physician',
      workPlace: json['workPlace'] ?? json['workingAt'] ?? 'Not specified',
      avatar: json['avatar'] ?? json['avatarUrl'] ?? json['photo'],
      languages: json['languages'] != null
          ? List<String>.from(json['languages'])
          : ['English'],
      location: json['location'] ?? 'Not specified',
      experience: json['experience']?.toString() ?? '0 years',
      qualifications: json['qualifications']?.toString() ?? '',
      consultationFee: json['consultationFee'] is num
          ? (json['consultationFee'] as num).toDouble()
          : double.tryParse(json['consultationFee']?.toString() ?? ''),
    );
  }

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'specialization': specialization,
      'workPlace': workPlace,
      'avatar': avatar,
      'languages': languages,
      'location': location,
      'experience': experience,
      'qualifications': qualifications,
      'consultationFee': consultationFee,
    };
  }

  // Copy with method for easy updates
  DoctorProfile copyWith({
    String? specialization,
    String? workPlace,
    String? avatar,
    List<String>? languages,
    String? location,
    String? experience,
    String? qualifications,
    double? consultationFee,
  }) {
    return DoctorProfile(
      specialization: specialization ?? this.specialization,
      workPlace: workPlace ?? this.workPlace,
      avatar: avatar ?? this.avatar,
      languages: languages ?? this.languages,
      location: location ?? this.location,
      experience: experience ?? this.experience,
      qualifications: qualifications ?? this.qualifications,
      consultationFee: consultationFee ?? this.consultationFee,
    );
  }

  // Helper method to get experience as integer
  int get experienceInYears {
    try {
      // Extract number from string like "5 years" or "2.5 years"
      final expMatch = RegExp(r'(\d+(\.\d+)?)').firstMatch(experience);
      if (expMatch != null) {
        return double.parse(expMatch.group(0)!).round();
      }
      return 0;
    } catch (e) {
      return 0;
    }
  }

  // Helper method to get formatted languages string
  String get languagesFormatted {
    if (languages.isEmpty) return 'No languages specified';
    if (languages.length == 1) return languages.first;

    final allButLast = languages.sublist(0, languages.length - 1);
    return '${allButLast.join(', ')} and ${languages.last}';
  }

  // Helper method to get initials for avatar
  String get initials {
    // Extract first letters from specialization or work place
    final words = specialization.split(' ');
    if (words.length >= 2) {
      return '${words[0][0]}${words[1][0]}'.toUpperCase();
    }
    return specialization.substring(0, 2).toUpperCase();
  }

  @override
  String toString() {
    return 'DoctorProfile(specialization: $specialization, workPlace: $workPlace, '
        'languages: $languages, location: $location, experience: $experience, '
        'qualifications: $qualifications, consultationFee: $consultationFee)';
  }

  // Equality check
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is DoctorProfile &&
        other.specialization == specialization &&
        other.workPlace == workPlace &&
        other.avatar == avatar &&
        other.languages == languages &&
        other.location == location &&
        other.experience == experience &&
        other.qualifications == qualifications &&
        other.consultationFee == consultationFee;
  }

  @override
  int get hashCode {
    return specialization.hashCode ^
        workPlace.hashCode ^
        avatar.hashCode ^
        languages.hashCode ^
        location.hashCode ^
        experience.hashCode ^
        qualifications.hashCode ^
        consultationFee.hashCode;
  }
}

// Extension for Doctor class to add profile
extension DoctorWithProfile on Doctor {
  // Method to get full profile information
  DoctorProfile getProfile({
    required String specialization,
    required String workPlace,
    String? avatar,
    required List<String> languages,
    required String location,
    required String experience,
    String qualifications = '',
    double? consultationFee,
  }) {
    return DoctorProfile(
      specialization: specialization,
      workPlace: workPlace,
      avatar: avatar,
      languages: languages,
      location: location,
      experience: experience,
      qualifications: qualifications,
      consultationFee: consultationFee,
    );
  }
}

// Example usage:
void exampleUsage() {
  final doctor = Doctor(
    id: 'doctor-001',
    name: 'Dr. Yazan Al Ahmad',
    email: 'yazan@gmail.com',
    phoneNumber: '+962 9 2342 34234',
    age: 20,
    bio:
        'Experienced physician dedicated to providing exceptional patient care with over 8 years of practice in general medicine.',
    profile: DoctorProfile(
      specialization: 'Cardiologist',
      workPlace: 'City General Hospital',
      avatar: 'https://example.com/avatar.jpg',
      languages: ['English', 'Arabic', 'French'],
      location: 'New York, USA',
      experience: '10 years',
      qualifications: 'MBBS, MD',
      consultationFee: 50,
    ),
  );

  print('Doctor: ${doctor.name}');
  print('Bio: ${doctor.bio}');
  print('Specialization: ${doctor.profile.specialization}');
  print('Works at: ${doctor.profile.workPlace}');
  print('Speaks: ${doctor.profile.languagesFormatted}');
  print('Experience: ${doctor.profile.experience}');
}
