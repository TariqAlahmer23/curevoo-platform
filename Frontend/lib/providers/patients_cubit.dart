import 'package:curevoo_doctor/models/patient.dart';
import 'package:curevoo_doctor/models/nsclc_last_result.dart';
import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:curevoo_doctor/repos/patients_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class PatientsState extends Equatable {
  const PatientsState({
    this.isSubmitting = false,
    this.errorMessage,
    this.isSuccess = false,
    this.pendingConnectRequestsCount = 0,
  });

  final bool isSubmitting;
  final String? errorMessage;
  final bool isSuccess;
  final int pendingConnectRequestsCount;

  @override
  List<Object?> get props => [
    isSubmitting,
    errorMessage,
    isSuccess,
    pendingConnectRequestsCount,
  ];

  PatientsState copyWith({
    bool? isSubmitting,
    String? errorMessage,
    bool? isSuccess,
    int? pendingConnectRequestsCount,
    bool clearError = false,
  }) {
    return PatientsState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      isSuccess: isSuccess ?? this.isSuccess,
      pendingConnectRequestsCount:
          pendingConnectRequestsCount ?? this.pendingConnectRequestsCount,
    );
  }
}

class PatientsCubit extends Cubit<PatientsState> {
  PatientsCubit._(this._patientsRepo, this._authCubit)
    : super(const PatientsState());

  final PatientsRepo _patientsRepo;
  final AuthCubit _authCubit;

  static PatientsCubit create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) {
    final repo = PatientsRepo(mainRepo: MainRepo(baseUrl: baseUrl));
    return PatientsCubit._(repo, authCubit);
  }

  Future<List<PatientSummary>> fetchPatients() async {
    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(state.copyWith(errorMessage: 'Missing access token.'));
      return const [];
    }

    try {
      final patients = await _withRefreshRetry(
        (accessToken) => _patientsRepo.fetchPatients(accessToken),
      );
      emit(state.copyWith(clearError: true));
      if (patients is List<PatientSummary>) {
        return patients;
      }
      if (patients is List) {
        return patients.whereType<PatientSummary>().toList(growable: false);
      }
      return const [];
    } on ApiException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return const [];
    } catch (_) {
      emit(
        state.copyWith(
          errorMessage: 'Failed to load patients. Please try again.',
        ),
      );
      return const [];
    }
  }

  Future<bool> createPatient(CreatePatientRequest request) async {
    if (state.isSubmitting) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(
      state.copyWith(isSubmitting: true, isSuccess: false, clearError: true),
    );

    try {
      await _withRefreshRetry(
        (accessToken) => _patientsRepo.createPatient(accessToken, request),
      );
      emit(
        state.copyWith(isSubmitting: false, isSuccess: true, clearError: true),
      );
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Failed to create patient. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<PatientSummary?> createPatientAndReturn(
    CreatePatientRequest request,
  ) async {
    if (state.isSubmitting) return null;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return null;
    }

    emit(
      state.copyWith(isSubmitting: true, isSuccess: false, clearError: true),
    );

    try {
      final createdPatient = await _withRefreshRetry(
        (accessToken) => _patientsRepo.createPatient(accessToken, request),
      );
      final patientSummary = _patientsRepo.parsePatientSummary(createdPatient);
      emit(
        state.copyWith(isSubmitting: false, isSuccess: true, clearError: true),
      );
      return patientSummary;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: e.message,
        ),
      );
      return null;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Failed to create patient. Please try again.',
        ),
      );
      return null;
    }
  }

  Future<bool> updatePatient(
    String patientId,
    UpdatePatientRequest request,
  ) async {
    if (state.isSubmitting) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(
      state.copyWith(isSubmitting: true, isSuccess: false, clearError: true),
    );

    try {
      await _withRefreshRetry(
        (accessToken) =>
            _patientsRepo.updatePatient(accessToken, patientId, request),
      );
      emit(
        state.copyWith(isSubmitting: false, isSuccess: true, clearError: true),
      );
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Failed to update patient. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<bool> deletePatient(String patientId) async {
    if (state.isSubmitting) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(
      state.copyWith(isSubmitting: true, isSuccess: false, clearError: true),
    );

    try {
      await _withRefreshRetry(
        (accessToken) => _patientsRepo.deletePatient(accessToken, patientId),
      );
      emit(
        state.copyWith(isSubmitting: false, isSuccess: true, clearError: true),
      );
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Failed to delete patient. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<List<PatientConnectRequest>> fetchConnectRequests() async {
    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(state.copyWith(errorMessage: 'Missing access token.'));
      return const [];
    }

    try {
      final requests = await _withRefreshRetry(
        (accessToken) => _patientsRepo.fetchConnectRequests(accessToken),
      );
      final parsedRequests = requests is List<PatientConnectRequest>
          ? requests
          : requests is List
          ? requests.whereType<PatientConnectRequest>().toList(growable: false)
          : const <PatientConnectRequest>[];
      final pendingCount = parsedRequests
          .where((request) => request.status.trim().toUpperCase() == 'PENDING')
          .length;
      emit(
        state.copyWith(
          clearError: true,
          pendingConnectRequestsCount: pendingCount,
        ),
      );
      return parsedRequests;
    } on ApiException catch (e) {
      emit(state.copyWith(errorMessage: e.message));
      return const [];
    } catch (_) {
      emit(
        state.copyWith(
          errorMessage:
              'Failed to load patient connection requests. Please try again.',
        ),
      );
      return const [];
    }
  }

  Future<bool> respondToConnectRequest({
    required String requestId,
    required DoctorConnectRequestAction action,
  }) async {
    if (state.isSubmitting) return false;

    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Missing access token.',
        ),
      );
      return false;
    }

    emit(
      state.copyWith(isSubmitting: true, isSuccess: false, clearError: true),
    );

    try {
      await _withRefreshRetry(
        (accessToken) => _patientsRepo.respondToConnectRequest(
          accessToken,
          requestId: requestId,
          action: action,
        ),
      );
      final pendingCount = state.pendingConnectRequestsCount;
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: true,
          pendingConnectRequestsCount: pendingCount > 0 ? pendingCount - 1 : 0,
          clearError: true,
        ),
      );
      return true;
    } on ApiException catch (e) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: e.message,
        ),
      );
      return false;
    } catch (_) {
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: false,
          errorMessage: 'Failed to submit patient connection response.',
        ),
      );
      return false;
    }
  }

  Future<NsclcLastResult?> fetchLastNsclcResult(String patientId) async {
    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      emit(state.copyWith(errorMessage: 'Missing access token.'));
      return null;
    }

    try {
      final result = await _withRefreshRetry(
        (accessToken) =>
            _patientsRepo.fetchLastNsclcResult(accessToken, patientId),
      );
      emit(state.copyWith(clearError: true));
      if (result is NsclcLastResult) {
        return result;
      }
      return null;
    } on ApiException catch (e) {
      final errorCode = _readErrorCode(e.data);
      if (e.statusCode == 404 && errorCode == 'PATIENT_NOT_FOUND') {
        emit(
          state.copyWith(
            errorMessage: 'Patient not found or not accessible by this doctor.',
          ),
        );
        return null;
      }
      if (e.statusCode == 404 && errorCode == 'AI_RESULT_NOT_FOUND') {
        emit(
          state.copyWith(
            errorMessage:
                'No stored treatment resistance result found for this patient yet.',
          ),
        );
        return null;
      }
      emit(state.copyWith(errorMessage: e.message));
      return null;
    } catch (_) {
      emit(
        state.copyWith(
          errorMessage:
              'Failed to load the latest treatment resistance result. Please try again.',
        ),
      );
      return null;
    }
  }

  Future<dynamic> _withRefreshRetry(
    Future<dynamic> Function(String token) action,
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
      if (!refreshed) rethrow;

      final refreshedToken = _authCubit.state.token;
      if (refreshedToken == null || refreshedToken.isEmpty) {
        throw ApiException(message: 'Missing refreshed access token.');
      }

      return action(refreshedToken);
    }
  }

  @override
  Future<void> close() {
    _patientsRepo.close();
    return super.close();
  }
}

String? _readErrorCode(dynamic data) {
  if (data is! Map) return null;
  final typed = data.map(
    (key, dynamic value) => MapEntry(key.toString(), value),
  );
  final direct = typed['code'] ?? typed['errorCode'];
  if (direct is String && direct.trim().isNotEmpty) {
    return direct.trim();
  }
  final nestedError = typed['error'];
  if (nestedError is Map) {
    final nestedTyped = nestedError.map(
      (key, dynamic value) => MapEntry(key.toString(), value),
    );
    final nestedCode = nestedTyped['code'] ?? nestedTyped['errorCode'];
    if (nestedCode is String && nestedCode.trim().isNotEmpty) {
      return nestedCode.trim();
    }
  }
  return null;
}
