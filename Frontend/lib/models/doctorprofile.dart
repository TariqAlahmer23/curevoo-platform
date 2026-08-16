// // ignore_for_file: unused_local_variable

// import 'package:curevoo_doctor/models/doctor.dart';

// class DoctorProfile {
//   final String specialization;
//   final String workPlace; // Changed from worken_at to workPlace for better naming
//   final String? avatar; // URL or path to avatar image
//   final List<String> languages;
//   final String location;
//   final String experience; // Could be "5 years" or similar format

//   const DoctorProfile({
//     required this.specialization,
//     required this.workPlace,
//     this.avatar,
//     required this.languages,
//     required this.location,
//     required this.experience,
//   });

//   // Factory constructor for creating from JSON
//   factory DoctorProfile.fromJson(Map<String, dynamic> json) {
//     return DoctorProfile(
//       specialization: json['specialization'] ?? 'General Physician',
//       workPlace: json['workPlace'] ?? 'Not specified',
//       avatar: json['avatar'],
//       languages: json['languages'] != null 
//           ? List<String>.from(json['languages'])
//           : ['English'],
//       location: json['location'] ?? 'Not specified',
//       experience: json['experience'] ?? '0 years',
//     );
//   }

//   // Convert to JSON
//   Map<String, dynamic> toJson() {
//     return {
//       'specialization': specialization,
//       'workPlace': workPlace,
//       'avatar': avatar,
//       'languages': languages,
//       'location': location,
//       'experience': experience,
//     };
//   }

//   // Copy with method for easy updates
//   DoctorProfile copyWith({
//     String? specialization,
//     String? workPlace,
//     String? avatar,
//     List<String>? languages,
//     String? location,
//     String? experience,
//   }) {
//     return DoctorProfile(
//       specialization: specialization ?? this.specialization,
//       workPlace: workPlace ?? this.workPlace,
//       avatar: avatar ?? this.avatar,
//       languages: languages ?? this.languages,
//       location: location ?? this.location,
//       experience: experience ?? this.experience,
//     );
//   }

//   // Helper method to get experience as integer
//   int get experienceInYears {
//     try {
//       // Extract number from string like "5 years" or "2.5 years"
//       final expMatch = RegExp(r'(\d+(\.\d+)?)').firstMatch(experience);
//       if (expMatch != null) {
//         return double.parse(expMatch.group(0)!).round();
//       }
//       return 0;
//     } catch (e) {
//       return 0;
//     }
//   }

//   // Helper method to get formatted languages string
//   String get languagesFormatted {
//     if (languages.isEmpty) return 'No languages specified';
//     if (languages.length == 1) return languages.first;
    
//     final allButLast = languages.sublist(0, languages.length - 1);
//     return '${allButLast.join(', ')} and ${languages.last}';
//   }

//   // Helper method to get initials for avatar
//   String get initials {
//     // Extract first letters from specialization or work place
//     final words = specialization.split(' ');
//     if (words.length >= 2) {
//       return '${words[0][0]}${words[1][0]}'.toUpperCase();
//     }
//     return specialization.substring(0, 2).toUpperCase();
//   }

//   @override
//   String toString() {
//     return 'DoctorProfile(specialization: $specialization, workPlace: $workPlace, '
//         'languages: $languages, location: $location, experience: $experience)';
//   }

//   // Equality check
//   @override
//   bool operator ==(Object other) {
//     if (identical(this, other)) return true;
    
//     return other is DoctorProfile &&
//         other.specialization == specialization &&
//         other.workPlace == workPlace &&
//         other.avatar == avatar &&
//         other.languages == languages &&
//         other.location == location &&
//         other.experience == experience;
//   }

//   @override
//   int get hashCode {
//     return specialization.hashCode ^
//         workPlace.hashCode ^
//         avatar.hashCode ^
//         languages.hashCode ^
//         location.hashCode ^
//         experience.hashCode;
//   }
// }

// // Extension for Doctor class to add profile
// extension DoctorWithProfile on Doctor {
//   // Method to get full profile information
//   DoctorProfile getProfile({
//     required String specialization,
//     required String workPlace,
//     String? avatar,
//     required List<String> languages,
//     required String location,
//     required String experience,
//   }) {
//     return DoctorProfile(
//       specialization: specialization,
//       workPlace: workPlace,
//       avatar: avatar,
//       languages: languages,
//       location: location,
//       experience: experience,
//     );
//   }
// }

// // Example usage:
// void exampleUsage() {
//   final profile = DoctorProfile(
//     specialization: 'Cardiologist',
//     workPlace: 'City General Hospital',
//     avatar: 'https://example.com/avatar.jpg',
//     languages: ['English', 'Arabic', 'French'],
//     location: 'New York, USA',
//     experience: '10 years',
//   );

// }