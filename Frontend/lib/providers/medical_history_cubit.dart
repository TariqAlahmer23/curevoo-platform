import 'package:curevoo_doctor/providers/auth_cubit.dart';
import 'package:curevoo_doctor/repos/main_repo.dart';
import 'package:curevoo_doctor/repos/medical_history_repo.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class MedicalHistoryState extends Equatable {
  const MedicalHistoryState({
    this.isSubmitting = false,
    this.isSuccess = false,
    this.errorMessage,
  });

  final bool isSubmitting;
  final bool isSuccess;
  final String? errorMessage;

  @override
  List<Object?> get props => [isSubmitting, isSuccess, errorMessage];

  MedicalHistoryState copyWith({
    bool? isSubmitting,
    bool? isSuccess,
    String? errorMessage,
    bool clearError = false,
  }) {
    return MedicalHistoryState(
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isSuccess: isSuccess ?? this.isSuccess,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class MedicalHistoryCubit extends Cubit<MedicalHistoryState> {
  MedicalHistoryCubit._(
    this._medicalHistoryRepo,
    this._authCubit,
  ) : super(const MedicalHistoryState());

  final MedicalHistoryRepo _medicalHistoryRepo;
  final AuthCubit _authCubit;

  static MedicalHistoryCubit create({
    required AuthCubit authCubit,
    String baseUrl = AuthCubit.defaultApiBaseUrl,
  }) {
    final repo = MedicalHistoryRepo(mainRepo: MainRepo(baseUrl: baseUrl));
    return MedicalHistoryCubit._(repo, authCubit);
  }

  Future<bool> createMedicalHistory({
    required String patientId,
    required CreateMedicalHistoryRequest request,
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
      state.copyWith(
        isSubmitting: true,
        isSuccess: false,
        clearError: true,
      ),
    );

    try {
      await _withRefreshRetry(
        (accessToken) => _medicalHistoryRepo.createMedicalHistory(
          accessToken,
          patientId: patientId,
          request: request,
        ),
      );
      emit(
        state.copyWith(
          isSubmitting: false,
          isSuccess: true,
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
          errorMessage: 'Failed to create medical history. Please try again.',
        ),
      );
      return false;
    }
  }

  Future<PatientHistoryRecord> fetchLatestHistoryRecord({
    required String patientId,
  }) async {
    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Missing access token.');
    }

    return _withRefreshRetry(
      (accessToken) => _medicalHistoryRepo.fetchLatestHistoryRecord(
        accessToken,
        patientId: patientId,
      ),
    );
  }

  Future<List<PatientHistoryRecord>> fetchAllHistoryRecords({
    required String patientId,
  }) async {
    final token = _authCubit.state.token;
    if (token == null || token.isEmpty) {
      throw ApiException(message: 'Missing access token.');
    }

    return _withRefreshRetry(
      (accessToken) => _medicalHistoryRepo.fetchAllHistoryRecords(
        accessToken,
        patientId: patientId,
      ),
    );
  }

  Future<T> _withRefreshRetry<T>(
    Future<T> Function(String token) action,
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

      return await action(refreshedToken);
    }
  }

  @override
  Future<void> close() {
    _medicalHistoryRepo.close();
    return super.close();
  }
}
