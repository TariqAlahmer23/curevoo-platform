import 'package:curevoo_doctor/models/doctor.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/doctor_repo.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter/foundation.dart';

class DoctorState extends Equatable {
  const DoctorState({
    this.doctor,
    this.isLoading = false,
    this.isSaving = false,
    this.errorMessage,
    this.hasLoaded = false,
  });

  final Doctor? doctor;
  final bool isLoading;
  final bool isSaving;
  final String? errorMessage;
  final bool hasLoaded;

  @override
  List<Object?> get props => [
    doctor,
    isLoading,
    isSaving,
    errorMessage,
    hasLoaded,
  ];

  DoctorState copyWith({
    Doctor? doctor,
    bool? isLoading,
    bool? isSaving,
    String? errorMessage,
    bool? hasLoaded,
    bool clearError = false,
  }) {
    return DoctorState(
      doctor: doctor ?? this.doctor,
      isLoading: isLoading ?? this.isLoading,
      isSaving: isSaving ?? this.isSaving,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      hasLoaded: hasLoaded ?? this.hasLoaded,
    );
  }
}

class DoctorCubit extends Cubit<DoctorState> {
  DoctorCubit._(
    this._doctorRepo,
    this._authCubit,
  ) : super(const DoctorState());

  final DoctorRepo _doctorRepo;
  final AuthCubit _authCubit;

  static DoctorCubit create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) {
    final repo = DoctorRepo(mainRepo: MainRepo(baseUrl: baseUrl));
    return DoctorCubit._(repo, authCubit);
  }

  Future<void> loadProfile({bool forceRefresh = false}) async {
    if (state.isLoading) return;
    if (state.hasLoaded && !forceRefresh) return;

    if (!_hasAccessToken) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: 'Missing access token.',
          hasLoaded: false,
        ),
      );
      return;
    }

    emit(state.copyWith(isLoading: true, clearError: true));

    try {
      final doctor = await _withRefreshRetry(_doctorRepo.getProfile);
      await _authCubit.updateDoctor(doctor);
      emit(
        state.copyWith(
          doctor: doctor,
          isLoading: false,
          hasLoaded: true,
          clearError: true,
        ),
      );
    } catch (e) {
      emit(
        state.copyWith(
          isLoading: false,
          errorMessage: e.toString(),
          hasLoaded: false,
        ),
      );
    }
  }

  Future<bool> updateProfile(Map<String, dynamic> payload) async {
    if (!_hasAccessToken) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      final doctor = await _withRefreshRetry(
        (token) => _doctorRepo.updateProfile(token, payload),
      );
      final mergedDoctor = _mergeDoctorWithFallback(
        current: state.doctor,
        incoming: doctor,
      );
      await _authCubit.updateDoctor(mergedDoctor);
      emit(
        state.copyWith(
          doctor: mergedDoctor,
          isSaving: false,
          hasLoaded: true,
          clearError: true,
        ),
      );
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  Future<bool> uploadPhoto({
    required Uint8List photoBytes,
    required String photoName,
  }) async {
    if (!_hasAccessToken) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(state.copyWith(isSaving: true, clearError: true));

    try {
      final doctor = await _withRefreshRetry(
        (token) => _doctorRepo.uploadPhoto(
          token,
          photoBytes: photoBytes,
          photoName: photoName,
        ),
      );
      final mergedDoctor = _mergeDoctorWithFallback(
        current: state.doctor,
        incoming: doctor,
      );
      await _authCubit.updateDoctor(mergedDoctor);
      emit(
        state.copyWith(
          doctor: mergedDoctor,
          isSaving: false,
          hasLoaded: true,
          clearError: true,
        ),
      );
      return true;
    } catch (e) {
      emit(
        state.copyWith(
          isSaving: false,
          errorMessage: e.toString(),
        ),
      );
      return false;
    }
  }

  void syncFromAuthDoctor(Doctor? doctor) {
    if (doctor == null) return;
    emit(
      state.copyWith(
        doctor: doctor,
        hasLoaded: true,
      ),
    );
  }

  bool get _hasAccessToken {
    final token = _authCubit.state.token;
    return token != null && token.isNotEmpty;
  }

  Future<Doctor> _withRefreshRetry(
    Future<Doctor> Function(String token) action,
  ) async {
    final initialToken = _authCubit.state.token;
    if (initialToken == null || initialToken.isEmpty) {
      throw ApiException(message: 'Missing access token.');
    }

    try {
      return await action(initialToken);
    } on ApiException catch (e) {
      if (e.statusCode != 401) rethrow;

      final refreshed = await _authCubit.refreshSession();
      if (!refreshed) {
        rethrow;
      }

      final refreshedToken = _authCubit.state.token;
      if (refreshedToken == null || refreshedToken.isEmpty) {
        throw ApiException(message: 'Missing refreshed access token.');
      }

      return action(refreshedToken);
    }
  }

  @override
  Future<void> close() {
    _doctorRepo.close();
    return super.close();
  }

  Doctor _mergeDoctorWithFallback({
    required Doctor? current,
    required Doctor incoming,
  }) {
    if (current == null) return incoming;

    final incomingName = incoming.name.trim();
    final incomingEmail = incoming.email.trim();
    final incomingPhone = incoming.phoneNumber.trim();
    final incomingSpecialization = incoming.profile.specialization.trim();
    final incomingWorkPlace = incoming.profile.workPlace.trim();
    final incomingLocation = incoming.profile.location.trim();
    final incomingExperience = incoming.profile.experience.trim();
    final incomingQualifications = incoming.profile.qualifications.trim();

    final resolvedName =
        (incomingName.isNotEmpty && incomingName.toLowerCase() != 'doctor')
        ? incomingName
        : current.name;

    final resolvedAge = incoming.age == 25 && current.age != 25
        ? current.age
        : incoming.age;

    return incoming.copyWith(
      id: incoming.id.trim().isNotEmpty ? incoming.id : current.id,
      name: resolvedName,
      email: incomingEmail.isNotEmpty ? incomingEmail : current.email,
      phoneNumber: incomingPhone.isNotEmpty ? incomingPhone : current.phoneNumber,
      age: resolvedAge,
      qrCode: (incoming.qrCode?.trim().isNotEmpty ?? false)
          ? incoming.qrCode
          : current.qrCode,
      bio: (incoming.bio?.trim().isNotEmpty ?? false) ? incoming.bio : current.bio,
      profile: incoming.profile.copyWith(
        specialization: incomingSpecialization.isNotEmpty
            ? incomingSpecialization
            : current.profile.specialization,
        workPlace: incomingWorkPlace.isNotEmpty
            ? incomingWorkPlace
            : current.profile.workPlace,
        avatar: (incoming.profile.avatar?.trim().isNotEmpty ?? false)
            ? incoming.profile.avatar
            : current.profile.avatar,
        languages: incoming.profile.languages.isNotEmpty
            ? incoming.profile.languages
            : current.profile.languages,
        location: incomingLocation.isNotEmpty
            ? incomingLocation
            : current.profile.location,
        experience: incomingExperience.isNotEmpty
            ? incomingExperience
            : current.profile.experience,
        qualifications: incomingQualifications.isNotEmpty
            ? incomingQualifications
            : current.profile.qualifications,
        consultationFee:
            incoming.profile.consultationFee ?? current.profile.consultationFee,
      ),
    );
  }
}
